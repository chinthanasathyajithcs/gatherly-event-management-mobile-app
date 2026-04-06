import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final AuthService _auth = AuthService();

  String? studentName;
  String? studentId;
  String? studentEmail;

  bool _isLoading = true;

  final String eventId = "EVENT001";

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = _auth.getCurrentUser();
    if (user != null) {
      final data = await _auth.getStudentData(user.uid);
      if (mounted) {
        setState(() {
          studentName = data?['name'] ?? 'Student';
          studentId = data?['studentId'] ?? 'Not assigned';
          studentEmail = user.email ?? '';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateQRData() {
    final user = _auth.getCurrentUser();
    return jsonEncode({
      "studentId": studentId?.trim(),
      "uid": user?.uid ?? '',
      "eventId": eventId,
      "name": studentName?.trim(),
    });
  }

  void _showQRDialog() {
    final qrData = _generateQRData();
    final GlobalKey qrKey = GlobalKey();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16161F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF7C6AF7), width: 1),
          ),
          title: const Text(
            "Your Event QR Code",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Event: $eventId',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              Text(
                'Student: ${studentName?.trim()}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  width: 220,
                  height: 220,
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: qrData,
                    size: 196,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadQR(qrKey, dialogContext),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text("Download QR"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C6AF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadQR(GlobalKey qrKey, BuildContext dialogContext) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final RenderRepaintBoundary boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showSnack("Failed to generate QR image");
        return;
      }

      final Uint8List bytes = byteData.buffer.asUint8List();

      // Clean the studentId — remove ALL spaces and special characters
      final String cleanId =
          (studentId ?? 'unknown').trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      // Use timestamp to guarantee unique filename every time
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "QR_${cleanId}_${timestamp}.png";

      // Try multiple save locations in order
      String? savedPath;

      // Location 1: App external files dir (always works, no permissions needed)
      try {
        final Directory? extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final File file = File("${extDir.path}/$fileName");
          await file.writeAsBytes(bytes);
          savedPath = file.path;
        }
      } catch (e) {
        print("Ext storage failed: $e");
      }

      // Location 2: App documents dir (fallback)
      if (savedPath == null) {
        try {
          final Directory docsDir = await getApplicationDocumentsDirectory();
          final File file = File("${docsDir.path}/$fileName");
          await file.writeAsBytes(bytes);
          savedPath = file.path;
        } catch (e) {
          print("Docs dir failed: $e");
        }
      }

      // Location 3: Temp dir (last resort)
      if (savedPath == null) {
        final Directory tempDir = await getTemporaryDirectory();
        final File file = File("${tempDir.path}/$fileName");
        await file.writeAsBytes(bytes);
        savedPath = file.path;
      }

      if (mounted) {
        _showSnack("QR saved ✅  $fileName");
        print("QR saved at: $savedPath");
      }
    } catch (e) {
      print("Download QR error: $e");
      if (mounted) {
        _showSnack("Error saving QR: $e");
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF7C6AF7), width: 1),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C6AF7).withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4ECDC4).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C6AF7),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Header card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF7C6AF7).withOpacity(0.1),
                                const Color(0xFF4ECDC4).withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C6AF7),
                                      Color(0xFF4ECDC4),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Student Portal',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      studentName?.trim() ?? 'Student',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                    Text(
                                      'ID: ${studentId?.trim() ?? ''}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          'Event Access',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Event info card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16161F),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ECDC4)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event_rounded,
                                  color: Color(0xFF4ECDC4),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Event',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Event ID: $eventId',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Generate QR button
                        GestureDetector(
                          onTap: _showQRDialog,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7C6AF7),
                                  Color(0xFF5A50D4),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C6AF7)
                                      .withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_2_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Generate QR',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Show at event entry gate',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        Center(
                          child: TextButton.icon(
                            onPressed: _logout,
                            icon: Icon(
                              Icons.logout_rounded,
                              color: Colors.white.withOpacity(0.5),
                              size: 18,
                            ),
                            label: Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}