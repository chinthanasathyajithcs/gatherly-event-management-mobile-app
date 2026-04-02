import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../student/student_dashboard_screen.dart';
import 'admin_login_screen.dart';
import 'google_profile_completion_screen.dart';
import 'auth_forms.dart';

class AuthShellScreen extends StatefulWidget {
  const AuthShellScreen({super.key});

  @override
  State<AuthShellScreen> createState() => _AuthShellScreenState();
}

class _AuthShellScreenState extends State<AuthShellScreen> {
  final _authService = AuthService();

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  final _nameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLoginMode = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _selectedDept;
  String? _error;

  final List<String> _departments = [
    'Computing',
    'Engineering and Science',
    'Business',
  ];

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  int get _passwordStrength {
    final p = _regPassCtrl.text;
    if (p.length < 6) return 1;
    int score = 1;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[^a-zA-Z0-9]'))) score++;
    return score.clamp(1, 4);
  }

  String get _strengthLabel {
    switch (_passwordStrength) {
      case 1:
        return 'Too short';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      default:
        return 'Strong';
    }
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 1:
        return const Color(0xFFD46D1D);
      case 2:
        return const Color(0xFFE47D26);
      case 3:
        return const Color(0xFFE99239);
      default:
        return const Color(0xFFEA6A1A);
    }
  }

  void _setMode(bool loginMode) {
    if (_isLoginMode == loginMode) return;
    setState(() {
      _isLoginMode = loginMode;
      _error = null;
    });
  }

  Future<void> _studentLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.studentLogin(
        email: _loginEmailCtrl.text,
        password: _loginPassCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _studentRegister() async {
    final isFormValid = _registerFormKey.currentState!.validate();
    final isDepartmentValid = _selectedDept != null;

    if (!isFormValid || !isDepartmentValid) {
      setState(() {
        if (!isDepartmentValid) {
          _error = 'Please select your department.';
        }
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.studentRegister(
        name: _nameCtrl.text,
        studentId: _studentIdCtrl.text,
        department: _selectedDept!,
        email: _regEmailCtrl.text,
        password: _regPassCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleAuth() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      if (!mounted) return;

      // Check if profile is complete, otherwise navigate to completion screen
      if (!user.isProfileComplete) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => GoogleProfileCompletionScreen(profile: user),
          ),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first to reset password.');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent!'),
          backgroundColor: Color(0xFFCB6D22),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF111827).withOpacity(0.04),
                      blurRadius: 28,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFF6D9BB)),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Color(0xFFE96A1A), size: 28),
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        'UniHub',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'One organized place to sign in or create your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AuthModeButton(
                              title: 'Sign In',
                              selected: _isLoginMode,
                              onTap: () => _setMode(true),
                            ),
                          ),
                          Expanded(
                            child: AuthModeButton(
                              title: 'Create Account',
                              selected: !_isLoginMode,
                              onTap: () => _setMode(false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF3D6C2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFE96A1A), size: 17),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _isLoginMode
                          ? AuthLoginForm(
                              key: const ValueKey('login-form'),
                              formKey: _loginFormKey,
                              emailCtrl: _loginEmailCtrl,
                              passCtrl: _loginPassCtrl,
                              loading: _loading,
                              googleLoading: _googleLoading,
                              onGoogleTap: _googleAuth,
                              onForgotPasswordTap: _forgotPassword,
                              onSubmit: _studentLogin,
                            )
                          : AuthRegisterForm(
                              key: const ValueKey('register-form'),
                              formKey: _registerFormKey,
                              nameCtrl: _nameCtrl,
                              studentIdCtrl: _studentIdCtrl,
                              emailCtrl: _regEmailCtrl,
                              passCtrl: _regPassCtrl,
                              confirmCtrl: _confirmCtrl,
                              loading: _loading,
                              googleLoading: _googleLoading,
                              departments: _departments,
                              selectedDept: _selectedDept,
                              strengthLabel: _strengthLabel,
                              strengthColor: _strengthColor,
                              passwordStrength: _passwordStrength,
                              onDeptChanged: (value) {
                                setState(() {
                                  _selectedDept = value;
                                });
                              },
                              onGoogleTap: _googleAuth,
                              onSubmit: _studentRegister,
                            ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Are you an admin?',
                          style: TextStyle(
                            color: Color(0xFFE96A1A),
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
