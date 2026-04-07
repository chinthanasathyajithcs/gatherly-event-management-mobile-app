import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import 'student_discovery_page.dart';
import 'student_organize_page.dart';
import 'student_preferences_screen.dart';
import 'student_profile_page.dart';
import 'student_notifications_screen.dart';
import 'student_schedule_page.dart';

class StudentDashboardScreen extends StatefulWidget {
  final int initialIndex;

  const StudentDashboardScreen({super.key, this.initialIndex = 0});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late int _selectedIndex;

  List<Widget> get _pages => [
        StudentDiscoveryPage(
          onOpenOrganize: () => setState(() => _selectedIndex = 2),
        ),
        const StudentSchedulePage(),
        const StudentOrganizePage(),
        const StudentProfilePage(),
      ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StudentPreferencesBottomSheet.checkAndShow(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      body: SafeArea(
        child: Column(
          children: [
            const _StudentTopBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140D1B2E),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _StudentBottomNavItem(
                isSelected: _selectedIndex == 0,
                label: 'Discovery',
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _StudentBottomNavItem(
                isSelected: _selectedIndex == 1,
                label: 'Schedule',
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _StudentBottomNavItem(
                isSelected: _selectedIndex == 2,
                label: 'Organize',
                icon: Icons.dashboard_customize_outlined,
                activeIcon: Icons.dashboard_customize,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _StudentBottomNavItem(
                isSelected: _selectedIndex == 3,
                label: 'Profile',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentTopBar extends StatelessWidget {
  const _StudentTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B2E).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Brand name with decorative dots
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Gatherly',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D1B2E),
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                // Decorative dots
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCB6D22),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1B2E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Builder(
              builder: (context) {
                final uid = FirebaseAuth.instance.currentUser?.uid;

                return StreamBuilder<int>(
                  stream: uid == null
                      ? Stream<int>.value(0)
                      : NotificationService.instance.streamUnreadCount(uid),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    final hasUnread = unreadCount > 0;

                    return Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F1EB),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const StudentNotificationsScreen(),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                color: Color(0xFF3A5068),
                                size: 23,
                              ),
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            top: 9,
                            right: 11,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCB6D22),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFF6F1EB),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentBottomNavItem extends StatelessWidget {
  final bool isSelected;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final VoidCallback onTap;

  const _StudentBottomNavItem({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFFEA6A1A);
    const Color inactiveColor = Color(0xFF738196);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
