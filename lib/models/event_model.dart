import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String? id;
  final String createdBy;
  final String category;
  final String name;
  final DateTime date;
  final TimeOfDayData time;
  final String location;
  final bool hasParticipantLimit;
  final int? attendeeCount;
  final List<String> joinedParticipantIds;
  final int joinedParticipantCount;
  final String description;
  final Timestamp? createdAt;

  EventModel({
    this.id,
    required this.createdBy,
    required this.category,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.hasParticipantLimit,
    this.attendeeCount,
    this.joinedParticipantIds = const [],
    this.joinedParticipantCount = 0,
    required this.description,
    this.createdAt,
  });

  factory EventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final Timestamp dateTs = map['eventDate'] as Timestamp? ?? Timestamp.now();

    return EventModel(
      id: doc.id,
      createdBy: map['createdBy'] as String? ?? '',
      category: map['category'] as String? ?? '',
      name: map['name'] as String? ?? '',
      date: dateTs.toDate(),
      time: TimeOfDayData(
        hour: map['timeHour'] as int? ?? 9,
        minute: map['timeMinute'] as int? ?? 0,
      ),
      location: map['location'] as String? ?? '',
      hasParticipantLimit: map['hasParticipantLimit'] as bool? ??
          ((map['attendeeCount'] as int?) != null),
      attendeeCount: map['attendeeCount'] as int?,
      joinedParticipantIds:
          (map['joinedParticipantIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      joinedParticipantCount: map['joinedParticipantCount'] as int? ?? 0,
      description: map['description'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'category': category,
      'name': name,
      'eventDate': Timestamp.fromDate(date),
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'location': location,
      'hasParticipantLimit': hasParticipantLimit,
      'attendeeCount': hasParticipantLimit ? attendeeCount : null,
      'joinedParticipantIds': joinedParticipantIds,
      'joinedParticipantCount': joinedParticipantCount,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class TimeOfDayData {
  final int hour;
  final int minute;

  const TimeOfDayData({required this.hour, required this.minute});
}
