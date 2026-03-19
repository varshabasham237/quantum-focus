import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Authentication service — handles login, register, token persistence, profile status.
class AuthService extends ChangeNotifier {
  final ApiService _api;

  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _profileComplete = false;
  String? _userName;
  String? _userEmail;
  String? _userId;
  String? _error;

  AuthService(this._api);

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get profileComplete => _profileComplete;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  String? get error => _error;
  ApiService get api => _api;

  /// Try to restore session from stored tokens
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');

    if (accessToken != null && refreshToken != null) {
      _api.setTokens(accessToken, refreshToken);

      // Verify token by fetching profile
      final result = await _api.get('/auth/profile');
      if (result != null && result.containsKey('id')) {
        _userId = result['id'];
        _userName = result['name'];
        _userEmail = result['email'];
        _isLoggedIn = true;

        // Check profile completion
        final profileResult = await _api.get('/profile/');
        if (profileResult != null) {
          _profileComplete = profileResult['profile_complete'] == true;
        }

        notifyListeners();
        return;
      }
      await _clearStored();
    }
  }

  /// Register a new user
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });

    _isLoading = false;

    if (result != null && result.containsKey('access_token')) {
      await _handleAuthSuccess(result);
      _profileComplete = false; // New user, needs onboarding
      notifyListeners();
      return true;
    } else {
      _error = result?['error'] ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });

    _isLoading = false;

    if (result != null && result.containsKey('access_token')) {
      await _handleAuthSuccess(result);

      // Check profile completion
      final profileResult = await _api.get('/profile/');
      if (profileResult != null) {
        _profileComplete = profileResult['profile_complete'] == true;
      }

      notifyListeners();
      return true;
    } else {
      _error = result?['error'] ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  /// Mark profile as complete (called after onboarding)
  void markProfileComplete() {
    _profileComplete = true;
    notifyListeners();
  }

  /// Logout
  Future<void> logout() async {
    _api.clearTokens();
    await _clearStored();
    _isLoggedIn = false;
    _profileComplete = false;
    _userName = null;
    _userEmail = null;
    _userId = null;
    notifyListeners();
  }

  /// Handle successful auth response
  Future<void> _handleAuthSuccess(Map<String, dynamic> data) async {
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    final user = data['user'];

    _api.setTokens(accessToken, refreshToken);

    _userId = user['id'];
    _userName = user['name'];
    _userEmail = user['email'];
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> _clearStored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}
