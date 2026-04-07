import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../widgets/schedule_event_card.dart';
import 'student_discovery_page.dart';

const Color _bgColor = Color(0xFFF9F6F0);
const Color _textMuted = Color(0xFF7A6B5D);
const Color _primaryAccent = Color(0xFFAC5D20);

class StudentSchedulePage extends StatefulWidget {
  const StudentSchedulePage({super.key});

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> {
  String? _uid;
  DateTime? _jumpToDay;
  final ScrollController _scrollController = ScrollController();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _eventsStream;

  // Map from date-string (yyyy-MM-dd) → GlobalKey for scroll-to
  final Map<String, GlobalKey> _dateKeys = {};

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _eventsStream = FirebaseFirestore.instance
          .collection('events')
          .where('scheduledByIds', arrayContains: _uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Unique days that have events, sorted ascending
  List<DateTime> _uniqueDays(List<EventModel> events) {
    final seen = <String>{};
    final days = <DateTime>[];
    for (final e in events) {
      final key = _dayKey(e.date);
      if (seen.add(key)) {
        days.add(DateTime(e.date.year, e.date.month, e.date.day));
      }
    }
    days.sort((a, b) => a.compareTo(b));
    return days;
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);

    if (day == today) return 'Today';
    if (day == tomorrow) return 'Tomorrow';
    if (day == yesterday) return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(d);
  }

  String _formatMonthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  String _formatTime(TimeOfDayData time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${h.toString().padLeft(2, '0')}:$minute $suffix';
  }

  void _jumpToDate(DateTime day, List<DateTime> uniqueDays) {
    setState(() => _jumpToDay = day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dateKeys[_dayKey(day)];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.08,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _eventsStream == null) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: Text("Please sign in to view your schedule.")),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _eventsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryAccent));
            }

            final docs = snapshot.data?.docs ?? [];
            final allEvents = docs.map((doc) => EventModel.fromDoc(doc)).toList();

            allEvents.sort((a, b) {
              final aDt = DateTime(a.date.year, a.date.month, a.date.day, a.time.hour, a.time.minute);
              final bDt = DateTime(b.date.year, b.date.month, b.date.day, b.time.hour, b.time.minute);
              return aDt.compareTo(bDt);
            });

            final uniqueDays = _uniqueDays(allEvents);

            for (final d in uniqueDays) {
              _dateKeys.putIfAbsent(_dayKey(d), () => GlobalKey());
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "My Schedule",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF904210),
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        allEvents.isEmpty
                            ? "Add events to build your schedule."
                            : "${allEvents.length} event${allEvents.length == 1 ? '' : 's'} across ${uniqueDays.length} day${uniqueDays.length == 1 ? '' : 's'}",
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: _textMuted.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (uniqueDays.isNotEmpty)
                  _DateStrip(
                    days: uniqueDays,
                    selectedDay: _jumpToDay,
                    onDayTap: (d) => _jumpToDate(d, uniqueDays),
                    isToday: _isToday,
                    isSame: _isSameDay,
                  ),
                if (uniqueDays.isNotEmpty) const SizedBox(height: 14),
                Expanded(
                  child: allEvents.isEmpty
                      ? _emptyState()
                      : _buildTimeline(allEvents, uniqueDays),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeline(List<EventModel> allEvents, List<DateTime> uniqueDays) {
    final List<_TimelineItem> items = [];
    String? lastMonth;

    for (final day in uniqueDays) {
      final monthLabel = _formatMonthYear(day);
      if (monthLabel != lastMonth) {
        items.add(_TimelineItem.monthDivider(monthLabel));
        lastMonth = monthLabel;
      }

      final dayEvents = allEvents.where((e) => _isSameDay(e.date, day)).toList();
      items.add(_TimelineItem.dayHeader(day, _dateKeys[_dayKey(day)]!));
      for (int i = 0; i < dayEvents.length; i++) {
        items.add(_TimelineItem.event(
          dayEvents[i],
          isLastInGroup: i == dayEvents.length - 1,
          isVeryLast: day == uniqueDays.last && i == dayEvents.length - 1,
        ));
      }
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((item) {
          if (item.type == _ItemType.monthDivider) {
            return _MonthDivider(label: item.monthLabel!);
          }
          if (item.type == _ItemType.dayHeader) {
            return _DayHeaderRow(
              day: item.day!,
              label: _formatDayLabel(item.day!),
              isToday: _isToday(item.day!),
              anchorKey: item.anchorKey!,
            );
          }
          return ScheduleEventCard(
            event: item.event!,
            timeText: _formatTime(item.event!.time),
            isLastInGroup: item.isLastInGroup,
            isVeryLast: item.isVeryLast,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailsPage(event: item.event!),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5DC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 40,
              color: _primaryAccent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            "No events yet",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A3A2C),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap 'Add to Schedule' on any event\nto see it appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: _textMuted.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date Strip ───────────────────────────────────────────────────────────────

class _DateStrip extends StatefulWidget {
  final List<DateTime> days;
  final DateTime? selectedDay;
  final void Function(DateTime) onDayTap;
  final bool Function(DateTime) isToday;
  final bool Function(DateTime, DateTime) isSame;

  const _DateStrip({
    required this.days,
    required this.selectedDay,
    required this.onDayTap,
    required this.isToday,
    required this.isSame,
  });

  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<_DateStrip> {
  final ScrollController _tc = ScrollController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _tc,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.days.length,
        itemBuilder: (context, index) {
          final day = widget.days[index];
          final isSelected = widget.selectedDay != null &&
              widget.isSame(day, widget.selectedDay!);
          final today = widget.isToday(day);
          final dayName = DateFormat('E').format(day).toUpperCase();
          final dayNum = day.day.toString();
          final monthAbbr = DateFormat('MMM').format(day).toUpperCase();

          return GestureDetector(
            onTap: () => widget.onDayTap(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 54,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF9E4C14)
                    : today
                        ? const Color(0xFFD9A27A).withValues(alpha: 0.25)
                        : const Color(0xFFEDE5DC),
                borderRadius: BorderRadius.circular(30),
                border: today && !isSelected
                    ? Border.all(color: const Color(0xFFCB8050), width: 1.5)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF9E4C14).withValues(alpha: 0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFFF6CEB0)
                          : const Color(0xFF8B7D71),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayNum,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : today
                              ? const Color(0xFF7A3B0E)
                              : const Color(0xFF4A3A2C),
                    ),
                  ),
                  Text(
                    monthAbbr,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFF6CEB0)
                          : const Color(0xFF8B7D71),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Timeline Items ────────────────────────────────────────────────────────────

enum _ItemType { monthDivider, dayHeader, event }

class _TimelineItem {
  final _ItemType type;
  final DateTime? day;
  final EventModel? event;
  final String? monthLabel;
  final GlobalKey? anchorKey;
  final bool isLastInGroup;
  final bool isVeryLast;

  const _TimelineItem._({
    required this.type,
    this.day,
    this.event,
    this.monthLabel,
    this.anchorKey,
    this.isLastInGroup = false,
    this.isVeryLast = false,
  });

  factory _TimelineItem.monthDivider(String label) =>
      _TimelineItem._(type: _ItemType.monthDivider, monthLabel: label);

  factory _TimelineItem.dayHeader(DateTime day, GlobalKey key) =>
      _TimelineItem._(type: _ItemType.dayHeader, day: day, anchorKey: key);

  factory _TimelineItem.event(EventModel event,
          {required bool isLastInGroup, required bool isVeryLast}) =>
      _TimelineItem._(
        type: _ItemType.event,
        event: event,
        isLastInGroup: isLastInGroup,
        isVeryLast: isVeryLast,
      );
}

// ── Month Divider ─────────────────────────────────────────────────────────────

class _MonthDivider extends StatelessWidget {
  final String label;
  const _MonthDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA07050),
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFE5D5C4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day Header Row ────────────────────────────────────────────────────────────

class _DayHeaderRow extends StatelessWidget {
  final DateTime day;
  final String label;
  final bool isToday;
  final GlobalKey anchorKey;

  const _DayHeaderRow({
    required this.day,
    required this.label,
    required this.isToday,
    required this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left accent blob
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFFDE8742) : const Color(0xFFCDB49A),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isToday ? const Color(0xFF7A3B0E) : const Color(0xFF3A2C1E),
                  letterSpacing: -0.3,
                ),
              ),
              if (isToday)
                const Text(
                  "TODAY",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDE8742),
                    letterSpacing: 2.0,
                  ),
                ),
            ],
          ),
          if (isToday) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEDC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8C49A)),
              ),
              child: const Text(
                "NOW",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFAC5D20),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

