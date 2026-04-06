import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

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
    final statusValue = status.value.trim();
    await _events.doc(eventId).update({
      'approvalStatus': statusValue,
      'status': statusValue,
      'approvalUpdatedAt': FieldValue.serverTimestamp(),
    });
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

  Future<void> joinEvent(
      {required String eventId, required String userId}) async {
    final docRef = _events.doc(eventId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Event not found.');
      }

      final map = snapshot.data() ?? <String, dynamic>{};
      final hasLimit = map['hasParticipantLimit'] as bool? ?? false;
      final limit = map['attendeeCount'] as int?;
      final joined = (map['joinedParticipantIds'] as List<dynamic>? ??
              map['joinedStudentIds'] as List<dynamic>? ??
              const [])
          .whereType<String>()
          .toList();

      if (joined.contains(userId)) return;

      if (hasLimit && limit != null && joined.length >= limit) {
        throw StateError('Participant limit reached for this event.');
      }

      tx.update(docRef, {
        'joinedParticipantIds': FieldValue.arrayUnion([userId]),
        'joinedParticipantCount': FieldValue.increment(1),
      });
    });
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
      });
    });
  }
}
