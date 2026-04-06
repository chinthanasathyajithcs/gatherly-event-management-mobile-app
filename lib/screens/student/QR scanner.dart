import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? adminName;
  String? adminEmail;
  bool _isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final user = _auth.getCurrentUser();
    if (user != null) {
      setState(() {
        adminName = user.email?.split('@').first ?? 'Admin';
        adminEmail = user.email;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      _processScannedQR(result);
    }
  }

  Future<void> _processScannedQR(String qrJsonString) async {
    // Parse QR data
    Map<String, dynamic> qrData;
    try {
      qrData = jsonDecode(qrJsonString);
    } catch (e) {
      _showSnackbar('Invalid QR code format ❌', Colors.red);
      return;
    }

    final String? studentId = qrData['studentId'];
    final String? uid = qrData['uid'];
    final String? eventId = qrData['eventId'];
    final String studentName = qrData['name'] ?? 'Unknown';

    if (studentId == null || eventId == null) {
      _showSnackbar('QR missing required data ❌', Colors.red);
      return;
    }

    // Check if ticket exists (purchased)
    final bool hasTicket = await _auth.hasTicket(studentId, eventId);

    if (!hasTicket) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF16161F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.red, width: 1),
            ),
            title: const Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'No Ticket Found',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              'Student $studentId has NOT purchased a ticket for event $eventId.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Check if already marked present for this event
    final alreadyMarked = await _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'present')
        .limit(1)
        .get();

    if (alreadyMarked.docs.isNotEmpty) {
      _showSnackbar(
          'Student $studentId already marked present for $eventId ⚠️',
          Colors.orange);
      return;
    }

    // Show confirmation dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF16161F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF7C6AF7), width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF4ECDC4)),
              SizedBox(width: 8),
              Text(
                'Confirm Attendance',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Student ID', studentId),
              const SizedBox(height: 8),
              _infoRow('Name', studentName),
              const SizedBox(height: 8),
              _infoRow('Event ID', eventId),
              const SizedBox(height: 8),
              _infoRow('Ticket', '✅ Purchased'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _markAttendance(
                    studentId, studentName, eventId, uid ?? '');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Mark Present',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF7C6AF7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _markAttendance(
      String studentId, String studentName, String eventId, String uid) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('attendance').add({
        'studentId': studentId,
        'studentName': studentName,
        'uid': uid,
        'eventId': eventId,
        'status': 'present',
        'scannedAt': FieldValue.serverTimestamp(),
        'markedBy': adminEmail ?? 'admin',
        'date': now.toIso8601String(),
      });
      _showSnackbar('$studentName marked present ✅', const Color(0xFF4ECDC4));
    } catch (e) {
      _showSnackbar('Error marking attendance: $e', Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
            child: FadeTransition(
              opacity: _fadeAnimation,
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

                          // Admin header card
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
                                        Color(0xFF4ECDC4)
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin Dashboard',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        adminName ?? 'Administrator',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Georgia',
                                        ),
                                      ),
                                      Text(
                                        adminEmail ?? '',
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
                            'Attendance Management',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          _buildActionCard(
                            title: 'Scan QR Code',
                            subtitle: 'Scan student QR at entry gate',
                            icon: Icons.qr_code_scanner_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C6AF7), Color(0xFF5A50D4)],
                            ),
                            onTap: _scanQR,
                          ),

                          const SizedBox(height: 16),

                          _buildActionCard(
                            title: 'View Attendance',
                            subtitle: 'Check attendance records',
                            icon: Icons.history_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4ECDC4), Color(0xFF3DB0A8)],
                            ),
                            onTap: _showAttendanceHistory,
                          ),

                          const SizedBox(height: 32),

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
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient)
                  .colors
                  .first
                  .withOpacity(0.3),
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
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
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
    );
  }

  void _showAttendanceHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Attendance Records',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('attendance')
                      .orderBy('scannedAt', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (_, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7C6AF7),
                        ),
                      );
                    }
                    final records = snapshot.data!.docs;
                    if (records.isEmpty) {
                      return Center(
                        child: Text(
                          'No attendance records yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: records.length,
                      itemBuilder: (_, index) {
                        final data =
                            records[index].data() as Map<String, dynamic>;
                        final timestamp =
                            data['scannedAt'] as Timestamp?;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C6AF7)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF7C6AF7),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['studentName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'ID: ${data['studentId']}  •  Event: ${data['eventId']}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (timestamp != null)
                                      Text(
                                        _formatTime(timestamp.toDate()),
                                        style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.35),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ECDC4)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Present',
                                  style: TextStyle(
                                    color: Color(0xFF4ECDC4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}

// ── QR Scanner Screen ──────────────────────────────────────────────────────────

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        title: const Text(
          'Scan Student QR',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF16161F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  setState(() => _scanned = true);
                  _controller.stop();
                  Navigator.pop(context, value);
                  return;
                }
              }
            },
          ),

          // Dimmed overlay with transparent center hole effect
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          // Scanner frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF7C6AF7),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                      top: 0,
                      left: 0,
                      child: _corner(top: true, left: true)),
                  Positioned(
                      top: 0,
                      right: 0,
                      child: _corner(top: true, left: false)),
                  Positioned(
                      bottom: 0,
                      left: 0,
                      child: _corner(top: false, left: true)),
                  Positioned(
                      bottom: 0,
                      right: 0,
                      child: _corner(top: false, left: false)),
                ],
              ),
            ),
          ),

          // Instruction text
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161F),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: const Color(0xFF7C6AF7), width: 1),
                ),
                child: const Text(
                  'Place student QR inside the frame',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({required bool top, required bool left}) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: Color(0xFF7C6AF7), width: 3)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: Color(0xFF7C6AF7), width: 3)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: Color(0xFF7C6AF7), width: 3)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: Color(0xFF7C6AF7), width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}