import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../widgets/organizer_event_card.dart';
import 'qr_scanner_page.dart';
import 'student_event_builder_screen.dart';

class StudentOrganizePage extends StatelessWidget {
  const StudentOrganizePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _OrganizeBackground(),
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HeroHeader(),
                        const SizedBox(height: 18),
                        _OpenBuilderCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StudentEventBuilderScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const _CreatedEventsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hosts section (displays event creator and co-hosts)
// ---------------------------------------------------------------------------

class _HostsSection extends StatefulWidget {
  final String createdBy;
  final List<String> coHostIds;
  final Map<String, String> coHostNamesById;
  final AuthService authService;

  const _HostsSection({
    required this.createdBy,
    required this.coHostIds,
    required this.coHostNamesById,
    required this.authService,
  });

  @override
  State<_HostsSection> createState() => _HostsSectionState();
}

class _HostsSectionState extends State<_HostsSection> {
  late Map<String, UserModel?> _creatorDetails;
  late Map<String, UserModel?> _coHostDetails;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _creatorDetails = {};
    _coHostDetails = {};
    _loadHostsData();
  }

  Future<void> _loadHostsData() async {
    try {
      // Load creator details
      final creator = await widget.authService.getUserProfile(widget.createdBy);

      // Load co-host details
      final coHosts = <String, UserModel?>{};
      for (final coHostId in widget.coHostIds) {
        try {
          final profile = await widget.authService.getUserProfile(coHostId);
          coHosts[coHostId] = profile;
        } catch (_) {
          coHosts[coHostId] = null;
        }
      }

      if (mounted) {
        setState(() {
          _creatorDetails[widget.createdBy] = creator;
          _coHostDetails.addAll(coHosts);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB6D22)),
            ),
          ),
        ),
      );
    }

    // Build the hosts list
    final hosts = <Widget>[];

    // Add creator
    final creator = _creatorDetails[widget.createdBy];
    hosts.add(
      _HostTile(
        name: creator?.name ?? 'Creator',
        email: creator?.email ?? 'Email unavailable',
        isCreator: true,
      ),
    );

    // Add co-hosts
    for (final coHostId in widget.coHostIds) {
      final coHost = _coHostDetails[coHostId];
      final hostName = widget.coHostNamesById[coHostId] ?? 'Co-host';
      hosts.add(
        _HostTile(
          name: coHost?.name ?? hostName,
          email: coHost?.email ?? 'Email unavailable',
          isCreator: false,
        ),
      );
    }

    if (hosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organizers',
          style: TextStyle(
            color: Color(0xFF0D1B2E),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x0F0D1B2E)),
          ),
          child: Column(
            children: hosts,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Host tile widget
// ---------------------------------------------------------------------------

class _HostTile extends StatelessWidget {
  final String name;
  final String email;
  final bool isCreator;

  const _HostTile({
    required this.name,
    required this.email,
    required this.isCreator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCreator ? const Color(0xFFFFF4EB) : const Color(0xFFEDF9F0),
              border: Border.all(
                color: isCreator
                    ? const Color(0x30CB6D22)
                    : const Color(0x302F9E44),
              ),
            ),
            child: Icon(
              isCreator ? Icons.star_rounded : Icons.person_rounded,
              size: 20,
              color:
                  isCreator ? const Color(0xFFCB6D22) : const Color(0xFF2F9E44),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1F334A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCreator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Host',
                          style: TextStyle(
                            color: Color(0xFFCB6D22),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF8B919E),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------

class _OrganizeBackground extends StatelessWidget {
  const _OrganizeBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _OrganizeBackdropPainter(),
        ),
      ),
    );
  }
}

