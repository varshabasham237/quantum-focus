import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/strictness_model.dart';
import 'api_service.dart';

class StrictnessService {
  final ApiService _apiService;

  StrictnessService(this._apiService);

  Future<StrictnessStatus?> getStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/strictness/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return StrictnessStatus.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching strictness status: $e');
      return null;
    }
  }

  Future<StrictnessStatus?> evaluateToday(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/strictness/evaluate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'date': dateStr}),
      );

      if (response.statusCode == 200) {
        return StrictnessStatus.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error evaluating strictness: $e');
      return null;
    }
  }
}
