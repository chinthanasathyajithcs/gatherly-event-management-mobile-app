import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  general,
  eventApproved,
  eventRejected,
  eventRegistration,
  eventUpdate,
  qna,
}

extension AppNotificationTypeX on AppNotificationType {
  String get value {
    switch (this) {
      case AppNotificationType.eventApproved:
        return 'event_approved';
      case AppNotificationType.eventRejected:
        return 'event_rejected';
      case AppNotificationType.eventRegistration:
        return 'event_registration';
      case AppNotificationType.eventUpdate:
        return 'event_update';
      case AppNotificationType.qna:
        return 'qna';
      case AppNotificationType.general:
        return 'general';
    }
  }
}

AppNotificationType parseAppNotificationType(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'event_approved':
      return AppNotificationType.eventApproved;
    case 'event_rejected':
      return AppNotificationType.eventRejected;
    case 'event_registration':
      return AppNotificationType.eventRegistration;
    case 'event_update':
      return AppNotificationType.eventUpdate;
    case 'qna':
      return AppNotificationType.qna;
    default:
      return AppNotificationType.general;
  }
}

class AppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final AppNotificationType type;
  final bool isRead;
  final String? eventId;
  final Timestamp? createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.eventId,
    this.createdAt,
  });

  factory AppNotificationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? <String, dynamic>{};

    return AppNotificationModel(
      id: doc.id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: parseAppNotificationType(map['type'] as String?),
      isRead: map['isRead'] as bool? ?? false,
      eventId: map['eventId'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
    );
  }
}
