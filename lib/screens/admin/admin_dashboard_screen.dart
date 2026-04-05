import 'package:event_management_app/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../auth/auth_shell_screen.dart';
import '../club.dart';
import '../student/student_dashboard_screen.dart';

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTime(TimeOfDayData time) {
  final hour =
      time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'hackathon':
      return const Color(0xFF1D4E89);
    case 'workshop':
      return const Color(0xFF2E8A99);
    case 'seminar':
      return const Color(0xFF9C6ADE);
    case 'conference':
      return const Color(0xFF4F709C);
    case 'festival':
      return const Color(0xFFFF8A3D);
    case 'meetup':
      return const Color(0xFF5F8D4E);
    case 'webinar':
      return const Color(0xFF00A8CC);
    case 'competition':
      return const Color(0xFFDC2F02);
    case 'career fair':
      return const Color(0xFF4361EE);
    case 'networking':
      return const Color(0xFF38B000);
    case 'sports':
      return const Color(0xFFFCA311);
    case 'cultural':
      return const Color(0xFFE0AAFF);
    case 'orientation':
      return const Color(0xFF2563EB);
    case 'volunteering':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFFCB6D22);
  }
}

Future<bool> _confirmReject(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Reject event?'),
        content: const Text('This will reject the event request permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      );
    },
  );
  return result == true;
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Stream<List<EventModel>> _eventsForStatus(EventApprovalStatus status) {
    final service = EventService();

    switch (status) {
      case EventApprovalStatus.accepted:
        return service.streamAcceptedEvents();
      case EventApprovalStatus.rejected:
        return service.streamRejectedEvents();
      case EventApprovalStatus.pending:
      default:
        return service.streamPendingEvents();
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthShellScreen()),
      (_) => false,
    );
  }

  Future<void> _showAddAdminDialog(BuildContext context) async {
    final wasCreated = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddAdminDialog(),
    );

    if (wasCreated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student promoted to admin successfully.'),
          backgroundColor: Color(0xFF0D1B2E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F1EB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D1B2E),
          elevation: 0,
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'student') {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const StudentDashboardScreen()),
                    (_) => false,
                  );
                } else if (value == 'promote') {
                  _showAddAdminDialog(context);
                } else if (value == 'logout') {
                  _handleSignOut(context);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'student',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 12),
                      Text('View as student'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'promote',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Promote student to admin'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFCB6D22),
            labelColor: Color(0xFF0D1B2E),
            unselectedLabelColor: Color(0xFF7B6E63),
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F3EE), Color(0xFFF6F1EB)],
            ),
          ),
          child: TabBarView(
            children: [
              _AdminEventTab(
                title: 'Pending events',
                subtitle:
                    'Review event submissions and approve or reject requests from students.',
                status: EventApprovalStatus.pending,
                showActions: true,
                eventFetcher: () =>
                    _eventsForStatus(EventApprovalStatus.pending),
              ),
              _AdminEventTab(
                title: 'Approved events',
                subtitle: 'Review events that have already been accepted.',
                status: EventApprovalStatus.accepted,
                showActions: true,
                eventFetcher: () =>
                    _eventsForStatus(EventApprovalStatus.accepted),
              ),
              _AdminEventTab(
                title: 'Rejected events',
                subtitle: 'Review events that were rejected by the admin.',
                status: EventApprovalStatus.rejected,
                showActions: true,
                eventFetcher: () =>
                    _eventsForStatus(EventApprovalStatus.rejected),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClubScreen()),
          ),
          child: const Icon(Icons.add),
          backgroundColor: const Color(0xFFCB6D22),
        ),
      ),
    );
  }
}

class _AdminEventTab extends StatelessWidget {
  const _AdminEventTab({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.showActions,
    required this.eventFetcher,
  });

