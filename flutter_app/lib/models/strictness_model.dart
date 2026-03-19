class StrictnessStatus {
  final int warnings;
  final String level;
  final List<String> activePenalties;
  final String? lastEvaluated;

  StrictnessStatus({
    required this.warnings,
    required this.level,
    required this.activePenalties,
    this.lastEvaluated,
  });

  factory StrictnessStatus.fromJson(Map<String, dynamic> json) {
    return StrictnessStatus(
      warnings: json['warnings'] ?? 0,
      level: json['strictness_level'] ?? 'NORMAL',
      activePenalties: List<String>.from(json['active_penalties'] ?? []),
      lastEvaluated: json['last_evaluated'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warnings': warnings,
      'strictness_level': level,
      'active_penalties': activePenalties,
      'last_evaluated': lastEvaluated,
    };
  }
}
