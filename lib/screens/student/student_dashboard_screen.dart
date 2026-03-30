import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/role_select_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Student';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF122240),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: Color(0xFFC4A052), size: 22),
            SizedBox(width: 8),
            Text('UniEvents',
                style: TextStyle(
                    color: Color(0xFFF0EADC),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Color(0xFF8A9AB5), size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: Color(0xFF8A9AB5), size: 20),
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A2F50), Color(0xFF122240)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0x33C4A052)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFC4A052).withOpacity(0.2),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                                color: Color(0xFFC4A052),
                                fontWeight: FontWeight.w700,
                                fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $name! 👋',
                            style: const TextStyle(
                                color: Color(0xFFF0EADC),
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 3),
                        const Text('Discover upcoming events',
                            style: TextStyle(
                                color: Color(0xFF8A9AB5), fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // My registrations stats
            const Row(
              children: [
                _StatCard(
                    icon: Icons.event_available_rounded,
                    label: 'Registered',
                    value: '3',
                    color: Color(0xFFC4A052)),
                SizedBox(width: 12),
                _StatCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'Upcoming',
                    value: '8',
                    color: Color(0xFF5B8FE8)),
              ],
            ),

            const SizedBox(height: 28),

            const Text('UPCOMING EVENTS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF8A9AB5))),

            const SizedBox(height: 14),

            // Sample event cards
            const _EventCard(
              title: 'Tech Innovation Summit 2024',
              date: 'Apr 12, 2024 · 9:00 AM',
              location: 'Main Auditorium',
              category: 'Technology',
              spots: 45,
              categoryColor: Color(0xFF5B8FE8),
            ),
            const SizedBox(height: 10),
            const _EventCard(
              title: 'Cultural Fest — Spring Edition',
              date: 'Apr 20, 2024 · 2:00 PM',
              location: 'University Grounds',
              category: 'Cultural',
              spots: 200,
              categoryColor: Color(0xFFE8A030),
            ),
            const SizedBox(height: 10),
            const _EventCard(
              title: 'Career & Internship Fair',
              date: 'May 5, 2024 · 10:00 AM',
              location: 'Engineering Block B',
              category: 'Career',
              spots: 12,
              categoryColor: Color(0xFF5BA85E),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x33C4A052)),
                  foregroundColor: const Color(0xFFC4A052),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View All Events',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF122240),
          border: Border.all(color: const Color(0x33C4A052)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Color(0xFFF0EADC),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF8A9AB5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;
  final String category;
  final int spots;
  final Color categoryColor;

  const _EventCard({
    required this.title,
    required this.date,
    required this.location,
    required this.category,
    required this.spots,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF122240),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(category,
                    style: TextStyle(
                        color: categoryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              const Spacer(),
              Text('$spots spots left',
                  style: TextStyle(
                      color: spots < 20 ? const Color(0xFFE05252) : const Color(0xFF5BA85E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFF0EADC),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: Color(0xFF8A9AB5), size: 12),
              const SizedBox(width: 5),
              Text(date,
                  style: const TextStyle(
                      color: Color(0xFF8A9AB5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF8A9AB5), size: 12),
              const SizedBox(width: 5),
              Text(location,
                  style: const TextStyle(
                      color: Color(0xFF8A9AB5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC4A052),
                foregroundColor: const Color(0xFF0D1B2E),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Register Now',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
