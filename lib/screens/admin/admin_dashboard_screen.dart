import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/auth_shell_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D1B2E),
        elevation: 0,
        title: const Text(
          'Admin',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthShellScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const Center(
        child: Text(
          'Admin page is being rebuilt.',
          style: TextStyle(
            color: Color(0xFF0D1B2E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
