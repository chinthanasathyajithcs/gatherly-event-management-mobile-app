import 'package:flutter/material.dart';
import 'package:event_management_app/services/auth_service.dart';
import 'package:event_management_app/widgets/custom_text_field.dart';
import 'package:event_management_app/screens/student/student_dashboard_screen.dart';
import'package:event_management_app/screens/auth/student_register_screen.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await _authService.studentLogin(
        email: _emailCtrl.text,
        password: _passCtrl.text,
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

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        setState(() => _googleLoading = false);
        return;
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your email first to reset password.');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(_emailCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent!'),
          backgroundColor: Color(0xFF5BA85E),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF8A9AB5), size: 18),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4A052).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFFC4A052).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, color: Color(0xFFC4A052), size: 12),
                      SizedBox(width: 5),
                      Text('STUDENT',
                          style: TextStyle(
                              color: Color(0xFFC4A052),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Welcome Back',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0EADC))),
                const SizedBox(height: 6),
                const Text('Sign in to your student account',
                    style: TextStyle(color: Color(0xFF8A9AB5), fontSize: 13.5)),

                const SizedBox(height: 32),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE05252).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFFE05252).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFE05252), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFFE05252), fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _googleLoading ? null : _googleSignIn,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      foregroundColor: const Color(0xFFF0EADC),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _googleLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFFF0EADC), strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.google.com/favicon.ico',
                                width: 18,
                                height: 18,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.login, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Text('Continue with Google',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500, fontSize: 14)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR SIGN IN WITH EMAIL',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  ],
                ),

                const SizedBox(height: 22),

                CustomTextField(
                  label: 'University Email',
                  hint: 'you@university.edu',
                  controller: _emailCtrl,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),

                CustomTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passCtrl,
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot password?',
                        style: TextStyle(
                            color: Color(0xFFC4A052),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4A052),
                      foregroundColor: const Color(0xFF0D1B2E),
                      disabledBackgroundColor: const Color(0xFFC4A052).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFF0D1B2E), strokeWidth: 2.5),
                          )
                        : const Text('Sign In',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.5)),
                  ),
                ),

                const SizedBox(height: 20),

                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("No account? ",
                          style: TextStyle(color: Color(0xFF8A9AB5), fontSize: 13)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StudentRegisterScreen()),
                        ),
                        child: const Text('Create one',
                            style: TextStyle(
                                color: Color(0xFFC4A052),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A052))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
