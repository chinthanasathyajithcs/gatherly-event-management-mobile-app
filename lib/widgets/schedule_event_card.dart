import 'package:flutter/material.dart';
import '../models/event_model.dart';

class ScheduleEventCard extends StatelessWidget {
  final EventModel event;
  final String timeText;
  final bool isLastInGroup;
  final bool isVeryLast;
  final VoidCallback onTap;

  const ScheduleEventCard({
    super.key,
    required this.event,
    required this.timeText,
    required this.isLastInGroup,
    required this.isVeryLast,
    required this.onTap,
  });

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'hackathon':   return const Color(0xFF1D4E89);
      case 'workshop':    return const Color(0xFF2E8A99);
      case 'seminar':     return const Color(0xFF9C6ADE);
      case 'conference':  return const Color(0xFF4F709C);
      case 'festival':    return const Color(0xFFFF8A3D);
      case 'competition': return const Color(0xFFDC2F02);
      case 'sports':      return const Color(0xFFFCA311);
      case 'cultural':    return const Color(0xFFE0AAFF);
      default:            return const Color(0xFFAC5D20);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'hackathon':   return Icons.terminal_rounded;
      case 'workshop':    return Icons.build_rounded;
      case 'seminar':     return Icons.mic_rounded;
      case 'sports':      return Icons.sports_basketball_rounded;
      case 'festival':    return Icons.celebration_rounded;
      case 'cultural':    return Icons.palette_rounded;
      case 'conference':  return Icons.business_center_rounded;
      default:            return Icons.explore_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(event.category);
    final catIcon = _categoryIcon(event.category);
    const bgColor = Color(0xFFF9F6F0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: bgColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: catColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isVeryLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFDDD0C2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLastInGroup ? 6 : 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD9C5B0).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 4, color: catColor),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Category pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          event.category.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: catColor,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Event title
                                      Text(
                                        event.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1B1C20),
                                          height: 1.2,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Location
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Color(0xFF8B7D71),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              event.location.isNotEmpty ? event.location : 'TBA',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF8B7D71),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Chips row
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0E5D9),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF904210)),
                                                const SizedBox(width: 5),
                                                Text(
                                                  timeText,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF904210),
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE4F8EE),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.notifications_active_rounded, size: 11, color: Color(0xFF14754B)),
                                                SizedBox(width: 4),
                                                Text(
                                                  "REMINDER SET",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF14754B),
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Icon circle
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(catIcon, color: catColor, size: 24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
