import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/event_model.dart';

const Color _bgColor = Color(0xFFF6F1EB);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textDark = Color(0xFF1B1C20);
const Color _textMuted = Color(0xFF7B6E63);
const Color _primaryAccent = Color(0xFFCB6D22);
const Color _softBorder = Color(0xFFE8D5C4);
const double _secondaryCardHeight = 156;

const List<String> _categories = [
  'All',
  'Hackathon',
  'Workshop',
  'Seminar',
  'Conference',
  'Festival',
  'Meetup',
  'Webinar',
  'Competition',
  'Career Fair',
  'Networking',
  'Sports',
  'Cultural',
  'Orientation',
  'Volunteering',
];

class StudentDiscoveryPage extends StatefulWidget {
  final VoidCallback? onOpenOrganize;

  const StudentDiscoveryPage({super.key, this.onOpenOrganize});

  @override
  State<StudentDiscoveryPage> createState() => _StudentDiscoveryPageState();
}

class _StudentDiscoveryPageState extends State<StudentDiscoveryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  Timer? _tomorrowRotationTimer;
  int _tomorrowEventsCount = 0;
  final ValueNotifier<int> _tomorrowSpotlightIndexNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _tomorrowRotationTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _rotateTomorrow());
  }

  void _rotateTomorrow() {
    if (!mounted || _tomorrowEventsCount < 2) return;
    _tomorrowSpotlightIndexNotifier.value =
        (_tomorrowSpotlightIndexNotifier.value + 1) % _tomorrowEventsCount;
  }

  @override
  void dispose() {
    _tomorrowRotationTimer?.cancel();
    _tomorrowSpotlightIndexNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<EventModel>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map(EventModel.fromDoc)
          .where(
            (event) => event.approvalStatus == EventApprovalStatus.accepted,
          )
          .toList();
      events.sort((a, b) => _start(a).compareTo(_start(b)));
      return events;
    });
  }

  DateTime _start(EventModel event) {
    return DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.time.hour,
      event.time.minute,
    );
  }

  bool _isLive(EventModel event, DateTime now) {
    final start = _start(event);
    final end = start.add(const Duration(hours: 2));
    return now.isAfter(start) && now.isBefore(end);
  }

  String _dateText(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }

  String _timeText(EventModel event) {
    final hour = event.time.hour;
    final minute = event.time.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$normalizedHour:$minute $suffix';
  }

  String _timeTextCompact(EventModel event) {
    final hour = event.time.hour;
    final minute = event.time.minute;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    if (minute == 0) return '$normalizedHour $suffix';
    final minuteText = minute.toString().padLeft(2, '0');
    return '$normalizedHour:$minuteText $suffix';
  }

  String _spotlightDateLabel(EventModel event, DateTime now) {
    final start = _start(event);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDay = DateTime(start.year, start.month, start.day);

    if (eventDay == tomorrow) return 'Tomorrow';
    if (eventDay == today) return 'Today';
    return _dateText(start);
  }

  bool _matches(EventModel event, String query) {
    if (query.isEmpty) return true;
    final haystack =
        '${event.name} ${event.description} ${event.category} ${event.location}'
            .toLowerCase();
    return haystack.contains(query.toLowerCase());
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'hackathon':
        return const Color(0xFF1D4E89);
      case 'workshop':
        return const Color(0xFF2E8A99);
      case 'seminar':
        return const Color(0xFF9C6ADE);
      case 'conference':
        return const Color(0xFF4F709C);
      case 'festival':
        return const Color(0xFFFF8A3D);
      case 'meetup':
        return const Color(0xFF5F8D4E);
      case 'webinar':
        return const Color(0xFF00A8CC);
      case 'competition':
        return const Color(0xFFDC2F02);
      case 'career fair':
        return const Color(0xFF4361EE);
      case 'networking':
        return const Color(0xFF38B000);
      case 'sports':
        return const Color(0xFFFCA311);
      case 'cultural':
        return const Color(0xFFE0AAFF);
      case 'orientation':
        return const Color(0xFF2563EB);
      case 'volunteering':
        return const Color(0xFF22C55E);
      default:
        return _primaryAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F3EE), _bgColor],
        ),
      ),
      child: StreamBuilder<List<EventModel>>(
        stream: _eventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryAccent),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load events right now.',
                style: TextStyle(color: _textMuted),
              ),
            );
          }

          final allEvents = snapshot.data ?? <EventModel>[];
          final query = _searchController.text.trim();
          final filteredEvents = allEvents.where((event) {
            final categoryMatch = _selectedCategory == 'All' ||
                event.category.toLowerCase() == _selectedCategory.toLowerCase();
            return categoryMatch && _matches(event, query);
          }).toList();

          final now = DateTime.now();
          final liveEvents =
              filteredEvents.where((event) => _isLive(event, now)).toList();

          final upcomingEvents = filteredEvents
              .where((event) => _start(event).isAfter(now))
              .toList()
            ..sort((a, b) => _start(a).compareTo(_start(b)));

          final tomorrow = DateTime(now.year, now.month, now.day + 1);
          final tomorrowEvents = upcomingEvents.where((event) {
            final eventStart = _start(event);
            return eventStart.year == tomorrow.year &&
                eventStart.month == tomorrow.month &&
                eventStart.day == tomorrow.day;
          }).toList();

          _tomorrowEventsCount = tomorrowEvents.length;
          if (_tomorrowSpotlightIndexNotifier.value >= _tomorrowEventsCount &&
              _tomorrowEventsCount > 0) {
            _tomorrowSpotlightIndexNotifier.value = 0;
          }

          final featuredEvent = liveEvents.isNotEmpty ? liveEvents.first : null;
          final personalizedEvents = upcomingEvents
              .where(
                (event) =>
                    !tomorrowEvents.any((tEvent) => tEvent.id == event.id),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildCategories(),
              const SizedBox(height: 26),
              _sectionHeader('Featured Pulse', 'CURATION'),
              const SizedBox(height: 14),
              if (featuredEvent != null)
                _FeaturedEventCard(
                  event: featuredEvent,
                  isLive: liveEvents.contains(featuredEvent),
                  categoryColor: _categoryColor(featuredEvent.category),
                  dateText: _dateText(_start(featuredEvent)),
                  timeText: _timeText(featuredEvent),
                )
              else
                _emptyState(
                  'No live sessions match your filters right now.',
                  icon: Icons.auto_awesome_rounded,
                ),
              const SizedBox(height: 18),
              if (tomorrowEvents.isNotEmpty)
                ValueListenableBuilder<int>(
                  valueListenable: _tomorrowSpotlightIndexNotifier,
                  builder: (context, spotlightIndex, _) {
                    final safeIndex = spotlightIndex % tomorrowEvents.length;
                    final spotlightEvent = tomorrowEvents[safeIndex];
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final fade = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        );
                        return FadeTransition(opacity: fade, child: child);
                      },
                      child: _SpotlightCard(
                        key: ValueKey('tomorrow-${spotlightEvent.id}'),
                        event: spotlightEvent,
                        dateText: _spotlightDateLabel(spotlightEvent, now),
                        timeText: _timeTextCompact(spotlightEvent),
                      ),
                    );
                  },
                )
              else
                const _TomorrowEmptyCard(),
              const SizedBox(height: 18),
              _HostEventCard(
                onTap: () {
                  final openOrganize = widget.onOpenOrganize;
                  if (openOrganize != null) {
                    openOrganize();
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event creation coming soon')),
                  );
                },
              ),
              const SizedBox(height: 28),
              _sectionHeader('Upcoming for You', 'PERSONALIZED'),
              const SizedBox(height: 14),
              if (personalizedEvents.isEmpty)
                _emptyState(
                  'No upcoming events found. Try another category or search.',
                  icon: Icons.event_busy_rounded,
                )
              else
                ...personalizedEvents.take(4).map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UpcomingEventCard(
                          event: event,
                          dateText: _dateText(_start(event)),
                          timeText: _timeText(event),
                          categoryColor: _categoryColor(event.category),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Find your next vibe...',
          hintStyle: const TextStyle(
            color: Color(0xFF9F8F83),
            fontSize: 15,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF9F8F83)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF9F8F83)),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(category),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _textDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            selectedColor: _primaryAccent,
            backgroundColor: _cardColor,
            side: BorderSide(color: selected ? _primaryAccent : _softBorder),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            onSelected: (_) {
              setState(() {
                _selectedCategory = category;
              });
            },
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, String overline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          style: const TextStyle(
            color: Color(0xFF8A6D5A),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: _textDark,
            fontSize: 32,
            height: 0.96,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message, {required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _primaryAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedEventCard extends StatelessWidget {
  final EventModel event;
  final bool isLive;
  final Color categoryColor;
  final String dateText;
  final String timeText;

  const _FeaturedEventCard({
    required this.event,
    required this.isLive,
    required this.categoryColor,
    required this.dateText,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster =
        event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event details coming soon')),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight =
                (constraints.maxWidth * 1.05).clamp(260.0, 380.0);
            final titleSize = constraints.maxWidth < 360 ? 28.0 : 34.0;
            return Container(
              height: cardHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF111827),
                    categoryColor.withValues(alpha: 0.95),
                    const Color(0xFF2A0F0A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
                image: hasPoster
                    ? DecorationImage(
                        image: NetworkImage(event.posterImageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: const ColorFilter.mode(
                          Color(0x70000000),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isLive)
                              _badge('LIVE NOW', const Color(0xFF0BA84F),
                                  Colors.white),
                            _badge(
                              event.category.toUpperCase(),
                              Colors.white.withValues(alpha: 0.16),
                              Colors.white,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          event.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            height: 0.96,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$dateText $timeText',
                          style: const TextStyle(
                            color: Color(0xFFF4EDE5),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF8F4EF),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _badge(String text, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  final EventModel event;
  final String dateText;
  final String timeText;

  const _SpotlightCard({
    super.key,
    required this.event,
    required this.dateText,
    required this.timeText,
  });

  IconData _spotlightIcon(String category) {
    switch (category.toLowerCase()) {
      case 'workshop':
        return Icons.psychology_alt_rounded;
      case 'seminar':
        return Icons.record_voice_over_rounded;
      case 'conference':
        return Icons.business_center_rounded;
      case 'hackathon':
        return Icons.code_rounded;
      case 'festival':
        return Icons.celebration_rounded;
      case 'meetup':
      case 'networking':
        return Icons.groups_rounded;
      case 'sports':
        return Icons.sports_basketball_rounded;
      case 'cultural':
        return Icons.palette_rounded;
      case 'webinar':
        return Icons.live_tv_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _secondaryCardHeight,
      padding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6EBDD),
            Color(0xFFF1E0CF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF0CBB1),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -24,
            left: -30,
            child: Container(
              width: 120,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.category.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFA96A2A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A3A30),
                    fontSize: 26,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 13, color: Color(0xFF81695B)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$dateText, $timeText',
                        style: const TextStyle(
                          color: Color(0xFF81695B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: -26,
            bottom: -32,
            child: Container(
              width: 126,
              height: 126,
              decoration: const BoxDecoration(
                color: Color(0x42D9A169),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -14,
            bottom: -18,
            child: Container(
              width: 94,
              height: 94,
              decoration: const BoxDecoration(
                color: Color(0x28D9A169),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 14,
            child: Icon(
              _spotlightIcon(event.category),
              size: 30,
              color: const Color(0xFFD39A61),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostEventCard extends StatelessWidget {
  final VoidCallback onTap;

  const _HostEventCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _secondaryCardHeight,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E7DA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFD9BFA5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Host an Event?',
            style: TextStyle(
              color: _primaryAccent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bring your vision to life on campus.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TomorrowEmptyCard extends StatelessWidget {
  const _TomorrowEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _secondaryCardHeight,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7E7D6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFD9BFA5),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOMORROW',
                  style: TextStyle(
                    color: _primaryAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'No events are scheduled for tomorrow yet',
                  style: TextStyle(
                    color: Color(0xFF4A3A30),
                    fontSize: 20,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Check out upcoming events below or host one now.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFE8C4A9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F8B5C2A),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFB97A34),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  final EventModel event;
  final String dateText;
  final String timeText;
  final Color categoryColor;

  const _UpcomingEventCard({
    required this.event,
    required this.dateText,
    required this.timeText,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster =
        event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty;
    final goingText = event.hasParticipantLimit
        ? '${event.joinedParticipantCount}/${event.attendeeCount ?? event.joinedParticipantCount} going'
        : '${event.joinedParticipantCount} attending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0D1B2E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 72,
              height: 72,
              child: hasPoster
                  ? Image.network(event.posterImageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: categoryColor.withValues(alpha: 0.12),
                      child: Icon(Icons.event_rounded,
                          color: categoryColor, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.category.toUpperCase(),
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '|',
                      style: TextStyle(color: Color(0xFFB79D87), fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 18,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$dateText, $timeText - $goingText',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primaryAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.add_rounded, color: _primaryAccent, size: 20),
          ),
        ],
      ),
    );
  }
}
