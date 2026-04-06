import 'package:flutter/material.dart';

import '../models/event_model.dart';

// ---------------------------------------------------------------------------
// Category → gradient palette
// ---------------------------------------------------------------------------

const Map<String, List<Color>> organizerCategoryGradients = {
  'hackathon': [Color(0xFF0D1B2E), Color(0xFF1D4E89)],
  'workshop': [Color(0xFF1F6E8C), Color(0xFF2E8A99)],
  'seminar': [Color(0xFF6A4C93), Color(0xFF9C6ADE)],
  'conference': [Color(0xFF213555), Color(0xFF4F709C)],
  'festival': [Color(0xFFB84A00), Color(0xFFFF8A3D)],
  'meetup': [Color(0xFF355E3B), Color(0xFF5F8D4E)],
  'webinar': [Color(0xFF005B96), Color(0xFF00A8CC)],
  'competition': [Color(0xFF6A040F), Color(0xFFDC2F02)],
  'career fair': [Color(0xFF3A0CA3), Color(0xFF4361EE)],
  'networking': [Color(0xFF004B23), Color(0xFF38B000)],
  'sports': [Color(0xFF14213D), Color(0xFFFCA311)],
  'cultural': [Color(0xFF7B2CBF), Color(0xFFE0AAFF)],
  'orientation': [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  'volunteering': [Color(0xFF166534), Color(0xFF22C55E)],
};

List<Color> paletteForCategory(String category) =>
    organizerCategoryGradients[category.trim().toLowerCase()] ??
    const [Color(0xFF374151), Color(0xFF6B7280)];

// ---------------------------------------------------------------------------
// Approval status helpers
// ---------------------------------------------------------------------------

String approvalStatusLabel(EventApprovalStatus status) {
  switch (status) {
    case EventApprovalStatus.pending:
      return 'Pending';
    case EventApprovalStatus.accepted:
      return 'Approved';
    case EventApprovalStatus.rejected:
      return 'Rejected';
  }
}

IconData approvalStatusIcon(EventApprovalStatus status) {
  switch (status) {
    case EventApprovalStatus.pending:
      return Icons.schedule_rounded;
    case EventApprovalStatus.accepted:
      return Icons.check_circle_rounded;
    case EventApprovalStatus.rejected:
      return Icons.cancel_rounded;
  }
}

Color approvalStatusColor(EventApprovalStatus status) {
  switch (status) {
    case EventApprovalStatus.pending:
      return const Color(0xFFCB6D22);
    case EventApprovalStatus.accepted:
      return const Color(0xFF2F9E44);
    case EventApprovalStatus.rejected:
      return const Color(0xFFD64545);
  }
}

Color approvalStatusBg(EventApprovalStatus status) {
  switch (status) {
    case EventApprovalStatus.pending:
      return const Color(0xFFFFF4EB);
    case EventApprovalStatus.accepted:
      return const Color(0xFFEDF9F0);
    case EventApprovalStatus.rejected:
      return const Color(0xFFFDEDED);
  }
}

// ---------------------------------------------------------------------------
// Animated wrapper for staggered entry
// ---------------------------------------------------------------------------

class AnimatedOrganizerCard extends StatefulWidget {
  final int index;
  final Widget child;

  const AnimatedOrganizerCard({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<AnimatedOrganizerCard> createState() => _AnimatedOrganizerCardState();
}

class _AnimatedOrganizerCardState extends State<AnimatedOrganizerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main reusable organizer event card
// ---------------------------------------------------------------------------

class OrganizerEventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback onPosterTap;

  const OrganizerEventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onPosterTap,
  });

  String _participantLabel() {
    if (!event.hasParticipantLimit) return 'Open event';
    return '${event.joinedParticipantCount}/${event.attendeeCount ?? '∞'}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDayData time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour12 =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final hh = hour12.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm $period';
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteForCategory(event.category);
    final sColor = approvalStatusColor(event.approvalStatus);
    final sBg = approvalStatusBg(event.approvalStatus);
    final sLabel = approvalStatusLabel(event.approvalStatus);
    final sIcon = approvalStatusIcon(event.approvalStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x0E0D1B2E)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C0D1B2E),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPosterHeader(palette),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0D1B2E),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: sBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: sColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(sIcon, size: 13, color: sColor),
                                const SizedBox(width: 4),
                                Text(
                                  sLabel,
                                  style: TextStyle(
                                    color: sColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Date + time
                      Row(
                        children: [
                          OrganizerMetaChip(
                            icon: Icons.calendar_today_rounded,
                            label: _formatDate(event.date),
                          ),
                          const SizedBox(width: 10),
                          OrganizerMetaChip(
                            icon: Icons.access_time_rounded,
                            label: _formatTime(event.time),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Location + participants
                      Row(
                        children: [
                          OrganizerMetaChip(
                            icon: Icons.location_on_outlined,
                            label: event.location,
                            flex: true,
                          ),
                          const SizedBox(width: 10),
                          OrganizerMetaChip(
                            icon: Icons.people_outline_rounded,
                            label: _participantLabel(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action row
                      Row(
                        children: [
                          OrganizerActionChip(
                            icon: Icons.image_outlined,
                            label: 'Update Poster',
                            onTap: onPosterTap,
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Color(0xFFABB8C8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterHeader(List<Color> palette) {
    if (event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                event.posterImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackGradientHeader(palette),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                child: OrganizerCategoryBadge(label: event.category),
              ),
            ],
          ),
        ),
      );
    }
    return _fallbackGradientHeader(palette);
  }

  Widget _fallbackGradientHeader(List<Color> palette) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: palette,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -25,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -15,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 14,
              child: OrganizerCategoryBadge(label: event.category),
            ),
            Positioned(
              right: 18,
              bottom: 10,
              child: Text(
                event.name.isNotEmpty ? event.name[0].toUpperCase() : 'E',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.18),
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting small widgets
// ---------------------------------------------------------------------------

class OrganizerCategoryBadge extends StatelessWidget {
  final String label;
  const OrganizerCategoryBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class OrganizerMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool flex;

  const OrganizerMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.flex = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8A98A9)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4E6076),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (flex) return Expanded(child: content);
    return content;
  }
}

class OrganizerActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const OrganizerActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x0F0D1B2E)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFF3A5068)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF29425D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
