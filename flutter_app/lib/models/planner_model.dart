/// Data models for the Study Planner feature.

enum PlanMode { heavy, medium, light }

enum BlockType { study, breakTime, free }

extension PlanModeLabel on PlanMode {
  String get label {
    switch (this) {
      case PlanMode.heavy:
        return 'Heavy Focus';
      case PlanMode.medium:
        return 'Medium Focus';
      case PlanMode.light:
        return 'Light Focus';
    }
  }

  String get description {
    switch (this) {
      case PlanMode.heavy:
        return '80% of your day in deep study';
      case PlanMode.medium:
        return 'Balanced study with good breaks';
      case PlanMode.light:
        return 'Light schedule with plenty of free time';
    }
  }

  String get emoji {
    switch (this) {
      case PlanMode.heavy:
        return '🔥';
      case PlanMode.medium:
        return '⚡';
      case PlanMode.light:
        return '🌿';
    }
  }

  String get apiKey {
    switch (this) {
      case PlanMode.heavy:
        return 'heavy';
      case PlanMode.medium:
        return 'medium';
      case PlanMode.light:
        return 'light';
    }
  }
}

class PlanBlock {
  final BlockType type;
  final String? subject;
  final int durationMin;
  final bool editable;

  // Mutable fields (only for study blocks)
  String? editedSubject;
  int? editedDuration;

  PlanBlock({
    required this.type,
    this.subject,
    required this.durationMin,
    required this.editable,
    this.editedSubject,
    this.editedDuration,
  });

  factory PlanBlock.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    BlockType blockType;
    switch (typeStr) {
      case 'study':
        blockType = BlockType.study;
        break;
      case 'break':
        blockType = BlockType.breakTime;
        break;
      default:
        blockType = BlockType.free;
    }

    return PlanBlock(
      type: blockType,
      subject: json['subject'] as String?,
      durationMin: json['duration_min'] as int,
      editable: json['editable'] as bool? ?? false,
    );
  }

  /// Display subject name (edited or original)
  String get displaySubject => editedSubject ?? subject ?? 'Study';

  /// Display duration (edited or original)
  int get displayDuration => editedDuration ?? durationMin;

  bool get isStudy => type == BlockType.study;
  bool get isBreak => type == BlockType.breakTime;
  bool get isFree => type == BlockType.free;
}

class DayPlan {
  final PlanMode mode;
  final int totalStudyMin;
  final int totalBreakMin;
  final int totalFreeMin;
  final List<PlanBlock> blocks;

  DayPlan({
    required this.mode,
    required this.totalStudyMin,
    required this.totalBreakMin,
    required this.totalFreeMin,
    required this.blocks,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json, PlanMode mode) {
    final blockList = (json['blocks'] as List<dynamic>)
        .map((b) => PlanBlock.fromJson(b as Map<String, dynamic>))
        .toList();

    return DayPlan(
      mode: mode,
      totalStudyMin: json['total_study_min'] as int,
      totalBreakMin: json['total_break_min'] as int,
      totalFreeMin: json['total_free_min'] as int,
      blocks: blockList,
    );
  }
}

class StudyPlan {
  final DayPlan heavy;
  final DayPlan medium;
  final DayPlan light;

  StudyPlan({
    required this.heavy,
    required this.medium,
    required this.light,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      heavy: DayPlan.fromJson(json['heavy'] as Map<String, dynamic>, PlanMode.heavy),
      medium: DayPlan.fromJson(json['medium'] as Map<String, dynamic>, PlanMode.medium),
      light: DayPlan.fromJson(json['light'] as Map<String, dynamic>, PlanMode.light),
    );
  }

  DayPlan byMode(PlanMode mode) {
    switch (mode) {
      case PlanMode.heavy:
        return heavy;
      case PlanMode.medium:
        return medium;
      case PlanMode.light:
        return light;
    }
  }
}
