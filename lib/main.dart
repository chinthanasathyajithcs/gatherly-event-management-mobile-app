import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/user_model.dart';
import 'screens/auth/auth_shell_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC4A052)),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const AuthWrapper(),
    );
  }
}

// Automatically routes user based on auth state + role
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1B2E),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFC4A052)),
            ),
          );
        }

        // Not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const AuthShellScreen();
        }

        // Logged in — check role from Firestore
        return FutureBuilder<UserModel?>(
          future: AuthService().getUserProfile(snapshot.data!.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0D1B2E),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFC4A052)),
                ),
              );
            }

            final profile = profileSnap.data;
            if (profile == null) return const AuthShellScreen();

            final role = profile.role;
            if (role == 'admin') return const AdminDashboardScreen();
            if (role == 'student') return const StudentDashboardScreen();

            // Unknown role — back to auth shell
            return const AuthShellScreen();
          },
        );
      },
    );
  }
}
