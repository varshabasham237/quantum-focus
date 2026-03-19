class WeeklyReport {
  final List<String> labels;
  final List<int> focusTime;
  final List<int> distractionTime;

  WeeklyReport({
    required this.labels,
    required this.focusTime,
    required this.distractionTime,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      labels: List<String>.from(json['labels'] ?? []),
      focusTime: List<int>.from(json['focus_time'] ?? []),
      distractionTime: List<int>.from(json['distraction_time'] ?? []),
    );
  }
}

class MonthlyReport {
  final List<String> labels;
  final List<int> focusTime;
  final List<int> distractionTime;

  MonthlyReport({
    required this.labels,
    required this.focusTime,
    required this.distractionTime,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      labels: List<String>.from(json['labels'] ?? []),
      focusTime: List<int>.from(json['focus_time'] ?? []),
      distractionTime: List<int>.from(json['distraction_time'] ?? []),
    );
  }
}

class AppUsageItem {
  final String name;
  final int minutes;

  AppUsageItem({
    required this.name,
    required this.minutes,
  });

  factory AppUsageItem.fromJson(Map<String, dynamic> json) {
    return AppUsageItem(
      name: json['name'] ?? '',
      minutes: json['minutes'] ?? 0,
    );
  }
}

class PerformanceSummary {
  final int focusTimeTotal;
  final int distractionTimeTotal;
  final int productivityScore;
  final int taskCompletionRate;
  final List<AppUsageItem> topDistractedApps;

  PerformanceSummary({
    required this.focusTimeTotal,
    required this.distractionTimeTotal,
    required this.productivityScore,
    required this.taskCompletionRate,
    required this.topDistractedApps,
  });

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) {
    return PerformanceSummary(
      focusTimeTotal: json['focus_time_total'] ?? 0,
      distractionTimeTotal: json['distraction_time_total'] ?? 0,
      productivityScore: json['productivity_score'] ?? 0,
      taskCompletionRate: json['task_completion_rate'] ?? 0,
      topDistractedApps: (json['top_distracted_apps'] as List?)
              ?.map((item) => AppUsageItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}
