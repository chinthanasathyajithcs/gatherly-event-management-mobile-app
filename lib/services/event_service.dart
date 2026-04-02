import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  Stream<List<EventModel>> streamUserEvents(String uid) {
    return _events.where('createdBy', isEqualTo: uid).snapshots().map(
      (snapshot) {
        final events = snapshot.docs.map(EventModel.fromDoc).toList();
        events.sort((a, b) {
          final aTime = a.createdAt?.toDate() ?? DateTime(2000);
          final bTime = b.createdAt?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        return events;
      },
    );
  }

  Future<void> createEvent(EventModel event) async {
    await _events.add(event.toMap());
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
      final joined = (map['joinedParticipantIds'] as List<dynamic>? ?? const [])
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
      final joined = (map['joinedParticipantIds'] as List<dynamic>? ?? const [])
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
