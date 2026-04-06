import 'package:event_management_app/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../auth/auth_shell_screen.dart';
import 'club_screen.dart';
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

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D5C4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                _MenuOption(
                  icon: Icons.person_outline_rounded,
                  label: 'View as student',
                  color: const Color(0xFF0D1B2E),
                  bgColor: const Color(0xFFF6F1EB),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
                      (_) => false,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _MenuOption(
                  icon: Icons.groups_rounded,
                  label: 'Manage clubs',
                  color: const Color(0xFF0D1B2E),
                  bgColor: const Color(0xFFF6F1EB),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClubScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _MenuOption(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Promote to admin',
                  color: const Color(0xFFCB6D22),
                  bgColor: const Color(0xFFCB6D22).withOpacity(0.12),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showAddAdminDialog(context);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Color(0xFFE8D5C4), height: 1),
                ),
                _MenuOption(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: const Color(0xFF9C2214),
                  bgColor: const Color(0xFFFFECE6),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleSignOut(context);
                  },
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
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
            IconButton(
              icon: const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF0D1B2E),
                size: 26,
              ),
              onPressed: () => _showAdminMenu(context),
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
      ),
    );
  }
}

class _AdminEventTab extends StatefulWidget {
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
  State<_AdminEventTab> createState() => _AdminEventTabState();
}

class _AdminEventTabState extends State<_AdminEventTab> {
  final Set<String> _processingEventIds = <String>{};

  bool _isProcessing(String? eventId) {
    if (eventId == null) return false;
    return _processingEventIds.contains(eventId);
  }

  Future<void> _runAction({
    required EventModel event,
    required String successMessage,
    required String failurePrefix,
    required Future<void> Function(String eventId) operation,
  }) async {
    final eventId = event.id;
    if (eventId == null || eventId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to process event without an id.')),
      );
      return;
    }

    if (_processingEventIds.contains(eventId)) return;

    setState(() => _processingEventIds.add(eventId));

    try {
      await operation(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failurePrefix$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingEventIds.remove(eventId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventModel>>(
      stream: widget.eventFetcher(),
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
              widget.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D1B2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
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
                    widget.status == EventApprovalStatus.pending
                        ? Icons.event_available_rounded
                        : widget.status == EventApprovalStatus.accepted
                            ? Icons.celebration_rounded
                            : Icons.event_busy_rounded,
                    size: 64,
                    color: const Color(0xFFCB6D22),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.status == EventApprovalStatus.pending
                        ? 'No pending events right now.'
                        : widget.status == EventApprovalStatus.accepted
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
                    widget.status == EventApprovalStatus.pending
                        ? 'When students submit events, they will appear here for approval.'
                        : widget.status == EventApprovalStatus.accepted
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
                  showActions: widget.showActions,
                  isProcessing: _isProcessing(event.id),
                  onApprove: () async {
                    if (!widget.showActions) return;
                    await _runAction(
                      event: event,
                      successMessage: 'Approved "${event.name}"',
                      failurePrefix: 'Failed to approve event: ',
                      operation: EventService().approveEvent,
                    );
                  },
                  onReject: () async {
                    if (!widget.showActions) return;
                    final confirmed = await _confirmReject(context);
                    if (!confirmed) return;
                    await _runAction(
                      event: event,
                      successMessage: 'Rejected "${event.name}"',
                      failurePrefix: 'Failed to reject event: ',
                      operation: EventService().rejectEvent,
                    );
                  },
                  onSetPending: () async {
                    if (!widget.showActions) return;
                    await _runAction(
                      event: event,
                      successMessage: 'Set "${event.name}" to pending',
                      failurePrefix: 'Failed to set pending: ',
                      operation: EventService().resetEventToPending,
                    );
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Promote to admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2E),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Give a user admin privileges',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7B6E63),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF7B6E63), size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF6F1EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.65,
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
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFF9C2214), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF9C2214),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_selectedStudent == null) ...[
                CustomTextField(
                  label: 'Search Student',
                  hint: 'Enter name or email address',
                  controller: _searchController,
                  icon: Icons.search_rounded,
                ),
                const SizedBox(height: 16),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFCB6D22)),
                      ),
                    ),
                  )
                else if (_searchResults.isEmpty &&
                    _searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.person_off_rounded,
                              size: 40, color: Color(0xFFD6C8BB)),
                          const SizedBox(height: 12),
                          Text(
                            'No student found for "${_searchController.text}"',
                            style: const TextStyle(
                              color: Color(0xFF7B6E63),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Results',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B6E63)),
                      ),
                      const SizedBox(height: 12),
                      ..._searchResults.map((student) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                  color: const Color(0xFFF0EBE6), width: 1.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _isPromoting
                                    ? null
                                    : () => setState(
                                        () => _selectedStudent = student),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF2E7),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (student.name?.isNotEmpty ?? false)
                                                ? student.name![0].toUpperCase()
                                                : (student.email.isNotEmpty
                                                    ? student.email[0]
                                                        .toUpperCase()
                                                    : 'U'),
                                            style: const TextStyle(
                                              color: Color(0xFFCB6D22),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name?.isNotEmpty == true
                                                  ? student.name!
                                                  : student.email,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF0D1B2E),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              student.email,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF7B6E63),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCB6D22),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Select',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F1EB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E1D9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB6D22),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCB6D22).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (_selectedStudent!.name?.isNotEmpty ?? false)
                                ? _selectedStudent!.name![0].toUpperCase()
                                : (_selectedStudent!.email.isNotEmpty
                                    ? _selectedStudent!.email[0].toUpperCase()
                                    : 'U'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStudent!.name?.isNotEmpty == true
                                  ? _selectedStudent!.name!
                                  : _selectedStudent!.email,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D1B2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedStudent!.email,
                              style: const TextStyle(
                                color: Color(0xFF7B6E63),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _selectedStudent = null),
                        icon: const Icon(Icons.edit_rounded,
                            size: 20, color: Color(0xFFCB6D22)),
                        tooltip: 'Change Student',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD4C8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.admin_panel_settings_rounded,
                          color: Color(0xFFCB6D22), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This student will be promoted to admin. They will immediately gain full access to the admin dashboard and can approve or reject events.',
                          style: TextStyle(
                            color: Color(0xFF9C2214),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _selectedStudent == null
          ? [
              TextButton(
                onPressed: _isPromoting
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7B6E63),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]
          : [
              TextButton(
                onPressed: _isPromoting
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7B6E63),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isPromoting
                    ? null
                    : () => _promoteToAdmin(_selectedStudent!),
                icon: _isPromoting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.verified_user_rounded, size: 20),
                label: Text(
                  _isPromoting ? 'Promoting...' : 'Confirm Promote',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB6D22),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.onSetPending,
  });

  final EventModel event;
  final Color categoryColor;
  final String dateText;
  final String timeText;
  final bool showActions;
  final bool isProcessing;
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
                      onPressed: isProcessing ? null : onReject,
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
                      onPressed: isProcessing ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB6D22),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Approve'),
                      ),
                    ),
                  ),
                ] else if (event.approvalStatus ==
                    EventApprovalStatus.accepted) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : onReject,
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
                      onPressed: isProcessing ? null : onSetPending,
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
                ] else if (event.approvalStatus ==
                    EventApprovalStatus.rejected) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB6D22),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Approve'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : onSetPending,
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

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0EBE6), width: 1.5),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.4), size: 24),
          ],
        ),
      ),
    );
  }
}