  final String title;
  final String subtitle;
  final EventApprovalStatus status;
  final bool showActions;
  final Stream<List<EventModel>> Function() eventFetcher;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventModel>>(
      stream: eventFetcher(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFCB6D22),
            ),
          );
        }

        if (snapshot.hasError) {
          final errorMessage = snapshot.error?.toString() ??
              'Unable to load events. Please try again later.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7B6E63),
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        final events = snapshot.data ?? <EventModel>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7B6E63),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (events.isEmpty)
              Column(
                children: [
                  const SizedBox(height: 60),
                  Icon(
                    status == EventApprovalStatus.pending
                        ? Icons.event_available_rounded
                        : status == EventApprovalStatus.accepted
                            ? Icons.celebration_rounded
                            : Icons.event_busy_rounded,
                    size: 64,
                    color: const Color(0xFFCB6D22),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status == EventApprovalStatus.pending
                        ? 'No pending events right now.'
                        : status == EventApprovalStatus.accepted
                            ? 'No approved events yet.'
                            : 'No rejected events yet.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1B2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status == EventApprovalStatus.pending
                        ? 'When students submit events, they will appear here for approval.'
                        : status == EventApprovalStatus.accepted
                            ? 'Approved events appear here after admin review.'
                            : 'Rejected events appear here after admin review.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7B6E63),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            if (events.isNotEmpty)
              ...events.map((event) {
                return _AdminEventCard(
                  event: event,
                  categoryColor: _categoryColor(event.category),
                  dateText: _formatDate(event.date),
                  timeText: _formatTime(event.time),
                  showActions: showActions,
                  onApprove: () async {
                    if (!showActions) return;
                    try {
                      await EventService().approveEvent(event.id!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Approved "${event.name}"'),
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to approve event: $error'),
                        ),
                      );
                    }
                  },
                  onReject: () async {
                    if (!showActions) return;
                    final confirmed = await _confirmReject(context);
                    if (!confirmed) return;

                    try {
                      await EventService().rejectEvent(event.id!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Rejected "${event.name}"'),
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to reject event: $error'),
                        ),
                      );
                    }
                  },
                  onSetPending: () async {
                    if (!showActions) return;
                    try {
                      await EventService().resetEventToPending(event.id!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Set "${event.name}" to pending'),
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to set pending: $error'),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
          ],
        );
      },
    );
  }
}

class _AddAdminDialog extends StatefulWidget {
  const _AddAdminDialog({super.key});

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<UserModel> _searchResults = [];
  String? _errorMessage;
  UserModel? _selectedStudent;
  bool _isPromoting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchStudents(_searchController.text);
  }

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await AuthService().searchStudentsByName(query: query);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _promoteToAdmin(UserModel student) async {
    setState(() => _isPromoting = true);

    try {
      await AuthService().promoteStudentToAdmin(student.uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isPromoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Promote student to admin'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFF9C2214),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_selectedStudent == null) ...[
                const Text(
                  'Search student by name or email',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7B6E63)),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  label: 'Student name or email',
                  hint: 'e.g. john@example.com or John Doe',
                  controller: _searchController,
                  icon: Icons.search_rounded,
                ),
                const SizedBox(height: 12),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFCB6D22)),
                      ),
                    ),
                  )
                else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No students found matching "${_searchController.text}"',
                        style: const TextStyle(
                          color: Color(0xFF7B6E63),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Column(
                    children: _searchResults
                        .map((student) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCB6D22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (student.name?.isNotEmpty ?? false)
                                          ? student.name![0].toUpperCase()
                                          : (student.email.isNotEmpty
                                              ? student.email[0].toUpperCase()
                                              : 'U'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  student.name?.isNotEmpty == true
                                      ? student.name!
                                      : student.email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D1B2E),
                                  ),
                                ),
                                subtitle: Text(
                                  student.email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7B6E63),
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: _isPromoting
                                      ? null
                                      : () => setState(() => _selectedStudent = student),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCB6D22),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  child: const Text(
                                    'Select',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedStudent != null) ...[
                        Text(
                          _selectedStudent!.name?.isNotEmpty == true
                              ? _selectedStudent!.name!
                              : _selectedStudent!.email,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D1B2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedStudent!.email,
                          style: const TextStyle(
                            color: Color(0xFF7B6E63),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This student will be promoted to admin and can access the admin dashboard immediately.',
                    style: TextStyle(
                      color: Color(0xFF9C2214),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isPromoting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_selectedStudent != null)
          ElevatedButton(
            onPressed: _isPromoting ? null : () => _promoteToAdmin(_selectedStudent!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB6D22),
            ),
            child: _isPromoting
                ? const SizedBox(
                    width: 60,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Confirm Promote'),
          ),
      ],
    );
  }
}


class _AdminEventCard extends StatelessWidget {
  const _AdminEventCard({
    required this.event,
    required this.categoryColor,
    required this.dateText,
    required this.timeText,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
    required this.onSetPending,
  });

  final EventModel event;
  final Color categoryColor;
  final String dateText;
  final String timeText;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSetPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1B2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.category,
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  event.approvalStatus == EventApprovalStatus.accepted
                      ? 'Approved'
                      : event.approvalStatus == EventApprovalStatus.rejected
                          ? 'Rejected'
                          : 'Pending',
                  style: const TextStyle(
                    color: Color(0xFF4F4F4F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                event.posterImageUrl!,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F1EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Color(0xFF7B6E63)),
                    ),
                  );
                },
              ),
            ),
          if (event.posterImageUrl != null && event.posterImageUrl!.isNotEmpty)
            const SizedBox(height: 14),
          Text(
            event.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7B6E63),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: Color(0xFF7B6E63)),
              const SizedBox(width: 6),
              Text(
                dateText,
                style: const TextStyle(color: Color(0xFF7B6E63)),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time_rounded,
                  size: 18, color: Color(0xFF7B6E63)),
              const SizedBox(width: 6),
              Text(
                timeText,
                style: const TextStyle(color: Color(0xFF7B6E63)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  size: 18, color: Color(0xFF7B6E63)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  style: const TextStyle(color: Color(0xFF7B6E63)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showActions)
            Row(
              children: [
                if (event.approvalStatus == EventApprovalStatus.pending) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCB6D22),
                        side: const BorderSide(color: Color(0xFFCB6D22)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Reject'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB6D22),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Approve'),
                      ),
                    ),
                  ),
                ] else if (event.approvalStatus == EventApprovalStatus.accepted) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCB6D22),
                        side: const BorderSide(color: Color(0xFFCB6D22)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Reject'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSetPending,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F4F4F),
                        side: const BorderSide(color: Color(0xFFB0B0B0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Set Pending'),
                      ),
                    ),
                  ),
                ] else if (event.approvalStatus == EventApprovalStatus.rejected) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB6D22),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Approve'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSetPending,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F4F4F),
                        side: const BorderSide(color: const Color(0xFFB0B0B0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Set Pending'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
