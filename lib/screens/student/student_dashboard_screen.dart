import 'package:flutter/material.dart';

import 'pages/student_discovery_page.dart';
import 'pages/student_organize_page.dart';
import 'pages/student_profile_page.dart';
import 'pages/student_schedule_page.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      body: SafeArea(
        child: Column(
          children: [
            _StudentTopBar(),
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
  const _StudentTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Premium app name with gradient-like accent
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: const [Color(0xFFCB6D22), Color(0xFFF49B3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'UniHub',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Spacer(),
          // Notification bell with minimal modern style
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFCB6D22).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                // TODO: Implement notifications for events and schedules
              },
              padding: const EdgeInsets.all(8),
              icon: const Icon(
                Icons.notifications_rounded,
                color: Color(0xFFCB6D22),
                size: 22,
              ),
            ),
          ),
        ],
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
