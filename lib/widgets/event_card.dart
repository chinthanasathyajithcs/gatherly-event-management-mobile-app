import 'package:flutter/material.dart';

import '../models/event_model.dart';

const Color _textDark = Color(0xFF1B1C20);
const Color _textMuted = Color(0xFF7B6E63);

class EventCard extends StatelessWidget {
  final EventModel event;
  final String scheduleText;
  final Color categoryColor;
  final VoidCallback onTap;

  const EventCard({
    super.key,
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
                        if (event.isPaidEvent) ...[
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFFB79D87),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A8A5A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '\$${event.entryFee?.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(
                                color: Color(0xFF1A8A5A),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
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
