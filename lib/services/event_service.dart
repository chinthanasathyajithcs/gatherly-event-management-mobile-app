import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification_model.dart';
import '../models/event_model.dart';
import 'notification_service.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  Stream<List<EventModel>> streamUserEvents(String uid) {
    final createdStream =
        _events.where('createdBy', isEqualTo: uid).snapshots();
    final coHostedStream =
        _events.where('coHostIds', arrayContains: uid).snapshots();

    return Stream.multi((controller) {
      var createdDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      var coHostedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      void emitMerged() {
        final unique = <String, EventModel>{};
        for (final doc in [...createdDocs, ...coHostedDocs]) {
          unique[doc.id] = EventModel.fromDoc(doc);
        }

        final events = unique.values.toList();
        events.sort((a, b) {
          final aTime = a.createdAt?.toDate() ?? DateTime(2000);
          final bTime = b.createdAt?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        controller.add(events);
      }

      final createdSub = createdStream.listen(
        (snapshot) {
          createdDocs = snapshot.docs;
          emitMerged();
        },
        onError: controller.addError,
      );

      final coHostedSub = coHostedStream.listen(
        (snapshot) {
          coHostedDocs = snapshot.docs;
          emitMerged();
        },
        onError: controller.addError,
      );

      controller.onCancel = () async {
        await createdSub.cancel();
        await coHostedSub.cancel();
      };
    });
  }

  Stream<List<EventModel>> streamEventsByStatus(EventApprovalStatus status) {
    return _events
        .where('approvalStatus', isEqualTo: status.value)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map(EventModel.fromDoc).toList();
      events.sort((a, b) {
        final aTime = a.createdAt?.toDate() ?? DateTime(2000);
        final bTime = b.createdAt?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return events;
    });
  }

  Stream<List<EventModel>> streamPendingEvents() {
    return streamEventsByStatus(EventApprovalStatus.pending);
  }

  Stream<List<EventModel>> streamAcceptedEvents() {
    return streamEventsByStatus(EventApprovalStatus.accepted);
  }

  Stream<List<EventModel>> streamRejectedEvents() {
    return streamEventsByStatus(EventApprovalStatus.rejected);
  }

  Future<void> createEvent(EventModel event) async {
    await _events.add(event.toMap());
  }

  Future<void> updateEventStatus({
    required String eventId,
    required EventApprovalStatus status,
  }) async {
    final eventSnapshot = await _events.doc(eventId).get();
    final eventData = eventSnapshot.data();
    if (!eventSnapshot.exists || eventData == null) {
      throw StateError('Event not found.');
    }

    final statusValue = status.value.trim();
    await _events.doc(eventId).update({
      'approvalStatus': statusValue,
      'status': statusValue,
      'approvalUpdatedAt': FieldValue.serverTimestamp(),
    });

    final organizerIds = <String>{
      (eventData['createdBy'] as String? ?? '').trim(),
      ...((eventData['coHostIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((id) => id.trim())),
    }..removeWhere((id) => id.isEmpty);

    final eventName = (eventData['name'] as String? ?? 'your event').trim();

    final isApproved = status == EventApprovalStatus.accepted;
    await NotificationService.instance.addNotificationToUsers(
      userIds: organizerIds,
      title: isApproved ? 'Event approved' : 'Event update',
      body: isApproved
          ? '$eventName was approved by admin and is now visible to students.'
          : '$eventName was rejected by admin. Please update and resubmit.',
      type: isApproved
          ? AppNotificationType.eventApproved
          : AppNotificationType.eventRejected,
      eventId: eventId,
    );
  }

  Future<void> approveEvent(String eventId) {
    return updateEventStatus(
      eventId: eventId,
      status: EventApprovalStatus.accepted,
    );
  }

  Future<void> rejectEvent(String eventId) {
    return updateEventStatus(
      eventId: eventId,
      status: EventApprovalStatus.rejected,
    );
  }

  Future<void> resetEventToPending(String eventId) {
    return updateEventStatus(
      eventId: eventId,
      status: EventApprovalStatus.pending,
    );
  }

  Future<void> updateEventPoster({
    required String eventId,
    String? posterImageUrl,
  }) async {
    await _events.doc(eventId).update({
      'posterImageUrl': posterImageUrl,
    });
  }

  Future<void> updateEventDetails({
    required String eventId,
    DateTime? date,
    int? timeHour,
    int? timeMinute,
    String? location,
    String? description,
    bool? hasParticipantLimit,
    int? attendeeCount,
    bool? isPaidEvent,
    double? entryFee,
    List<String>? coHostIds,
    Map<String, String>? coHostNamesById,
    bool resetApproval = false,
  }) async {
    final updates = <String, dynamic>{};

    if (date != null) {
      updates['eventDate'] = Timestamp.fromDate(date);
    }
    if (timeHour != null && timeMinute != null) {
      updates['timeHour'] = timeHour;
      updates['timeMinute'] = timeMinute;
    }
    if (location != null) {
      updates['location'] = location;
    }
    if (description != null) {
      updates['description'] = description;
    }
    if (hasParticipantLimit != null) {
      updates['hasParticipantLimit'] = hasParticipantLimit;
      if (!hasParticipantLimit) {
        updates['attendeeCount'] = null;
      }
    }
    if (attendeeCount != null) {
      updates['attendeeCount'] = attendeeCount;
    }
    if (isPaidEvent != null) {
      updates['isPaidEvent'] = isPaidEvent;
      if (!isPaidEvent) {
        updates['entryFee'] = null;
      }
    }
    if (entryFee != null) {
      updates['entryFee'] = entryFee;
    }
    if (coHostIds != null) {
      updates['coHostIds'] = coHostIds;
    }
    if (coHostNamesById != null) {
      updates['coHostNamesById'] = coHostNamesById;
    }
    if (resetApproval) {
      updates['approvalStatus'] = EventApprovalStatus.pending.value;
      updates['status'] = EventApprovalStatus.pending.value;
    }

    if (updates.isNotEmpty) {
      await _events.doc(eventId).update(updates);
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _events.doc(eventId).delete();
  }

  Future<void> joinEvent(
      {required String eventId,
      required String userId,
      Map<String, dynamic>? paymentDetails}) async {
    final docRef = _events.doc(eventId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Event not found.');
      }

      final map = snapshot.data() ?? <String, dynamic>{};
      final isPaidEvent = map['isPaidEvent'] as bool? ?? false;
      final hasLimit = map['hasParticipantLimit'] as bool? ?? false;
      final limit = map['attendeeCount'] as int?;
      final joined = (map['joinedParticipantIds'] as List<dynamic>? ??
              map['joinedStudentIds'] as List<dynamic>? ??
              const [])
          .whereType<String>()
          .toList();
      final updates = <String, dynamic>{
        'scheduledByIds': FieldValue.arrayUnion([userId]),
      };

      if (isPaidEvent && paymentDetails == null) {
        throw StateError('Payment is required for this event.');
      }

      if (!joined.contains(userId)) {
        if (hasLimit && limit != null && joined.length >= limit) {
          throw StateError('Participant limit reached for this event.');
        }

        updates['joinedParticipantIds'] = FieldValue.arrayUnion([userId]);
        updates['joinedParticipantCount'] = FieldValue.increment(1);
      }

      tx.update(docRef, updates);
    });

    await docRef.collection('registrations').doc(userId).set({
      'userId': userId,
      'eventId': eventId,
      'paymentRequired': paymentDetails != null,
      'paymentStatus': paymentDetails == null ? 'not_required' : 'paid',
      'paymentProvider': paymentDetails?['paymentProvider'] ?? 'paypal',
      'paymentAmount': paymentDetails?['amount'],
      'currency': paymentDetails?['currency'] ?? 'LKR',
      'paymentTransactionId': paymentDetails?['transactionId'],
      'registeredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final eventSnapshot = await docRef.get();
    final map = eventSnapshot.data() ?? <String, dynamic>{};
    final eventName = (map['name'] as String? ?? 'Event').trim();

    await NotificationService.instance.addNotificationToUser(
      userId: userId,
      title: 'Registration confirmed',
      body: 'You are registered for $eventName.',
      type: AppNotificationType.eventRegistration,
      eventId: eventId,
    );

    final organizerIds = <String>{
      (map['createdBy'] as String? ?? '').trim(),
      ...((map['coHostIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((id) => id.trim())),
    }
      ..remove(userId)
      ..removeWhere((id) => id.isEmpty);

    await NotificationService.instance.addNotificationToUsers(
      userIds: organizerIds,
      title: 'New registration',
      body: 'A student registered for $eventName.',
      type: AppNotificationType.eventUpdate,
      eventId: eventId,
    );
  }

  Future<void> leaveEvent(
      {required String eventId, required String userId}) async {
    final docRef = _events.doc(eventId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Event not found.');
      }

      final map = snapshot.data() ?? <String, dynamic>{};
      final joined = (map['joinedParticipantIds'] as List<dynamic>? ??
              map['joinedStudentIds'] as List<dynamic>? ??
              const [])
          .whereType<String>()
          .toList();

      if (!joined.contains(userId)) return;

      tx.update(docRef, {
        'joinedParticipantIds': FieldValue.arrayRemove([userId]),
        'joinedParticipantCount': FieldValue.increment(-1),
        'scheduledByIds': FieldValue.arrayRemove([userId]),
      });
    });

    await docRef.collection('registrations').doc(userId).delete();
  }
}
