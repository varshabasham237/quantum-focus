import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Calendar & Deadlines Screen — Module 3.4
/// Features: mini month calendar, reminder banner, timeline list,
/// FAB to add events, tap to edit, swipe to delete.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<CalendarEvent> _events = [];
  List<CalendarEvent> _reminders = [];
  bool _loading = true;
  String? _error;

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadData();
  }

  // ─── Data loading ──────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthService>();

    final eventsResult   = await auth.api.get('/calendar/events');
    final remindersResult = await auth.api.get('/calendar/reminders');

    if (!mounted) return;

    if (eventsResult == null || eventsResult.containsKey('error')) {
      setState(() {
        _error = eventsResult?['error'] ?? 'Failed to load events';
        _loading = false;
      });
      return;
    }

    final rawEvents = (eventsResult['events'] as List<dynamic>? ?? [])
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawReminders = (remindersResult?['events'] as List<dynamic>? ?? [])
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() {
      _events = rawEvents;
      _reminders = rawReminders;
      _loading = false;
    });
  }

  // ─── CRUD helpers ──────────────────────────────────────────

  Future<void> _createEvent(CreateEventRequest req) async {
    final auth = context.read<AuthService>();
    final result = await auth.api.post('/calendar/events', req.toJson());
    if (!mounted) return;
    if (result != null && !result.containsKey('error')) {
      await _loadData();
    } else {
      _showError(result?['error'] ?? 'Failed to create event');
    }
  }

  Future<void> _updateEvent(String id, UpdateEventRequest req) async {
    final auth = context.read<AuthService>();
    final result = await auth.api.patch('/calendar/events/$id', req.toJson());
    if (!mounted) return;
    if (result != null && !result.containsKey('error')) {
      await _loadData();
    } else {
      _showError(result?['error'] ?? 'Failed to update event');
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final auth = context.read<AuthService>();
    final result = await auth.api.delete('/calendar/events/${event.id}');
    if (!mounted) return;
    if (result != null && !result.containsKey('error')) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🗑️ "${event.title}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _createEvent(CreateEventRequest(
            title: event.title,
            type: event.type,
            date: event.date,
            note: event.note,
          )),
        ),
        backgroundColor: AppTheme.bgCard,
        duration: const Duration(seconds: 4),
      ));
    } else {
      _showError(result?['error'] ?? 'Failed to delete event');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.accentRose,
    ));
  }

  // ─── Helpers ──────────────────────────────────────────────

  List<CalendarEvent> get _eventsForSelectedDay {
    if (_selectedDay == null) return [];
    return _events.where((e) =>
      e.date.year == _selectedDay!.year &&
      e.date.month == _selectedDay!.month &&
      e.date.day == _selectedDay!.day,
    ).toList();
  }

  List<CalendarEvent> get _upcomingEvents {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return _events
        .where((e) => !DateTime(e.date.year, e.date.month, e.date.day)
            .isBefore(todayDate))
        .toList();
  }

  Set<DateTime> get _datesWithEvents {
    return _events.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet();
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('📅 Calendar & Deadlines'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: AppTheme.accentViolet,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Event',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentViolet),
                  SizedBox(height: 16),
                  Text('Loading calendar...', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 48),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentViolet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Reminder banner
        if (_reminders.isNotEmpty)
          SliverToBoxAdapter(child: _buildReminderBanner()),

        // Month Calendar
        SliverToBoxAdapter(child: _buildMonthCalendar()),

        // Selected day events
        if (_selectedDay != null && _eventsForSelectedDay.isNotEmpty)
          SliverToBoxAdapter(child: _buildDayEventsPanel()),

        // Divider
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              Expanded(child: Divider(color: Color(0xFF1F2937))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Upcoming', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Color(0xFF1F2937))),
            ]),
          ),
        ),

        // Timeline list
        _upcomingEvents.isEmpty
            ? const SliverToBoxAdapter(child: _EmptyUpcoming())
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildTimelineCard(_upcomingEvents[i]),
                  childCount: _upcomingEvents.length,
                ),
              ),

        // Bottom padding for FAB
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ─── Reminder banner ──────────────────────────────────────

  Widget _buildReminderBanner() {
    final count = _reminders.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? '"${_reminders.first.title}" is due within 2 days!'
                  : '$count events are due within 2 days — stay on track!',
              style: const TextStyle(
                color: AppTheme.accentAmber,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.accentAmber, size: 20),
        ],
      ),
    );
  }

  // ─── Mini Month Calendar ───────────────────────────────────

  Widget _buildMonthCalendar() {
    final datesWithEvents = _datesWithEvents;
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun ... 6=Sat

    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                _monthLabel(_focusedMonth),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Weekday headers
          Row(
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 8),

          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final dateOnly = DateTime(date.year, date.month, date.day);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selectedDay != null &&
                  date.year == _selectedDay!.year &&
                  date.month == _selectedDay!.month &&
                  date.day == _selectedDay!.day;
              final hasEvent = datesWithEvents.contains(dateOnly);

              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: _DayCell(
                  day: day,
                  isToday: isToday,
                  isSelected: isSelected,
                  hasEvent: hasEvent,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Selected day panel ────────────────────────────────────

  Widget _buildDayEventsPanel() {
    final dayEvents = _eventsForSelectedDay;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentViolet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentViolet.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_dayLabel(_selectedDay!)} — ${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
            style: const TextStyle(
                color: AppTheme.accentViolet,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...dayEvents.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(e.type.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.title,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    _TypeChip(type: e.type),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Timeline card ─────────────────────────────────────────

  Widget _buildTimelineCard(CalendarEvent event) {
    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.accentRose.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.accentRose, size: 26),
      ),
      onDismissed: (_) => _deleteEvent(event),
      child: GestureDetector(
        onTap: () => _showEditDialog(event),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: event.isDueSoon
                  ? AppTheme.accentAmber.withValues(alpha: 0.4)
                  : const Color(0xFF1F2937),
            ),
          ),
          child: Row(
            children: [
              // Date column
              Column(
                children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: event.type.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _shortMonth(event.date),
                          style: TextStyle(
                              color: event.type.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${event.date.day}',
                          style: TextStyle(
                              color: event.type.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(event.type.emoji,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                                color: event.completed ? AppTheme.textMuted : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                decoration: event.completed ? TextDecoration.lineThrough : null,
                                fontSize: 14),
                          ),
                        ),
                        if (event.type == EventType.task || event.type == EventType.assignment)
                          Checkbox(
                            value: event.completed,
                            activeColor: AppTheme.accentEmerald,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              if (val != null) {
                                _updateEvent(event.id, UpdateEventRequest(completed: val));
                              }
                            },
                          ),
                      ],
                    ),
                    if (event.note != null && event.note!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        event.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 4),
                    _DueBadge(event: event),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add Event dialog ──────────────────────────────────────

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    EventType selectedType = EventType.task;
    DateTime selectedDate = _selectedDay ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => _EventSheet(
          title: 'Add Event',
          titleCtrl: titleCtrl,
          noteCtrl: noteCtrl,
          selectedType: selectedType,
          selectedDate: selectedDate,
          onTypeChanged: (t) => setLocal(() => selectedType = t),
          onDateChanged: (d) => setLocal(() => selectedDate = d),
          onSave: () async {
            if (titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx);
            await _createEvent(CreateEventRequest(
              title: titleCtrl.text.trim(),
              type: selectedType,
              date: selectedDate,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
            ));
          },
        ),
      ),
    );
  }

  // ─── Edit Event dialog ─────────────────────────────────────

  void _showEditDialog(CalendarEvent event) {
    final titleCtrl = TextEditingController(text: event.title);
    final noteCtrl = TextEditingController(text: event.note ?? '');
    EventType selectedType = event.type;
    DateTime selectedDate = event.date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => _EventSheet(
          title: 'Edit Event',
          titleCtrl: titleCtrl,
          noteCtrl: noteCtrl,
          selectedType: selectedType,
          selectedDate: selectedDate,
          onTypeChanged: (t) => setLocal(() => selectedType = t),
          onDateChanged: (d) => setLocal(() => selectedDate = d),
          onSave: () async {
            if (titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx);
            await _updateEvent(
              event.id,
              UpdateEventRequest(
                title: titleCtrl.text.trim(),
                type: selectedType,
                date: selectedDate,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              ),
            );
          },
          onDelete: () async {
            Navigator.pop(ctx);
            await _deleteEvent(event);
          },
        ),
      ),
    );
  }

  // ─── String helpers ────────────────────────────────────────

  String _monthLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _shortMonth(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[dt.month - 1];
  }

  String _dayLabel(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    Color textColor = AppTheme.textSecondary;
    FontWeight fontWeight = FontWeight.w400;

    if (isSelected) {
      bgColor = AppTheme.accentViolet;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
    } else if (isToday) {
      bgColor = AppTheme.accentViolet.withValues(alpha: 0.2);
      textColor = AppTheme.accentViolet;
      fontWeight = FontWeight.w700;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ),
        if (hasEvent)
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppTheme.accentAmber,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final EventType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(color: type.color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DueBadge extends StatelessWidget {
  final CalendarEvent event;
  const _DueBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (event.isToday) {
      label = '🔴 Due today';
      color = AppTheme.accentRose;
    } else if (event.isTomorrow) {
      label = '🟠 Due tomorrow';
      color = AppTheme.accentAmber;
    } else if (event.isDueSoon) {
      label = '🟡 Due in ${event.daysFromNow} days';
      color = AppTheme.accentAmber;
    } else {
      label = 'In ${event.daysFromNow} days';
      color = AppTheme.textMuted;
    }

    return Text(label, style: TextStyle(color: color, fontSize: 11));
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No upcoming events',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add an exam, assignment, task or holiday.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable event bottom sheet ──────────────────────────────

class _EventSheet extends StatelessWidget {
  final String title;
  final TextEditingController titleCtrl;
  final TextEditingController noteCtrl;
  final EventType selectedType;
  final DateTime selectedDate;
  final ValueChanged<EventType> onTypeChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  const _EventSheet({
    required this.title,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.selectedType,
    required this.selectedDate,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.accentRose, size: 22),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Event title field
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Event title',
                prefixIcon: Icon(Icons.title_rounded, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 14),

            // Type selector
            Row(
              children: EventType.values.map((t) {
                final isSelected = t == selectedType;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTypeChanged(t),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.color.withValues(alpha: 0.2)
                            : AppTheme.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? t.color.withValues(alpha: 0.6)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                            t.label,
                            style: TextStyle(
                              color: isSelected ? t.color : AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Date picker
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.accentViolet,
                        surface: AppTheme.bgCard,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) onDateChanged(picked);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgInput,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.accentViolet, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Note field
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentViolet.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                label: const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
