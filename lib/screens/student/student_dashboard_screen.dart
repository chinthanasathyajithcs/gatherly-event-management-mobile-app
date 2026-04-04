import 'package:flutter/material.dart';

import 'pages/student_discovery_page.dart';
import 'pages/student_organize_page.dart';
import 'pages/student_profile_page.dart';
import 'pages/student_schedule_page.dart';
import '../../services/auth_service.dart';
import '../auth/auth_shell_screen.dart';

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

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthShellScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      body: SafeArea(
        child: Column(
          children: [
            _StudentTopBar(
              onSignOut: () => _signOut(context),
              onProfileTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
              },
            ),
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
  final VoidCallback onSignOut;
  final VoidCallback onProfileTap;

  const _StudentTopBar({
    required this.onSignOut,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_rounded,
            color: Color(0xFFCB6D22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'UniHub',
              style: TextStyle(
                color: Color(0xFF0D1B2E),
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'profile') {
                onProfileTap();
                return;
              }
              if (value == 'signout') {
                onSignOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'profile',
                child: Text('Open Profile'),
              ),
              PopupMenuItem<String>(
                value: 'signout',
                child: Text('Sign Out'),
              ),
            ],
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF0D1B2E),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFFF6F1EB),
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
