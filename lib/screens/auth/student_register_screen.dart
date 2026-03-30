import 'package:flutter/material.dart';
import 'package:event_management_app/services/auth_service.dart';
import 'package:event_management_app/widgets/custom_text_field.dart';
import 'package:event_management_app/screens/student/student_dashboard_screen.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  String? _selectedDept;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  final List<String> _departments = [
    'computing',
    'Engineering and science',
    'Business',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  int get _passwordStrength {
    final p = _passCtrl.text;
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
        return const Color(0xFFE05252);
      case 2:
        return const Color(0xFFE8A030);
      case 3:
        return const Color(0xFF5BA85E);
      default:
        return const Color(0xFFC4A052);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDept == null) {
      setState(() => _error = 'Please select your department.');
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

  Future<void> _googleSignUp() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4A052).withOpacity(0.12),
                    border: Border.all(
                        color: const Color(0xFFC4A052).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          color: Color(0xFFC4A052), size: 12),
                      SizedBox(width: 5),
                      Text('CREATE ACCOUNT',
                          style: TextStyle(
                              color: Color(0xFFC4A052),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Join UniEvents',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0EADC))),
                const SizedBox(height: 6),
                const Text('Register your student account',
                    style: TextStyle(color: Color(0xFF8A9AB5), fontSize: 13.5)),

                const SizedBox(height: 28),

                // Google signup
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _googleLoading ? null : _googleSignUp,
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
                              const Text('Sign up with Google',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR FILL IN YOUR DETAILS',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ),
                    Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.1))),
                  ],
                ),
                const SizedBox(height: 22),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE05252).withOpacity(0.1),
                      border: Border.all(
                          color: const Color(0xFFE05252).withOpacity(0.3)),
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

                CustomTextField(
                  label: 'Full Name',
                  hint: 'Jane Smith',
                  controller: _nameCtrl,
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Full name is required' : null,
                ),

                // Student ID + Department row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Student ID',
                        hint: '2024CS001',
                        controller: _studentIdCtrl,
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEPARTMENT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF8A9AB5))),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              border: Border.all(
                                  color: _selectedDept == null && _error != null
                                      ? const Color(0xFFE05252)
                                      : const Color(0x33C4A052)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDept,
                                isExpanded: true,
                                hint: const Text('Select…',
                                    style: TextStyle(
                                        color: Color(0x508A9AB5),
                                        fontSize: 13)),
                                dropdownColor: const Color(0xFF122240),
                                style: const TextStyle(
                                    color: Color(0xFFF0EADC), fontSize: 13),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFF8A9AB5),
                                    size: 18),
                                onChanged: (v) =>
                                    setState(() => _selectedDept = v),
                                items: _departments
                                    .map((d) => DropdownMenuItem(
                                        value: d, child: Text(d)))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),

                CustomTextField(
                  label: 'University Email',
                  hint: 'jane@university.edu',
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
                  hint: 'Min. 6 characters',
                  controller: _passCtrl,
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),

                // Password strength
                if (_passCtrl.text.isNotEmpty) ...[
                  Row(
                    children: List.generate(4, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: i < _passwordStrength
                                ? _strengthColor
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(_strengthLabel,
                      style: TextStyle(fontSize: 11, color: _strengthColor)),
                  const SizedBox(height: 12),
                ],

                CustomTextField(
                  label: 'Confirm Password',
                  hint: 'Repeat password',
                  controller: _confirmCtrl,
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please confirm password';
                    if (v != _passCtrl.text) return "Passwords don't match";
                    return null;
                  },
                ),

                const SizedBox(height: 4),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4A052),
                      foregroundColor: const Color(0xFF0D1B2E),
                      disabledBackgroundColor:
                          const Color(0xFFC4A052).withOpacity(0.5),
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
                        : const Text('Create Student Account',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.5)),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF8A9AB5),
                          height: 1.6),
                      children: [
                        TextSpan(text: 'By registering you agree to the '),
                        TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                                color: Color(0xFFC4A052),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A052))),
                        TextSpan(text: ' and '),
                        TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                                color: Color(0xFFC4A052),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFC4A052))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
