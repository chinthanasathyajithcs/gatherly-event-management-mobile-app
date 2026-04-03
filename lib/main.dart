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
  final projectId = dotenv.env['FIREBASE_PROJECT_ID']!;
  final configuredBucket = dotenv.env['FIREBASE_STORAGE_BUCKET']?.trim();
  final storageBucket =
      (configuredBucket != null && configuredBucket.isNotEmpty)
          ? configuredBucket
          : '$projectId.firebasestorage.app';

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: projectId,
      storageBucket: storageBucket,
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
          return const _AppLoadingScreen();
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
              return const _AppLoadingScreen();
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

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      body: Center(
        child: Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120D1B2E),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.auto_awesome,
                color: Color(0xFFCB6D22),
                size: 30,
              ),
              SizedBox(height: 12),
              Text(
                'UniHub',
                style: TextStyle(
                  color: Color(0xFF0D1B2E),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Getting things ready...',
                style: TextStyle(
                  color: Color(0xFF66778A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: Color(0xFFCB6D22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
