import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/role_select_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC4A052).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFFC4A052), size: 12),
                SizedBox(width: 4),
                Text('ADMIN',
                    style: TextStyle(
                        color: Color(0xFFC4A052),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF8A9AB5), size: 20),
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
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC4A052), Color(0xFF7A5C1E)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Color(0xFF0D1B2E), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back, Admin!',
                            style: TextStyle(
                                color: Color(0xFFF0EADC),
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(user?.email ?? '',
                            style: const TextStyle(
                                color: Color(0xFF8A9AB5), fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats row
            const Row(
              children: [
                _StatCard(icon: Icons.event_rounded, label: 'Events', value: '12'),
                SizedBox(width: 12),
                _StatCard(icon: Icons.people_rounded, label: 'Students', value: '248'),
                SizedBox(width: 12),
                _StatCard(icon: Icons.how_to_reg_rounded, label: 'Registrations', value: '531'),
              ],
            ),

            const SizedBox(height: 28),

            const Text('QUICK ACTIONS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF8A9AB5))),
            const SizedBox(height: 14),

            _ActionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create New Event',
              subtitle: 'Schedule and publish a university event',
              color: const Color(0xFFC4A052),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.people_outline_rounded,
              title: 'Manage Students',
              subtitle: 'View and manage registered students',
              color: const Color(0xFF5BA85E),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.bar_chart_rounded,
              title: 'View Reports',
              subtitle: 'Attendance and event analytics',
              color: const Color(0xFF5B8FE8),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.notifications_outlined,
              title: 'Send Notifications',
              subtitle: 'Broadcast announcements to students',
              color: const Color(0xFFE8A030),
              onTap: () {},
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

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF122240),
          border: Border.all(color: const Color(0x33C4A052)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFC4A052), size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFFF0EADC),
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8A9AB5), fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF122240),
          border: Border.all(color: const Color(0x22FFFFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFFF0EADC),
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF8A9AB5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A9AB5), size: 18),
          ],
        ),
      ),
    );
  }
}
