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
  DateTime? _selectedDay;

  late String uid;

  // 🔥 controls filtering
  bool isDateSelected = false;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
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
                ? "Events on ${_selectedDay!.toString().substring(0, 10)}"
                : "All My Events",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // 📋 EVENTS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No joined events"));
                }

                final docs = snapshot.data!.docs;

                List<QueryDocumentSnapshot> filteredDocs;

                if (isDateSelected) {
                  // 🔥 FIXED DATE FILTER (NO TIMEZONE ISSUE)
                  filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['eventDate'] == null) return false;

                    final eventDate = (data['eventDate'] as Timestamp).toDate();

                    return eventDate.year == _selectedDay!.year &&
                        eventDate.month == _selectedDay!.month &&
                        eventDate.day == _selectedDay!.day;
                  }).toList();
                } else {
                  // 🔥 SHOW ALL EVENTS
                  filteredDocs = docs;
                }

                // 🔥 EMPTY STATE
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      isDateSelected
                          ? "No events on this day"
                          : "No joined events",
                    ),
                  );
                }

                // 🔥 SORT EVENTS BY TIME
                filteredDocs.sort((a, b) {
                  final aDate = (a['eventDate'] as Timestamp).toDate();
                  final bDate = (b['eventDate'] as Timestamp).toDate();
                  return aDate.compareTo(bDate);
                });

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;

                    final eventDate = (data['eventDate'] as Timestamp).toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          data['name'] ?? 'No Title',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📂 ${data['category'] ?? ''}"),
                            Text("📍 ${data['location'] ?? ''}"),
                            Text("⏰ ${eventDate.toString().substring(11, 16)}"),
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