class _OrganizeBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF6F1EB);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final circlePaint = Paint()..color = const Color(0x11CB6D22);
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.08), 48, circlePaint);
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.28), 26, circlePaint);
    canvas.drawCircle(
        Offset(size.width * 0.84, size.height * 0.52), 18, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Hero header
// ---------------------------------------------------------------------------

class _HeroHeader extends StatefulWidget {
  const _HeroHeader();

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 4,
            child: _TwinkleStar(
              animation: _sparkleController,
              phase: 0.0,
              icon: Icons.auto_awesome,
              size: 46,
              color: const Color(0x34CB6D22),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organize with AI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFFCB6D22),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Start a guided conversation\nto build your event.',
                style: TextStyle(
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D1B2E),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Use the AI chat to create an event step by step. The assistant will collect the event details and help you build it faster.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.45,
                  color: Color(0xFF54657B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TwinkleStar extends AnimatedWidget {
  final double phase;
  final IconData icon;
  final double size;
  final Color color;

  const _TwinkleStar({
    required Animation<double> animation,
    required this.phase,
    required this.icon,
    required this.size,
    required this.color,
  }) : super(listenable: animation);

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final double t = (_animation.value + phase) % 1.0;
    final double pulse = (math.sin(t * 2 * math.pi) + 1) / 2;
    final double opacity = 0.58 + (pulse * 0.32);
    final double scale = 0.96 + (pulse * 0.08);
    final double angle = (pulse - 0.5) * 0.05;

    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Open builder card
// ---------------------------------------------------------------------------

class _OpenBuilderCard extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenBuilderCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2E),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x200D1B2E),
                blurRadius: 16,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open event builder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Start the conversation page and let the assistant guide the creation flow.',
                      style: TextStyle(
                        color: Color(0xFFD7DEE8),
                        height: 1.35,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Created events section – entirely redesigned
// ---------------------------------------------------------------------------

class _CreatedEventsSection extends StatefulWidget {
  const _CreatedEventsSection();

  @override
  State<_CreatedEventsSection> createState() => _CreatedEventsSectionState();
}

class _CreatedEventsSectionState extends State<_CreatedEventsSection> {
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();
  bool _showAll = false;

  // -- poster editor (upload / remove) kept from original ----

  Future<void> _openPosterEditor(
    BuildContext context,
    EventModel event,
  ) async {
    if (event.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event cannot be edited yet.')),
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFF6F1EB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCECECE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update event poster',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how you want to update this event poster.',
                style: TextStyle(
                  color: Color(0xFF596A7E),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1B2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context, 'upload'),
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Upload from gallery',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD64545),
                    side: const BorderSide(color: Color(0x30D64545)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context, 'remove'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Remove custom poster',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;

    if (action == 'remove') {
      await _eventService.updateEventPoster(
        eventId: event.id!,
        posterImageUrl: null,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster removed.')),
        );
      }
      return;
    }

    if (action != 'upload') return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please sign in again to upload poster.')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (picked == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected from gallery.')),
        );
      }
      return;
    }

    try {
      final uid = currentUser.uid;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final fileName =
          '${event.id}_${DateTime.now().millisecondsSinceEpoch.toString()}.$ext';
      final app = FirebaseAuth.instance.app;
      final bucket = app.options.storageBucket;
      final fallbackBucket = (bucket != null && bucket.isNotEmpty)
          ? bucket
          : '${app.options.projectId}.firebasestorage.app';
      final storage = FirebaseStorage.instanceFor(bucket: fallbackBucket);

      final ref = storage.ref().child('event_posters/$uid/$fileName');

      final contentType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      };

      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await ref.getDownloadURL();

      await _eventService.updateEventPoster(
        eventId: event.id!,
        posterImageUrl: downloadUrl,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster updated successfully.')),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        final msg = switch (e.code) {
          'unauthorized' =>
            'Upload blocked by Firebase Storage rules. Allow authenticated users for event_posters/{uid}.',
          'object-not-found' =>
            'Storage bucket not found. Create Firebase Storage for this project.',
          _ => 'Poster upload failed: ${e.message ?? e.code}',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Poster upload failed: $e')),
        );
      }
    }
  }

  // -- helpers ----

  String _formatDate(DateTime date) {
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

  String _statusLabel(EventApprovalStatus status) {
    switch (status) {
      case EventApprovalStatus.pending:
        return 'Pending';
      case EventApprovalStatus.accepted:
        return 'Approved';
      case EventApprovalStatus.rejected:
        return 'Rejected';
    }
  }

  IconData _statusIcon(EventApprovalStatus status) {
    switch (status) {
      case EventApprovalStatus.pending:
        return Icons.schedule_rounded;
      case EventApprovalStatus.accepted:
        return Icons.check_circle_rounded;
      case EventApprovalStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  Color _statusColor(EventApprovalStatus status) {
    switch (status) {
      case EventApprovalStatus.pending:
        return const Color(0xFFCB6D22);
      case EventApprovalStatus.accepted:
        return const Color(0xFF2F9E44);
      case EventApprovalStatus.rejected:
        return const Color(0xFFD64545);
    }
  }

  Color _statusBg(EventApprovalStatus status) {
    switch (status) {
      case EventApprovalStatus.pending:
        return const Color(0xFFFFF4EB);
      case EventApprovalStatus.accepted:
        return const Color(0xFFEDF9F0);
      case EventApprovalStatus.rejected:
        return const Color(0xFFFDEDED);
    }
  }

  // -- event detail bottom sheet ----

  void _openEventDetail(BuildContext context, EventModel event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EventDetailSheet(
          event: event,
          onUpdatePoster: () {
            Navigator.pop(context);
            _openPosterEditor(context, event);
          },
          eventService: _eventService,
          authService: _authService,
          formatDate: _formatDate,
          formatTime: _formatTime,
          statusLabel: _statusLabel,
          statusIcon: _statusIcon,
          statusColor: _statusColor,
          statusBg: _statusBg,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCB6D22), Color(0xFFE8943D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Your Events',
                style: TextStyle(
                  color: Color(0xFF0D1B2E),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        // Event list
        StreamBuilder<List<EventModel>>(
          stream: uid == null ? null : _eventService.streamUserEvents(uid),
          builder: (context, snapshot) {
            if (uid == null) {
              return _buildEmptyState(
                icon: Icons.login_rounded,
                title: 'Sign in required',
                subtitle: 'Sign in to view your created events.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final events = snapshot.data ?? const <EventModel>[];
            if (events.isEmpty) {
              return _buildEmptyState(
                icon: Icons.celebration_outlined,
                title: 'No events yet',
                subtitle:
                    'Create your first event using the chatbot above and it will appear here.',
              );
            }

            final visibleEvents = _showAll ? events : events.take(3).toList();
            final hasMore = events.length > 3;

            return Column(
              children: [
                // Event cards
                ...List.generate(visibleEvents.length, (i) {
                  return AnimatedOrganizerCard(
                    index: i,
                    child: OrganizerEventCard(
                      event: visibleEvents[i],
                      onTap: () => _openEventDetail(context, visibleEvents[i]),
                      onPosterTap: () =>
                          _openPosterEditor(context, visibleEvents[i]),
                    ),
                  );
                }),

                // View all / collapse toggle
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showAll = !_showAll),
                        icon: Icon(
                          _showAll
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                        ),
                        label: Text(
                          _showAll
                              ? 'Show less'
                              : 'View all ${events.length} events',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFCB6D22),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0F0D1B2E)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFFCB6D22),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Loading your events...',
            style: TextStyle(
              color: Color(0xFF6A7C90),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0F0D1B2E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D1B2E),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFFCB6D22), size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0D1B2E),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6A7C90),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event detail bottom sheet
// ---------------------------------------------------------------------------

class _EventDetailSheet extends StatefulWidget {
  final EventModel event;
  final VoidCallback onUpdatePoster;
  final EventService eventService;
  final AuthService authService;
  final String Function(DateTime) formatDate;
  final String Function(TimeOfDayData) formatTime;
  final String Function(EventApprovalStatus) statusLabel;
  final IconData Function(EventApprovalStatus) statusIcon;
  final Color Function(EventApprovalStatus) statusColor;
  final Color Function(EventApprovalStatus) statusBg;

  const _EventDetailSheet({
    required this.event,
    required this.onUpdatePoster,
    required this.eventService,
    required this.authService,
    required this.formatDate,
    required this.formatTime,
    required this.statusLabel,
    required this.statusIcon,
    required this.statusColor,
    required this.statusBg,
  });

  @override
  State<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<_EventDetailSheet> {
  static const _categoryGradients = {
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

  void _openEditSheet(BuildContext context) {
    if (widget.event.id == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _EditEventSheet(
          event: widget.event,
          eventService: widget.eventService,
          formatDate: widget.formatDate,
          formatTime: widget.formatTime,
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (widget.event.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF6F1EB),
        title: const Text(
          'Delete Event',
          style:
              TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0D1B2E)),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this event? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF3A5068)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Color(0xFF8A98A9), fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD64545)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await widget.eventService.deleteEvent(widget.event.id!);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted.')),
        );
      }
    }
  }

  Future<void> _processScannedQR(BuildContext context, String qrData) async {
    try {
      final data = jsonDecode(qrData);
      final eventId = data['eventId'];
      final studentId = data['studentId'];
      final uid = data['uid'];
      final name = data['name'];
      final ticketPaidFlag = data['paid'];

      if (eventId is! String || uid is! String || uid.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid QR: missing ticket fields.')),
          );
        }
        return;
      }

      final cleanUid = uid.trim();
      final cleanStudentId = studentId?.toString().trim() ?? '';
      final cleanName = name?.toString().trim().isNotEmpty == true
          ? name.toString().trim()
          : 'Unknown';

      if (eventId != widget.event.id) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid QR: Ticket is for a different event!')),
          );
        }
        return;
      }

      final eventRef =
          FirebaseFirestore.instance.collection('events').doc(eventId);
      final registrationRef =
          eventRef.collection('registrations').doc(cleanUid);
      final isJoinedParticipant = widget.event.joinedParticipantIds
          .map((id) => id.trim())
          .contains(cleanUid);

      final isPaidMode = widget.event.isPaidEvent;
      final ticketSaysPaid = ticketPaidFlag == true;

      if (isPaidMode && !ticketSaysPaid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid paid ticket: this QR is not marked as a paid-event ticket.',
              ),
            ),
          );
        }
        return;
      }

      bool registrationConfirmed = false;
      bool paymentConfirmed = !isPaidMode;

      try {
        final registrationDoc = await registrationRef.get();
        if (!registrationDoc.exists) {
          if (!isPaidMode && isJoinedParticipant) {
            registrationConfirmed = true;
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Check-in denied: attendee is not registered for this event.',
                  ),
                ),
              );
            }
            return;
          }
        } else {
          registrationConfirmed = true;
        }

        if (isPaidMode) {
          if (!registrationDoc.exists) {
            paymentConfirmed = false;
          } else {
            final regData = registrationDoc.data() ?? <String, dynamic>{};
            final paymentStatus =
                regData['paymentStatus']?.toString().trim().toLowerCase() ?? '';
            paymentConfirmed = paymentStatus == 'paid';
          }
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;

        registrationConfirmed = isJoinedParticipant;

        // For paid events, do not assume payment if rules block registration read.
        // Keep this strict to avoid accepting unpaid attendees.
        paymentConfirmed = !isPaidMode;
      }

      if (!registrationConfirmed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Check-in denied: attendee is not registered for this event.',
              ),
            ),
          );
        }
        return;
      }

      if (!paymentConfirmed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Check-in denied: paid-event ticket requires verified payment status.',
              ),
            ),
          );
        }
        return;
      }

      final ref = FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('attendance')
          .doc(cleanUid);

      final doc = await ref.get();
      if (doc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Already checked in: $cleanName ($cleanStudentId)'),
            ),
          );
        }
        return;
      }

      await ref.set({
        'studentId': cleanStudentId,
        'uid': cleanUid,
        'name': cleanName,
        'checkInMode': isPaidMode ? 'paid_ticket' : 'standard_qr',
        'paymentVerified': paymentConfirmed,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPaidMode
                  ? 'Paid ticket verified. Checked in: $cleanName'
                  : 'Checked in successfully: $cleanName',
            ),
            backgroundColor: const Color(0xFF2F9E44),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        final isPermissionError = e.code == 'permission-denied';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionError
                  ? 'Check-in blocked by Firestore rules. Allow host read access to registrations and write access to attendance.'
                  : 'Check-in failed: ${e.message ?? e.code}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code format.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        _categoryGradients[widget.event.category.trim().toLowerCase()] ??
            const [Color(0xFF374151), Color(0xFF6B7280)];
    final sColor = widget.statusColor(widget.event.approvalStatus);
    final sBg = widget.statusBg(widget.event.approvalStatus);
    final isRejected =
        widget.event.approvalStatus == EventApprovalStatus.rejected;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6F1EB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCECECE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Poster / gradient
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: GestureDetector(
                    onTap: (widget.event.posterImageUrl != null &&
                            widget.event.posterImageUrl!.isNotEmpty)
                        ? () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: false,
                                barrierColor: Colors.transparent,
                                pageBuilder: (_, __, ___) =>
                                    _FullScreenImageViewer(
                                  imageUrl: widget.event.posterImageUrl!,
                                  heroTag: 'detail_poster_${widget.event.id}',
                                ),
                                transitionsBuilder: (_, animation, __, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 250),
                                reverseTransitionDuration:
                                    const Duration(milliseconds: 200),
                              ),
                            );
                          }
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _buildDetailPoster(palette),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.event.name,
                        style: const TextStyle(
                          color: Color(0xFF0D1B2E),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sBg,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: sColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.statusIcon(widget.event.approvalStatus),
                                size: 15, color: sColor),
                            const SizedBox(width: 5),
                            Text(
                              widget.statusLabel(widget.event.approvalStatus),
                              style: TextStyle(
                                color: sColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Rejected banner
                      if (isRejected) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEDED),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x20D64545)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 18, color: Color(0xFFD64545)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This event was rejected. Edit details and resubmit for approval.',
                                  style: TextStyle(
                                    color: Color(0xFFB33B3B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Info tiles
                      _DetailTile(
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: widget.event.category,
                        locked: true,
                      ),
                      _DetailTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: widget.formatDate(widget.event.date),
                      ),
                      _DetailTile(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: widget.formatTime(widget.event.time),
                      ),
                      _DetailTile(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: widget.event.location,
                      ),
                      _DetailTile(
                        icon: Icons.people_outline_rounded,
                        label: 'Participants',
                        value: widget.event.hasParticipantLimit
                            ? '${widget.event.joinedParticipantCount} / ${widget.event.attendeeCount ?? '∞'} joined'
                            : 'Open event',
                      ),
                      _DetailTile(
                        icon: Icons.schedule_rounded,
                        label: 'Duration',
                        value:
                            '${widget.event.durationHours} hour${widget.event.durationHours == 1 ? '' : 's'}',
                      ),
                      _DetailTile(
                        icon: Icons.payments_outlined,
                        label: 'Entry',
                        value: widget.event.isPaidEvent
                            ? 'Paid (Rs. ${widget.event.entryFee?.toStringAsFixed(2) ?? '0.00'})'
                            : 'Free',
                      ),
                      _DetailTile(
                        icon: Icons.live_help_outlined,
                        label: 'Live Q&A',
                        value:
                            widget.event.isQnaEnabled ? 'Enabled' : 'Disabled',
                      ),
                      _DetailTile(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'QR Check-in',
                        value: widget.event.isQrAttendanceEnabled
                            ? 'Required'
                            : 'Not required',
                      ),
                      const SizedBox(height: 8),

                      _HostsSection(
                        createdBy: widget.event.createdBy,
                        coHostIds: widget.event.coHostIds,
                        coHostNamesById: widget.event.coHostNamesById,
                        authService: widget.authService,
                      ),
                      const SizedBox(height: 20),

                      // Description section
                      const Text(
                        'Description',
                        style: TextStyle(
                          color: Color(0xFF0D1B2E),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x0F0D1B2E)),
                        ),
                        child: Text(
                          widget.event.description,
                          style: const TextStyle(
                            color: Color(0xFF3A5068),
                            fontSize: 14.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D1B2E),
                                  side: const BorderSide(
                                      color: Color(0x22CB6D22)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: widget.onUpdatePoster,
                                icon:
                                    const Icon(Icons.image_outlined, size: 19),
                                label: const Text(
                                  'Poster',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFCB6D22),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: widget.event.id != null
                                    ? () => _openEditSheet(context)
                                    : null,
                                icon: const Icon(Icons.edit_outlined, size: 19),
                                label: const Text(
                                  'Edit Details',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.event.id != null) ...[
                        const SizedBox(height: 10),
                        if (widget.event.isQrAttendanceEnabled)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFCB6D22),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const QRScannerScreen()),
                                );
                                if (result != null && result is String) {
                                  _processScannedQR(context, result);
                                }
                              },
                              icon: const Icon(Icons.qr_code_scanner_rounded,
                                  size: 19),
                              label: const Text(
                                'Scan Attendees',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        if (widget.event.isQrAttendanceEnabled)
                          const SizedBox(height: 10),
                        if (widget.event.isQrAttendanceEnabled)
                          _LiveAttendanceSection(
                            event: widget.event,
                            authService: widget.authService,
                          ),
                        if (widget.event.isQrAttendanceEnabled)
                          const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD64545),
                              side: const BorderSide(color: Color(0x30D64545)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _confirmDelete(context),
                            icon: const Icon(Icons.delete_outline, size: 19),
                            label: const Text(
                              'Delete Event',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPoster(List<Color> palette) {
    if (widget.event.posterImageUrl != null &&
        widget.event.posterImageUrl!.isNotEmpty) {
      return Hero(
        tag: 'detail_poster_${widget.event.id}',
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.event.posterImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackDetailGradient(palette),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 14,
                child: OrganizerCategoryBadge(label: widget.event.category),
              ),
              // Expand hint icon
              Positioned(
                top: 12,
                right: 14,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _fallbackDetailGradient(palette);
  }

  Widget _fallbackDetailGradient(List<Color> palette) {
    return Container(
      height: 160,
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
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 14,
            child: OrganizerCategoryBadge(label: widget.event.category),
          ),
          Positioned(
            right: 20,
            bottom: 14,
            child: Text(
              widget.event.name.isNotEmpty
                  ? widget.event.name[0].toUpperCase()
                  : 'E',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 72,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail tile – used inside the detail sheet
// ---------------------------------------------------------------------------

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool locked;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x20CB6D22)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFCB6D22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF9A8B78),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.lock_outline_rounded,
                          size: 12, color: Color(0xFFBFAF9B)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF1F334A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit event sheet
// ---------------------------------------------------------------------------

class _EditEventSheet extends StatefulWidget {
  final EventModel event;
  final EventService eventService;
  final String Function(DateTime) formatDate;
  final String Function(TimeOfDayData) formatTime;

  const _EditEventSheet({
    required this.event,
    required this.eventService,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  final AuthService _authService = AuthService();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _posterImageUrl;
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _attendeesCtrl = TextEditingController();
  final TextEditingController _entryFeeCtrl = TextEditingController();
  final TextEditingController _hostSearchCtrl = TextEditingController();
  final FocusNode _hostSearchFocus = FocusNode();
  bool _hasParticipantLimit = false;
  bool _isPaidEvent = false;
  Map<String, String> _coHostNamesById = <String, String>{};
  Map<String, String> _coHostDetailsById = <String, String>{};
  List<UserModel> _hostSearchResults = const [];
  bool _hostSearchHasQueried = false;
  bool _searchingHosts = false;
  bool _updatingPoster = false;
  Timer? _hostSearchDebounce;
  int _hostSearchToken = 0;
  String? _hostSearchError;
  bool _saving = false;

  bool get _isRejected =>
      widget.event.approvalStatus == EventApprovalStatus.rejected;
  bool get _isPending =>
      widget.event.approvalStatus == EventApprovalStatus.pending;
  bool get _canEditSensitiveSettings => _isPending || _isRejected;

  @override
  void initState() {
    super.initState();
    _date = widget.event.date;
    _time = TimeOfDay(
        hour: widget.event.time.hour, minute: widget.event.time.minute);
    _posterImageUrl = widget.event.posterImageUrl;
    _locationCtrl.text = widget.event.location;
    _descriptionCtrl.text = widget.event.description;
    _attendeesCtrl.text = widget.event.attendeeCount?.toString() ?? '';
    _entryFeeCtrl.text = widget.event.entryFee?.toStringAsFixed(2) ?? '';
    _hasParticipantLimit = widget.event.hasParticipantLimit;
    _isPaidEvent = widget.event.isPaidEvent;
    _coHostNamesById = Map<String, String>.from(widget.event.coHostNamesById);
    for (final id in widget.event.coHostIds) {
      _coHostNamesById.putIfAbsent(id, () => 'Host');
      _coHostDetailsById.putIfAbsent(id, () => 'Loading email...');
    }

    _hydrateCoHostEmails();
  }

  Future<void> _hydrateCoHostEmails() async {
    final ids = _coHostNamesById.keys.toList();
    if (ids.isEmpty) return;

    final entries = await Future.wait(
      ids.map((id) async {
        try {
          final profile = await _authService.getUserProfile(id);
          final email = profile?.email.trim() ?? '';
          if (email.isNotEmpty) {
            return MapEntry(id, email);
          }
          return const MapEntry('', '');
        } catch (_) {
          return const MapEntry('', '');
        }
      }),
    );

    if (!mounted) return;

    setState(() {
      for (final entry in entries) {
        if (entry.key.isEmpty) continue;
        _coHostDetailsById[entry.key] = entry.value;
      }
    });
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _attendeesCtrl.dispose();
    _entryFeeCtrl.dispose();
    _hostSearchCtrl.dispose();
    _hostSearchFocus.dispose();
    _hostSearchDebounce?.cancel();
    super.dispose();
  }

  void _onHostQueryChanged(String value) {
    _hostSearchDebounce?.cancel();
    _hostSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _searchHosts();
    });
  }

  Future<void> _searchHosts() async {
    final query = _hostSearchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hostSearchHasQueried = false;
        _hostSearchResults = const [];
        _hostSearchError = null;
      });
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final requestToken = ++_hostSearchToken;

    setState(() {
      _searchingHosts = true;
      _hostSearchError = null;
    });
    try {
      final results = await _authService.searchStudentsByName(
        query: query,
        excludeUserIds: {
          widget.event.createdBy,
          ..._coHostNamesById.keys,
          if (currentUid != null) currentUid,
        },
      );
      if (!mounted) return;
      if (requestToken != _hostSearchToken) return;
      setState(() {
        _hostSearchHasQueried = true;
        _hostSearchResults = results;
        _hostSearchError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _hostSearchHasQueried = true;
          _hostSearchResults = const [];
          _hostSearchError =
              'Could not load suggestions. Check Firestore rules for users read access.';
        });
      }
    } finally {
      if (mounted) setState(() => _searchingHosts = false);
    }
  }

  void _addCoHost(UserModel user) {
    final resolvedName = (user.name?.trim().isNotEmpty ?? false)
        ? user.name!.trim()
        : user.email;
    final email = user.email.trim();

    setState(() {
      _coHostNamesById[user.uid] = resolvedName;
      _coHostDetailsById[user.uid] =
          email.isNotEmpty ? email : 'Email unavailable';
      _hostSearchCtrl.clear();
      _hostSearchHasQueried = false;
      _hostSearchResults = const [];
      _hostSearchError = null;
    });
    _hostSearchFocus.unfocus();
  }

  void _removeCoHost(String uid) {
    setState(() {
      _coHostNamesById.remove(uid);
      _coHostDetailsById.remove(uid);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _replacePoster() async {
    if (_updatingPoster || widget.event.id == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Please sign in again to upload poster.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (picked == null) {
      _showError('No image selected from gallery.');
      return;
    }

    setState(() => _updatingPoster = true);

    try {
      final uid = currentUser.uid;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final fileName =
          '${widget.event.id}_${DateTime.now().millisecondsSinceEpoch.toString()}.$ext';
      final app = FirebaseAuth.instance.app;
      final bucket = app.options.storageBucket;
      final fallbackBucket = (bucket != null && bucket.isNotEmpty)
          ? bucket
          : '${app.options.projectId}.firebasestorage.app';
      final storage = FirebaseStorage.instanceFor(bucket: fallbackBucket);
      final ref = storage.ref().child('event_posters/$uid/$fileName');

      final contentType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      };

      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await ref.getDownloadURL();

      await widget.eventService.updateEventPoster(
        eventId: widget.event.id!,
        posterImageUrl: downloadUrl,
      );

      if (!mounted) return;
      setState(() => _posterImageUrl = downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poster updated successfully.')),
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        final msg = switch (e.code) {
          'unauthorized' =>
            'Upload blocked by Firebase Storage rules. Allow authenticated users for event_posters/{uid}.',
          'object-not-found' =>
            'Storage bucket not found. Create Firebase Storage for this project.',
          _ => 'Poster upload failed: ${e.message ?? e.code}',
        };
        _showError(msg);
      }
    } catch (e) {
      if (mounted) {
        _showError('Poster upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _updatingPoster = false);
    }
  }

  Future<void> _removePoster() async {
    if (_updatingPoster || widget.event.id == null) return;

    setState(() => _updatingPoster = true);

    try {
      await widget.eventService.updateEventPoster(
        eventId: widget.event.id!,
        posterImageUrl: null,
      );
      if (!mounted) return;
      setState(() => _posterImageUrl = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poster removed.')),
      );
    } catch (e) {
      if (mounted) {
        _showError('Poster removal failed: $e');
      }
    } finally {
      if (mounted) setState(() => _updatingPoster = false);
    }
  }

  Future<void> _save({bool resubmit = false}) async {
    if (_saving) return;

    final location = _locationCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final attendees = int.tryParse(_attendeesCtrl.text.trim());
    final fee = double.tryParse(_entryFeeCtrl.text.trim());

    if (location.length < 2) {
      _showError('Location is too short.');
      return;
    }
    if (description.length < 8) {
      _showError('Description must be at least 8 characters.');
      return;
    }
    if (_hasParticipantLimit &&
        _canEditSensitiveSettings &&
        (attendees == null || attendees <= 0)) {
      _showError('Please enter a valid attendee count.');
      return;
    }
    if (_isPaidEvent &&
        _canEditSensitiveSettings &&
        (fee == null || fee <= 0)) {
      _showError('Please enter a valid entry fee amount.');
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.eventService.updateEventDetails(
        eventId: widget.event.id!,
        date: _date,
        timeHour: _time.hour,
        timeMinute: _time.minute,
        location: location,
        description: description,
        hasParticipantLimit:
            _canEditSensitiveSettings ? _hasParticipantLimit : null,
        attendeeCount: (_canEditSensitiveSettings && _hasParticipantLimit)
            ? attendees
            : null,
        isPaidEvent: _canEditSensitiveSettings ? _isPaidEvent : null,
        entryFee: (_canEditSensitiveSettings && _isPaidEvent) ? fee : null,
        coHostIds: _coHostNamesById.keys.toList(),
        coHostNamesById: _coHostNamesById,
        resetApproval: resubmit,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resubmit
              ? 'Event updated and resubmitted for approval.'
              : 'Event details updated.'),
        ),
      );
    } catch (e) {
      if (mounted) _showError('Failed to update: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: const Color(0xFFF3F5F7),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 34,
            color: Color(0xFF9AA8B6),
          ),
          SizedBox(height: 8),
          Text(
            'No banner preview available',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7E8B99),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => widget.formatDate(d);
  String _fmtTime(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final hour12 = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    return '${hour12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFCB6D22),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF0D1B2E),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F1EB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 22 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCECECE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            const Text(
              'Edit Event Details',
              style: TextStyle(
                color: Color(0xFF0D1B2E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),

            // Info about edit policy
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x18CB6D22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFCB6D22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isRejected
                          ? 'Edit and resubmit for admin approval. Name & category cannot be changed.'
                          : 'You can update logistical details. Name & category are locked after submission.',
                      style: const TextStyle(
                        color: Color(0xFF6A5638),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Poster / banner editor
            _sectionLabel('Poster / Banner'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x120D1B2E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _posterImageUrl != null &&
                              _posterImageUrl!.trim().isNotEmpty
                          ? Image.network(
                              _posterImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: const Color(0xFFF3F5F7),
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  _buildPosterPlaceholder(),
                            )
                          : _buildPosterPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _posterImageUrl != null &&
                            _posterImageUrl!.trim().isNotEmpty
                        ? 'Current banner preview'
                        : 'No banner image set yet',
                    style: const TextStyle(
                      color: Color(0xFF1F334A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Replace the banner or remove it from this event.',
                    style: TextStyle(
                      color: Color(0xFF6A7C90),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D1B2E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _updatingPoster ? null : _replacePoster,
                            icon: _updatingPoster
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.swap_horiz_rounded,
                                    size: 19),
                            label: const Text(
                              'Replace',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD64545),
                              side: const BorderSide(color: Color(0x30D64545)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: (_updatingPoster ||
                                    _posterImageUrl == null ||
                                    _posterImageUrl!.trim().isEmpty)
                                ? null
                                : _removePoster,
                            icon: const Icon(Icons.delete_outline, size: 19),
                            label: const Text(
                              'Remove',
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
            const SizedBox(height: 18),

            // Locked fields display
            _LockedFieldDisplay(
              icon: Icons.badge_outlined,
              label: 'Event Name',
              value: widget.event.name,
            ),
            const SizedBox(height: 10),
            _LockedFieldDisplay(
              icon: Icons.category_rounded,
              label: 'Category',
              value: widget.event.category,
            ),
            const SizedBox(height: 18),

            // Editable: Date & Time
            _sectionLabel('Date & Time'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _EditPickerButton(
                    icon: Icons.calendar_today_rounded,
                    label: _fmtDate(_date),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EditPickerButton(
                    icon: Icons.access_time_rounded,
                    label: _fmtTime(_time),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Editable: Location
            _sectionLabel('Location'),
            const SizedBox(height: 8),
            _StyledTextField(
              controller: _locationCtrl,
              hint: 'Event venue or address',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 18),

            // Editable: Participant limit (only if pending/rejected)
            if (_canEditSensitiveSettings) ...[
              _sectionLabel('Participants'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x120D1B2E)),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFCB6D22),
                  value: _hasParticipantLimit,
                  onChanged: (v) {
                    setState(() => _hasParticipantLimit = v);
                    if (!v) _attendeesCtrl.clear();
                  },
                  title: const Text(
                    'Track participant count',
                    style: TextStyle(
                      color: Color(0xFF1F334A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_hasParticipantLimit) ...[
                const SizedBox(height: 10),
                _StyledTextField(
                  controller: _attendeesCtrl,
                  hint: 'Max attendee count',
                  icon: Icons.people_outline_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 18),
            ] else ...[
              _LockedFieldDisplay(
                icon: Icons.people_outline_rounded,
                label: 'Participant Count Tracking',
                value: widget.event.hasParticipantLimit
                    ? 'Enabled (${widget.event.attendeeCount ?? 'N/A'} max)'
                    : 'Disabled',
              ),
              const SizedBox(height: 18),
            ],

            // Editable: Pricing (only if pending/rejected)
            if (_canEditSensitiveSettings) ...[
              _sectionLabel('Pricing'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x120D1B2E)),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFCB6D22),
                  value: _isPaidEvent,
                  onChanged: (v) {
                    setState(() => _isPaidEvent = v);
                    if (!v) _entryFeeCtrl.clear();
                  },
                  title: const Text(
                    'Paid event',
                    style: TextStyle(
                      color: Color(0xFF1F334A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_isPaidEvent) ...[
                const SizedBox(height: 10),
                _StyledTextField(
                  controller: _entryFeeCtrl,
                  hint: 'Entry fee amount (LKR)',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ] else ...[
              _LockedFieldDisplay(
                icon: Icons.payments_outlined,
                label: 'Pricing',
                value: widget.event.isPaidEvent
                    ? 'Paid (Rs. ${widget.event.entryFee?.toStringAsFixed(2) ?? '0.00'})'
                    : 'Free',
              ),
              const SizedBox(height: 18),
            ],

            // Editable: Co-hosts
            _sectionLabel('Co-hosts'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x120D1B2E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search by name and tap a suggestion to add co-hosts.',
                    style: TextStyle(
                      color: Color(0xFF5B6C80),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _hostSearchCtrl,
                    focusNode: _hostSearchFocus,
                    onChanged: _onHostQueryChanged,
                    onSubmitted: (_) => _searchHosts(),
                    decoration: InputDecoration(
                      hintText: 'Type a student name',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: _searchingHosts ? null : _searchHosts,
                        icon: _searchingHosts
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0x190D1B2E)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0x190D1B2E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCB6D22)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_coHostNamesById.isEmpty)
                    const Text(
                      'No co-hosts selected yet.',
                      style: TextStyle(
                        color: Color(0xFF8A97A8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x20CB6D22)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _coHostNamesById.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entries = _coHostNamesById.entries.toList();
                          final entry = entries[index];

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFFFE9D6),
                              child: Text(
                                entry.value.isNotEmpty
                                    ? entry.value[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Color(0xFFCB6D22),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              entry.value,
                              style: const TextStyle(
                                color: Color(0xFF1F334A),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              _coHostDetailsById[entry.key] ??
                                  'Email unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6A7C90),
                                fontSize: 11.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove co-host',
                              onPressed: () => _removeCoHost(entry.key),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFD64545),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_hostSearchCtrl.text.trim().isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Start typing a name to get suggestions.',
                      style: TextStyle(
                        color: Color(0xFF8A97A8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    if (_searchingHosts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_hostSearchError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _hostSearchError!,
                          style: const TextStyle(
                            color: Color(0xFFD64545),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (_hostSearchHasQueried &&
                        _hostSearchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No matching students found.',
                          style: TextStyle(
                            color: Color(0xFF8A97A8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (_hostSearchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x140D1B2E)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _hostSearchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final candidate = _hostSearchResults[index];
                            final title =
                                (candidate.name?.trim().isNotEmpty ?? false)
                                    ? candidate.name!.trim()
                                    : candidate.email;
                            final subtitle =
                                candidate.name?.trim().isNotEmpty == true
                                    ? candidate.email
                                    : candidate.studentId;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _addCoHost(candidate),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: const Color(0xFFFFF1E6),
                                    child: Text(
                                      title.isNotEmpty
                                          ? title[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(
                                        color: Color(0xFFCB6D22),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Color(0xFF1F334A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: subtitle == null || subtitle.isEmpty
                                      ? null
                                      : Text(
                                          subtitle,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                  trailing: const Icon(
                                    Icons.add_circle_rounded,
                                    color: Color(0xFF2F9E44),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Editable: Description
            _sectionLabel('Description'),
            const SizedBox(height: 8),
            _StyledTextField(
              controller: _descriptionCtrl,
              hint: 'Event description',
              icon: Icons.notes_rounded,
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),

            // Submit buttons
            if (_isRejected) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFCB6D22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving ? null : () => _save(resubmit: true),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 19),
                  label: Text(
                    _saving
                        ? 'Resubmitting...'
                        : 'Save & Resubmit for Approval',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Status will reset to Pending',
                  style: TextStyle(
                    color: Color(0xFF6A7C90),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFCB6D22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving ? null : () => _save(),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    _saving ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked field display (non-editable)
// ---------------------------------------------------------------------------

class _LockedFieldDisplay extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LockedFieldDisplay({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x10CB6D22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF9A8B78)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF9A8B78),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline_rounded,
                        size: 11, color: Color(0xFFBFAF9B)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF4A3F33),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Styled text field for edit sheet
// ---------------------------------------------------------------------------

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int minLines;
  final int? maxLines;
  final TextInputType keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiline = minLines > 1 || (maxLines ?? 1) > 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x120D1B2E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D1B2E),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textAlignVertical:
            isMultiline ? TextAlignVertical.top : TextAlignVertical.center,
        cursorColor: const Color(0xFFCB6D22),
        style: const TextStyle(
          color: Color(0xFF1F334A),
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          alignLabelWithHint: isMultiline,
          prefixIcon: Padding(
            padding: EdgeInsets.only(top: isMultiline ? 12 : 0),
            child: Icon(icon, size: 20, color: const Color(0xFFCB6D22)),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 44,
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFB8ADA0),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit picker button (date / time)
// ---------------------------------------------------------------------------

class _EditPickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _EditPickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x120D1B2E)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060D1B2E),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFCB6D22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1F334A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFCB6D22)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen image viewer with pinch-to-zoom
// ---------------------------------------------------------------------------

class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;
  late final Animation<double> _bgOpacity;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _bgOpacity = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _bgController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated dark backdrop
          FadeTransition(
            opacity: _bgOpacity,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(color: const Color(0xF0000000)),
            ),
          ),

          // Zoomable image
          Center(
            child: Hero(
              tag: widget.heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    final total = loadingProgress.expectedTotalBytes;
                    final loaded = loadingProgress.cumulativeBytesLoaded;
                    return Center(
                      child: CircularProgressIndicator(
                        value: total != null ? loaded / total : null,
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: FadeTransition(
              opacity: _bgOpacity,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // Pinch-to-zoom hint (shows briefly)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _bgOpacity,
              child: const Center(
                child: Text(
                  'Pinch to zoom  •  Tap background to close',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

// ---------------------------------------------------------------------------
// Live Attendance Section
// ---------------------------------------------------------------------------

class _LiveAttendanceSection extends StatefulWidget {
  final EventModel event;
  final AuthService authService;

  const _LiveAttendanceSection({
    required this.event,
    required this.authService,
  });

  @override
  State<_LiveAttendanceSection> createState() => _LiveAttendanceSectionState();
}

class _LiveAttendanceSectionState extends State<_LiveAttendanceSection> {
  bool _isLoadingProfiles = true;
  final Map<String, UserModel> _profiles = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void didUpdateWidget(covariant _LiveAttendanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.joinedParticipantIds.length !=
        widget.event.joinedParticipantIds.length) {
      _loadProfiles();
    }
  }

  Future<void> _loadProfiles() async {
    final idsToLoad = widget.event.joinedParticipantIds
        .where((uid) => !_profiles.containsKey(uid))
        .toList();
    if (idsToLoad.isEmpty) {
      if (mounted && _isLoadingProfiles) {
        setState(() => _isLoadingProfiles = false);
      }
      return;
    }

    if (mounted && !_isLoadingProfiles)
      setState(() => _isLoadingProfiles = true);

    try {
      final futures = idsToLoad.map((uid) async {
        final profile = await widget.authService.getUserProfile(uid);
        if (profile != null) {
          _profiles[uid] = profile;
        }
      });
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error loading attendee profiles: $e');
    }

    if (mounted) {
      setState(() => _isLoadingProfiles = false);
    }
  }

  Future<void> _removeAttendance(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Attendance?'),
        content: Text(
            'Are you sure you want to remove $name from the checked-in list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Remove', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ref = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event.id)
        .collection('attendance')
        .doc(uid);

    try {
      await ref.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating attendance: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.id == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('attendance')
          .snapshots(),
      builder: (context, snapshot) {
        final checkedInDocs = snapshot.data?.docs ?? [];
        final checkedInIds = checkedInDocs.map((doc) => doc.id).toSet();

        final extraNames = <String, String>{};
        for (final doc in checkedInDocs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null &&
              !widget.event.joinedParticipantIds.contains(doc.id)) {
            final name = data['name'] ?? 'Unknown';
            final sId = data['studentId'] ?? '';
            extraNames[doc.id] = '$name ($sId)';
          }
        }

        final total =
            widget.event.joinedParticipantIds.length + extraNames.length;
        final checkedInCount = checkedInDocs.length;

        final progress = total > 0 ? (checkedInCount / total) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Attendance',
              style: TextStyle(
                color: Color(0xFF0D1B2E),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x0F0D1B2E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$checkedInCount / $total Checked In',
                        style: const TextStyle(
                          color: Color(0xFF3A5068),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFFCB6D22),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFF6F1EB),
                      color: const Color(0xFF1A8A5A),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (total == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No participants registered yet.',
                          style:
                              TextStyle(color: Color(0xFF8A98A9), fontSize: 13),
                        ),
                      ),
                    )
                  else if (_isLoadingProfiles && _profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Color(0xFFCB6D22)),
                        ),
                      ),
                    )
                  else
                    ..._buildParticipantRows(checkedInIds, extraNames),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildParticipantRows(
      Set<String> checkedInIds, Map<String, String> extraNames) {
    if (checkedInIds.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No attendees have checked in yet.',
              style: TextStyle(color: Color(0xFF8A98A9), fontSize: 13),
            ),
          ),
        )
      ];
    }

    final allIds = checkedInIds.toList();

    allIds.sort((a, b) {
      final aName = _profiles[a]?.name ?? extraNames[a] ?? 'Z_Unknown';
      final bName = _profiles[b]?.name ?? extraNames[b] ?? 'Z_Unknown';
      return aName.compareTo(bName);
    });

    return allIds.map((uid) {
      final profile = _profiles[uid];

      final name = profile?.name ?? extraNames[uid] ?? 'Loading...';
      final sId = profile?.studentId ?? (extraNames[uid] != null ? '' : '');
      final displayId =
          sId.isNotEmpty ? sId : (profile?.uid.substring(0, 8) ?? 'Unknown');

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF1A8A5A),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF0D1B2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayId,
                    style: const TextStyle(
                      color: Color(0xFF8A98A9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _removeAttendance(uid, name);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFB2DFCA),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF1A8A5A),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Checked In',
                        style: TextStyle(
                          color: Color(0xFF1A8A5A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
