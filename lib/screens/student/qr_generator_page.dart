import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/event_model.dart';

class QRGeneratorDialog extends StatelessWidget {
  final String uid;
  final String studentName;
  final String studentId;
  final EventModel event;

  const QRGeneratorDialog({
    super.key,
    required this.uid,
    required this.studentName,
    required this.studentId,
    required this.event,
  });

  String _generateQRData() {
    return jsonEncode({
      "studentId": studentId,
      "uid": uid,
      "eventId": event.id ?? '',
      "name": studentName,
      "paid": event.isPaidEvent,
      "entryFee": event.entryFee,
    });
  }

  static void show(
    BuildContext context, {
    required String uid,
    required String studentName,
    required String studentId,
    required EventModel event,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return QRGeneratorDialog(
          uid: uid,
          studentName: studentName,
          studentId: studentId,
          event: event,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _generateQRData();

    return Dialog(
      backgroundColor: const Color(0xFFF6F1EB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE8D5C4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.isPaidEvent ? 'Your Event Ticket' : 'Your QR Ticket',
              style: TextStyle(
                color: Color(0xFF0D1B2E),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              event.name,
              style: const TextStyle(
                color: Color(0xFFCB6D22),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$studentName  ·  $studentId',
              style: const TextStyle(
                color: Color(0xFF6A7C90),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (event.isPaidEvent) ...[
              const SizedBox(height: 6),
              Text(
                'Paid ticket • Rs. ${event.entryFee?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  color: Color(0xFF1A8A5A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8D5C4)),
              ),
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8D5C4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFCB6D22)),
                  SizedBox(width: 6),
                  Text(
                    'Show this to the host at the venue',
                    style: TextStyle(
                      color: Color(0xFFCB6D22),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFCB6D22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
