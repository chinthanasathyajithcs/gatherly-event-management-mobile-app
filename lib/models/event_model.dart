import 'package:cloud_firestore/cloud_firestore.dart';

enum EventApprovalStatus { pending, accepted, rejected }

extension EventApprovalStatusX on EventApprovalStatus {
  String get value {
    switch (this) {
      case EventApprovalStatus.pending:
        return 'pending';
      case EventApprovalStatus.accepted:
        return 'accepted';
      case EventApprovalStatus.rejected:
        return 'rejected';
    }
  }
}

EventApprovalStatus parseEventApprovalStatus(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'accepted':
    case 'approved':
      return EventApprovalStatus.accepted;
    case 'rejected':
      return EventApprovalStatus.rejected;
    default:
      return EventApprovalStatus.pending;
  }
}

class EventModel {
  final String? id;
  final String createdBy;
  final List<String> coHostIds;
  final Map<String, String> coHostNamesById;
  final String category;
  final String name;
  final DateTime date;
  final TimeOfDayData time;
  final String location;
  final bool hasParticipantLimit;
  final int? attendeeCount;
  final List<String> joinedParticipantIds;
  final int joinedParticipantCount;
  final List<String> scheduledByIds;
  final String description;
  final EventApprovalStatus approvalStatus;
  final String? posterImageUrl;
  final bool isQnaEnabled;
  final bool isQrAttendanceEnabled;
  final Timestamp? createdAt;
  final Timestamp? approvalUpdatedAt;
  final int durationHours;
  final String? clubId;
  final String? clubName;

  EventModel({
    this.id,
    required this.createdBy,
    this.coHostIds = const [],
    this.coHostNamesById = const {},
    required this.category,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.hasParticipantLimit,
    this.attendeeCount,
    this.joinedParticipantIds = const [],
    this.joinedParticipantCount = 0,
    this.scheduledByIds = const [],
    required this.description,
    this.approvalStatus = EventApprovalStatus.pending,
    this.posterImageUrl,
    this.isQnaEnabled = false,
    this.isQrAttendanceEnabled = false,
    this.createdAt,
    this.approvalUpdatedAt,
    this.durationHours = 2,
    this.clubId,
    this.clubName,
  });

  factory EventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final Timestamp dateTs = map['eventDate'] as Timestamp? ?? Timestamp.now();

    final joinedParticipants = (map['joinedParticipantIds'] as List<dynamic>? ??
            map['joinedStudentIds'] as List<dynamic>? ??
            const [])
        .whereType<String>()
        .toList();

    final statusRaw =
        map['approvalStatus'] as String? ?? map['status'] as String?;

    final coHostsRaw = map['coHostNamesById'];
    final coHostNamesById = <String, String>{};
    if (coHostsRaw is Map) {
      coHostsRaw.forEach((key, value) {
        final id = key.toString().trim();
        final name = value?.toString().trim() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          coHostNamesById[id] = name;
        }
      });
    }

    final coHostIds = (map['coHostIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    return EventModel(
      id: doc.id,
      createdBy: map['createdBy'] as String? ?? '',
      coHostIds: coHostIds,
      coHostNamesById: coHostNamesById,
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
      joinedParticipantIds: joinedParticipants,
      joinedParticipantCount: map['joinedParticipantCount'] as int? ??
          map['joinedStudentCount'] as int? ??
          joinedParticipants.length,
      scheduledByIds: (map['scheduledByIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      description: map['description'] as String? ?? '',
      approvalStatus: parseEventApprovalStatus(statusRaw),
      posterImageUrl: (map['posterImageUrl'] as String?)?.trim().isEmpty == true
          ? null
          : (map['posterImageUrl'] as String?),
      isQnaEnabled: map['isQnaEnabled'] as bool? ?? false,
      isQrAttendanceEnabled: map['isQrAttendanceEnabled'] as bool? ?? false,
      createdAt: map['createdAt'] as Timestamp?,
      approvalUpdatedAt: map['approvalUpdatedAt'] as Timestamp?,
      durationHours: map['durationHours'] as int? ?? 2,
      clubId: map['clubId'] as String?,
      clubName: map['clubName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final statusValue = approvalStatus.value.trim();

    return {
      'createdBy': createdBy,
      'coHostIds': coHostIds,
      'coHostNamesById': coHostNamesById,
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
      'scheduledByIds': scheduledByIds,
      'description': description,
      'approvalStatus': statusValue,
      'status': statusValue,
      'posterImageUrl': posterImageUrl,
      'isQnaEnabled': isQnaEnabled,
      'isQrAttendanceEnabled': isQrAttendanceEnabled,
      'createdAt': FieldValue.serverTimestamp(),
      'durationHours': durationHours,
      'clubId': clubId,
      'clubName': clubName,
    };
  }
}

class TimeOfDayData {
  final int hour;
  final int minute;

  const TimeOfDayData({required this.hour, required this.minute});
}
