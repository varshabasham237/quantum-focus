/// Data models for the Calendar & Deadlines feature (Module 3.4).

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// EventType
// ─────────────────────────────────────────────────────────────

enum EventType { exam, assignment, task, holiday }

extension EventTypeExt on EventType {
  String get label {
    switch (this) {
      case EventType.exam:        return 'Exam';
      case EventType.assignment:  return 'Assignment';
      case EventType.task:        return 'Task';
      case EventType.holiday:     return 'Holiday';
    }
  }

  String get emoji {
    switch (this) {
      case EventType.exam:        return '📝';
      case EventType.assignment:  return '📋';
      case EventType.task:        return '✅';
      case EventType.holiday:     return '🎉';
    }
  }

  Color get color {
    switch (this) {
      case EventType.exam:        return const Color(0xFFFB7185); // rose
      case EventType.assignment:  return const Color(0xFF8B5CF6); // violet
      case EventType.task:        return const Color(0xFF34D399); // emerald
      case EventType.holiday:     return const Color(0xFFFBBF24); // amber
    }
  }

  String get apiKey {
    switch (this) {
      case EventType.exam:        return 'exam';
      case EventType.assignment:  return 'assignment';
      case EventType.task:        return 'task';
      case EventType.holiday:     return 'holiday';
    }
  }

  static EventType fromString(String s) {
    switch (s) {
      case 'exam':       return EventType.exam;
      case 'assignment': return EventType.assignment;
      case 'task':       return EventType.task;
      case 'holiday':    return EventType.holiday;
      default:           return EventType.task;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// CalendarEvent
// ─────────────────────────────────────────────────────────────

class CalendarEvent {
  final String id;
  final String title;
  final EventType type;
  final DateTime date;
  final String? note;
  final bool reminderSent;
  final bool completed;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.note,
    this.reminderSent = false,
    this.completed = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id:           json['id'] as String,
      title:        json['title'] as String,
      type:         EventTypeExt.fromString(json['type'] as String),
      date:         DateTime.parse(json['date'] as String),
      note:         json['note'] as String?,
      reminderSent: json['reminder_sent'] as bool? ?? false,
      completed:    json['completed'] as bool? ?? false,
    );
  }

  /// Days from today (negative = past)
  int get daysFromNow {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    return eventDate.difference(todayDate).inDays;
  }

  bool get isPast      => daysFromNow < 0;
  bool get isToday     => daysFromNow == 0;
  bool get isTomorrow  => daysFromNow == 1;
  bool get isDueSoon   => daysFromNow >= 0 && daysFromNow <= 2;
}

// ─────────────────────────────────────────────────────────────
// CreateEventRequest
// ─────────────────────────────────────────────────────────────

class CreateEventRequest {
  final String title;
  final EventType type;
  final DateTime date;
  final String? note;

  CreateEventRequest({
    required this.title,
    required this.type,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'type':  type.apiKey,
    'date':  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

// ─────────────────────────────────────────────────────────────
// UpdateEventRequest
// ─────────────────────────────────────────────────────────────

class UpdateEventRequest {
  final String? title;
  final EventType? type;
  final DateTime? date;
  final String? note;
  final bool? completed;

  UpdateEventRequest({this.title, this.type, this.date, this.note, this.completed});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (title != null) m['title'] = title;
    if (type != null)  m['type']  = type!.apiKey;
    if (date != null) {
      m['date'] = '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
    }
    if (note != null)  m['note']  = note;
    if (completed != null) m['completed'] = completed;
    return m;
  }
}
