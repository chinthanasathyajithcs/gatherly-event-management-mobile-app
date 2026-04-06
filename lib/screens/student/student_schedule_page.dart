import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class StudentSchedulePage extends StatefulWidget {
  const StudentSchedulePage({super.key});

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _uid;

  // Controls filtering
  bool isDateSelected = false;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  DateTime? _parseEventDate(Map<String, dynamic> data) {
    final rawDate = data['eventDate'];

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is DateTime) {
      return rawDate;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Schedule")),
        body: const Center(
          child: Text("Please sign in to view your schedule."),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('events')
        .where('joinedParticipantIds', arrayContains: uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text("My Schedule")),
      body: Column(
        children: [
          // 📅 CALENDAR
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                isDateSelected = true;
              });
            },
          ),

          // 🔥 RESET BUTTON
          TextButton(
            onPressed: () {
              setState(() {
                isDateSelected = false;
              });
            },
            child: const Text("Show All Events"),
          ),

          const SizedBox(height: 5),

          // 📌 TITLE
          Text(
            isDateSelected
                ? "Events on ${_selectedDay.toString().substring(0, 10)}"
                : "All My Events",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // 📋 EVENTS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No joined events"));
                }

                final docs = snapshot.data!.docs;

                List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs;

                if (isDateSelected) {
                  // Filter events to the selected day.
                  filteredDocs = docs.where((doc) {
                    final data = doc.data();

                    final eventDate = _parseEventDate(data);
                    if (eventDate == null) return false;

                    return eventDate.year == _selectedDay.year &&
                        eventDate.month == _selectedDay.month &&
                        eventDate.day == _selectedDay.day;
                  }).toList();
                } else {
                  filteredDocs = List.from(docs);
                }

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      isDateSelected
                          ? "No events on this day"
                          : "No joined events",
                    ),
                  );
                }

                filteredDocs.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final aDate = _parseEventDate(aData);
                  final bDate = _parseEventDate(bData);

                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;

                  return aDate.compareTo(bDate);
                });

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data();
                    final eventDate = _parseEventDate(data);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          data['name']?.toString() ?? 'No Title',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📂 ${data['category']?.toString() ?? ''}"),
                            Text("📍 ${data['location']?.toString() ?? ''}"),
                            Text(
                              eventDate == null
                                  ? "⏰ Time TBA"
                                  : "⏰ ${eventDate.toString().substring(11, 16)}",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
