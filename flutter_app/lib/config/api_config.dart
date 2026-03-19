/// API configuration for the AntiDistractionSystem backend.
class ApiConfig {
  // For Chrome/web: use localhost
  // For Android emulator: change to http://10.0.2.2:8000/api
  // For physical device: use your computer's local IP
  static const String baseUrl = 'http://localhost:8000/api';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
