import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';

class ReportService {
  // Use 10.0.2.2 for Android emulator to access localhost, 
  // or your actual local IP if on a physical device
  static const String baseUrl = 'http://10.0.2.2:8000/api/reports'; 

  static Future<WeeklyReport?> fetchWeeklyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/weekly'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return WeeklyReport.fromJson(jsonDecode(response.body));
      } else {
        print('Failed to load weekly report: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching weekly report: $e');
      return null;
    }
  }

  static Future<MonthlyReport?> fetchMonthlyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/monthly'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return MonthlyReport.fromJson(jsonDecode(response.body));
      } else {
        print('Failed to load monthly report: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching monthly report: $e');
      return null;
    }
  }

  static Future<PerformanceSummary?> fetchPerformanceSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/summary'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return PerformanceSummary.fromJson(jsonDecode(response.body));
      } else {
        print('Failed to load performance summary: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching performance summary: $e');
      return null;
    }
  }
}
