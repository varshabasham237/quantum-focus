import 'api_service.dart';
import '../models/planner_model.dart';

class PlannerService {
  final ApiService _api;

  PlannerService(this._api);

  Future<StudyPlan?> generatePlans() async {
    final response = await _api.get('/planner/generate');
    if (response != null && !response.containsKey('error')) {
      return StudyPlan.fromJson(response);
    }
    return null;
  }

  Future<bool> updatePlan(PlanMode mode, List<Map<String, dynamic>> updates) async {
    final response = await _api.patch('/planner/update', {
      'mode': mode.apiKey,
      'updates': updates,
    });
    return response != null && !response.containsKey('error');
  }

  Future<DailySession?> getDailySession() async {
    final response = await _api.get('/planner/daily-session');
    if (response != null && !response.containsKey('error')) {
      if (response['locked'] == true) {
         return DailySession.fromJson(response);
      }
    }
    return null;
  }

  Future<DailySession?> lockDailySession(PlanMode mode) async {
    final response = await _api.post('/planner/daily-session', {
      'mode': mode.apiKey,
    });
    if (response != null && !response.containsKey('error')) {
      return DailySession.fromJson(response);
    }
    return null;
  }

  Future<bool> updateDailySessionTask(int blockIndex, String task) async {
    final response = await _api.patch('/planner/daily-session/task', {
      'block_index': blockIndex,
      'task': task,
    });
    return response != null && !response.containsKey('error');
  }
}
