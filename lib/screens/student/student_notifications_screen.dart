import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification_model.dart';
import '../../services/notification_service.dart';

class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  IconData _typeIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.eventApproved:
        return Icons.verified_rounded;
      case AppNotificationType.eventRejected:
        return Icons.cancel_rounded;
      case AppNotificationType.eventRegistration:
        return Icons.event_available_rounded;
      case AppNotificationType.eventUpdate:
        return Icons.campaign_rounded;
      case AppNotificationType.qna:
        return Icons.forum_rounded;
      case AppNotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications.')),
      );
    }

    final service = NotificationService.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => service.markAllAsRead(uid),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: Color(0xFFCB6D22),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: service.streamNotifications(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load notifications: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? const [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 52,
                    color: const Color(0xFF0D1B2E).withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: const Color(0xFF0D1B2E).withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = notifications[index];

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    if (!item.isRead) {
                      service.markAsRead(uid: uid, notificationId: item.id);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: item.isRead
                            ? const Color(0xFFEDE6DD)
                            : const Color(0xFFFFD7BF),
                        width: item.isRead ? 1 : 1.4,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? const Color(0xFFF3EEE8)
                                : const Color(0xFFFFEEE2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _typeIcon(item.type),
                            color: const Color(0xFFCB6D22),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: const Color(0xFF0D1B2E),
                                  fontSize: 15,
                                  fontWeight: item.isRead
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  color: Color(0xFF5A6878),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.createdAt == null
                                    ? 'Now'
                                    : _timeAgo(item.createdAt!.toDate()),
                                style: const TextStyle(
                                  color: Color(0xFF97A3B2),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
