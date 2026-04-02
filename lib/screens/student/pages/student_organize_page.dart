import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
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
                        const SizedBox(height: 14),
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
                  color: Colors.white.withOpacity(0.12),
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

class _CreatedEventsSection extends StatelessWidget {
  const _CreatedEventsSection();

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final eventService = EventService();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x140D1B2E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0D1B2E),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: StreamBuilder<List<EventModel>>(
        stream: uid == null ? null : eventService.streamUserEvents(uid),
        builder: (context, snapshot) {
          final events = snapshot.data ?? const <EventModel>[];
          final count = events.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4E8DD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: Color(0xFFCB6D22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Your created events',
                      style: TextStyle(
                        color: Color(0xFF0D1B2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x190D1B2E)),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Color(0xFF41546A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (uid == null)
                const Text(
                  'Sign in to view your created events.',
                  style: TextStyle(
                    color: Color(0xFF596A7E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFFCB6D22),
                      ),
                    ),
                  ),
                )
              else if (events.isEmpty)
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No events created yet.',
                        style: TextStyle(
                          color: Color(0xFF596A7E),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.event_busy_rounded,
                      color: Color(0xFFCB6D22),
                    ),
                  ],
                )
              else
                Column(
                  children: events
                      .take(3)
                      .map(
                        (event) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFD),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x160D1B2E)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4E8DD),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event_rounded,
                                  color: Color(0xFFCB6D22),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF1F334A),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${event.category}  |  ${_formatDate(event.date)}  |  ${_formatTime(event.time)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF66778A),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}
