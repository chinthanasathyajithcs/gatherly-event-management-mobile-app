import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  String _timeTextTight(EventModel event) {
    final hour = event.time.hour;
    final minute = event.time.minute;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    if (minute == 0) return '$normalizedHour$suffix';
    final minuteText = minute.toString().padLeft(2, '0');
    return '$normalizedHour:$minuteText$suffix';
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

  String _upcomingScheduleText(EventModel event, DateTime now) {
    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    final start = _start(event);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDay = DateTime(start.year, start.month, start.day);
    final timeText = _timeTextTight(event);

    if (eventDay == today) {
      final evening = start.hour >= 17;
      return '${evening ? 'Tonight' : 'Today'}, $timeText';
    }

    if (eventDay == tomorrow) {
      return 'Tomorrow, $timeText';
    }

    return '${weekdays[start.weekday - 1]} ${start.day}, $timeText';
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

  Color _upcomingBadgeColor(String category) {
    switch (category.toLowerCase()) {
      case 'hackathon':
        return const Color(0xFF9A5E2B);
      case 'workshop':
        return const Color(0xFFB06A30);
      case 'seminar':
        return const Color(0xFFC47A36);
      case 'conference':
        return const Color(0xFFA86834);
      case 'festival':
        return const Color(0xFFD1863D);
      case 'meetup':
      case 'networking':
        return const Color(0xFF8C6B42);
      case 'webinar':
        return const Color(0xFF9F7148);
      case 'competition':
        return const Color(0xFFB36A3B);
      case 'career fair':
        return const Color(0xFFAF7646);
      case 'sports':
        return const Color(0xFFC8863C);
      case 'cultural':
        return const Color(0xFFAD6C52);
      case 'orientation':
      case 'volunteering':
        return const Color(0xFFA1764B);
      default:
        return _primaryAccent;
    }
  }

  IconData _categoryHeroIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hackathon':
        return Icons.terminal_rounded;
      case 'workshop':
        return Icons.build_rounded;
      case 'seminar':
        return Icons.mic_rounded;
      case 'sports':
        return Icons.sports_basketball_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _categoryHeroSubtitle(String category) {
    switch (category.toLowerCase()) {
      case 'hackathon':
        return 'Build fast, ship bold, and compete with top campus teams.';
      case 'workshop':
        return 'Hands-on sessions to sharpen real-world skills.';
      case 'seminar':
        return 'Insights, ideas, and expert sessions in one place.';
      case 'sports':
        return 'Energy-packed events to compete, play, and connect.';
      default:
        return 'Events curated for your current discovery mood.';
    }
  }

  Widget _buildCategoryHero({
    required String category,
    required int eventCount,
  }) {
    final accent = _upcomingBadgeColor(category);
    final icon = _categoryHeroIcon(category);
    final subtitle = _categoryHeroSubtitle(category);
    final countLabel = eventCount == 1 ? '1 event' : '$eventCount events';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.17),
            accent.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$category Focus',
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              countLabel,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
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
          final isCategoryMode = _selectedCategory != 'All';
          final filteredCount = filteredEvents.length;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              20 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildCategories(),
              if (isCategoryMode) ...[
                const SizedBox(height: 14),
                _buildCategoryHero(
                  category: _selectedCategory,
                  eventCount: filteredCount,
                ),
              ],
              const SizedBox(height: 26),
              _sectionHeader('Happening Now', 'CURATION'),
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
                  isCategoryMode
                      ? 'No live ${_selectedCategory.toLowerCase()} events right now.'
                      : 'Nothing live right now. Stay tuned.',
                  icon: Icons.videocam_off_rounded,
                ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
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
              _sectionHeader(
                isCategoryMode
                    ? 'Upcoming in ${_selectedCategory}s'
                    : 'Upcoming for You',
                isCategoryMode ? 'FILTERED' : 'PERSONALIZED',
              ),
              const SizedBox(height: 14),
              if (personalizedEvents.isEmpty)
                _emptyState(
                  isCategoryMode
                      ? 'No upcoming ${_selectedCategory.toLowerCase()} events found. Try All or another category.'
                      : 'No upcoming events found. Try another category or search.',
                  icon: Icons.event_busy_rounded,
                )
              else
                ...personalizedEvents.take(4).map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UpcomingEventCard(
                          event: event,
                          scheduleText: _upcomingScheduleText(event, now),
                          categoryColor: _upcomingBadgeColor(event.category),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _EventDetailsPage(event: event),
                              ),
                            );
                          },
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
    return SizedBox(
      width: double.infinity,
      height: 134,
      child: CustomPaint(
        painter: const _DashedRoundedRectPainter(
          color: Color(0xFFDCC5A7),
          strokeWidth: 1.4,
          dashLength: 5.5,
          gapLength: 4.5,
          radius: 24,
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F1E9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Host an Event?',
                style: TextStyle(
                  color: _primaryAccent,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bring your vision to life on campus.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 30,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  const _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength ||
        radius != oldDelegate.radius;
  }
}

class _TomorrowEmptyCard extends StatelessWidget {
  const _TomorrowEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 124,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: _bgColor,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No events tomorrow',
                  style: TextStyle(
                    color: Color(0xFF545E6B),
                    fontSize: 18,
                    height: 1.02,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check back later.',
                  style: TextStyle(
                    color: Color(0xFF7B8391),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.event_busy_rounded,
              size: 30,
              color: Color(0xFF8F98A6),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  final EventModel event;
  final String scheduleText;
  final Color categoryColor;
  final VoidCallback onTap;

  const _UpcomingEventCard({
    required this.event,
    required this.scheduleText,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoster =
        event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty;
    final isAllocatedEvent =
        event.hasParticipantLimit && (event.attendeeCount ?? 0) > 0;
    final joinedText =
        '${event.joinedParticipantCount}/${event.attendeeCount ?? event.joinedParticipantCount} has joined';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
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
                          style:
                              TextStyle(color: Color(0xFFB79D87), fontSize: 12),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          scheduleText,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isAllocatedEvent) ...[
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFFB79D87),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            joinedText,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailsPage extends StatelessWidget {
  final EventModel event;

  const _EventDetailsPage({required this.event});

  void _openPosterPreview(BuildContext context) {
    final posterUrl = event.posterImageUrl;
    if (posterUrl == null || posterUrl.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PosterPreviewPage(
          imageUrl: posterUrl,
          heroTag: 'event-poster-${event.id}',
        ),
      ),
    );
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

  String _formattedDate(EventModel event) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

    final start = _start(event);
    return '${weekdays[start.weekday - 1]}, ${start.day} ${months[start.month - 1]} ${start.year}';
  }

  String _formattedTime(EventModel event) {
    final hour = event.time.hour;
    final minute = event.time.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$normalizedHour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final hasPoster =
        event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty;
    final venue = event.location.trim().isEmpty ? 'TBA' : event.location;
    final isAllocatedEvent =
        event.hasParticipantLimit && (event.attendeeCount ?? 0) > 0;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DETAILS',
                style: TextStyle(
                  color: Color(0xFF8A6D5A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                event.name,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 30,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasPoster ? () => _openPosterPreview(context) : null,
                    child: SizedBox(
                      width: double.infinity,
                      height: 280,
                      child: hasPoster
                          ? Container(
                              color: _bgColor,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 0.68,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Hero(
                                          tag: 'event-poster-${event.id}',
                                          child: Image.network(
                                            event.posterImageUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.48),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.search_rounded,
                                            color: Colors.white,
                                            size: 17,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFEFE3D7),
                              child: const Icon(
                                Icons.image_not_supported_rounded,
                                color: Color(0xFFAF8868),
                                size: 44,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFEFD),
                      Color(0xFFF6F3EF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xE6E6DFD7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120D1B2E),
                      blurRadius: 18,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -124,
                      top: -20,
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x26CB6D22),
                                  width: 2,
                                ),
                              ),
                            ),
                            Container(
                              width: 236,
                              height: 236,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x30CB6D22),
                                  width: 2,
                                ),
                              ),
                            ),
                            Container(
                              width: 174,
                              height: 174,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x3CCB6D22),
                                  width: 2,
                                ),
                              ),
                            ),
                            Container(
                              width: 118,
                              height: 118,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: Alignment(-0.3, -0.3),
                                  radius: 0.95,
                                  colors: [
                                    Color(0x2CFFEED7),
                                    Color(0x26DEA26B),
                                    Color(0x1ACB6D22),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 112, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailItem(
                              label: 'Date', value: _formattedDate(event)),
                          const SizedBox(height: 10),
                          _DetailItem(
                              label: 'Time', value: _formattedTime(event)),
                          const SizedBox(height: 10),
                          _DetailItem(label: 'Venue', value: venue),
                          const SizedBox(height: 12),
                          const Text(
                            'Category',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _primaryAccent.withValues(alpha: 0.2),
                                  _primaryAccent.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _primaryAccent.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              event.category.toUpperCase(),
                              style: const TextStyle(
                                color: _primaryAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!isAllocatedEvent)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to your schedule.'),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Add to Schedule',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to your schedule.'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryAccent,
                            side: const BorderSide(color: Color(0xFFD9BFA5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Add to Schedule',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Your presence has been counted.',
                                ),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Join Event',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PosterPreviewPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _PosterPreviewPage({
    required this.imageUrl,
    required this.heroTag,
  });

  Future<Uint8List> _fetchPosterBytes() async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      throw Exception('Invalid poster URL.');
    }

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch image: ${response.statusCode}');
    }
    if (response.bodyBytes.isEmpty) {
      throw Exception('Downloaded image is empty.');
    }

    return response.bodyBytes;
  }

  Future<void> _downloadPoster(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      if (Theme.of(context).platform == TargetPlatform.windows ||
          Theme.of(context).platform == TargetPlatform.linux ||
          Theme.of(context).platform == TargetPlatform.fuchsia) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Poster download is not supported on this platform.'),
          ),
        );
        return;
      }

      final hasAccess = await Gal.hasAccess(toAlbum: true);
      final granted = hasAccess ? true : await Gal.requestAccess(toAlbum: true);

      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Storage access was denied. Unable to download.'),
          ),
        );
        return;
      }

      final uri = Uri.tryParse(imageUrl);
      if (uri == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid poster URL.')),
        );
        return;
      }

      final posterBytes = await _fetchPosterBytes();

      final now = DateTime.now();
      final name =
          'unihub_poster_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      try {
        await Gal.putImageBytes(
          posterBytes,
          album: 'UniHub',
          name: name,
        );
      } catch (_) {
        // Some devices reject album writes even when general access is granted.
        // Fallback to default gallery location to avoid total failure.
        await Gal.putImageBytes(
          posterBytes,
          name: name,
        );
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Poster downloaded to your gallery.')),
      );
    } on MissingPluginException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Download plugin not initialized. Fully stop the app and run it again.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $error'),
        ),
      );
    }
  }

  Future<void> _sharePoster(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final posterBytes = await _fetchPosterBytes();
      final now = DateTime.now();
      final fileName =
          'unihub_poster_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.jpg';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(posterBytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Check out this event poster from UniHub.',
          title: 'Share Poster',
        ),
      );
    } on MissingPluginException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Share plugin not initialized. Fully stop the app and run it again.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Share failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Share poster',
            onPressed: () => _sharePoster(context),
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: 'Download poster',
            onPressed: () => _downloadPoster(context),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.5,
            child: Hero(
              tag: heroTag,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white70,
                        size: 44,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Unable to load poster',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
