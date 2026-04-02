import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../services/gemini_event_assistant_service.dart';

class StudentEventBuilderScreen extends StatefulWidget {
  const StudentEventBuilderScreen({super.key});

  @override
  State<StudentEventBuilderScreen> createState() =>
      _StudentEventBuilderScreenState();
}

enum _EventBuilderStep {
  category,
  name,
  date,
  time,
  location,
  participantMode,
  attendees,
  description,
  review
}

class _StudentEventBuilderScreenState extends State<StudentEventBuilderScreen> {
  final EventService _eventService = EventService();
  final GeminiEventAssistantService _geminiService =
      GeminiEventAssistantService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _categories = const [
    'Hackathon',
    'Workshop',
    'Seminar',
    'Conference',
    'Festival',
    'Meetup',
  ];

  final List<_ChatMessage> _messages = [];

  _EventBuilderStep _step = _EventBuilderStep.category;
  String? _category;
  String? _name;
  DateTime? _date;
  TimeOfDay? _time;
  String? _location;
  bool _hasParticipantLimit = true;
  bool _participantModeChosen = false;
  int? _attendees;
  String? _description;
  bool _saving = false;
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _addAssistant(
        'Hi! I will help you create an event. First, pick an event category.');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addAssistant(String text) {
    setState(() => _messages.add(_ChatMessage(text: text, isUser: false)));
    _scrollToBottom();
  }

  void _addUser(String text) {
    setState(() => _messages.add(_ChatMessage(text: text, isUser: true)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _onCategorySelected(String category) {
    if (_saving || _thinking) return;

    final previousCategory = _category;
    setState(() => _category = category);

    if (_step == _EventBuilderStep.category) {
      _addUser(category);
      _step = _EventBuilderStep.name;
      _addAssistant('Great choice. What is the event name?');
      return;
    }

    if (previousCategory != null && previousCategory != category) {
      _addAssistant('Category updated to $category.');
    }
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    _date = DateTime(picked.year, picked.month, picked.day);
    _addUser(_formatDate(_date!));
    _step = _firstMissingStep();
    _addAssistant(_nextPromptForStep(_step));
  }

  Future<void> _pickTimeFromClock() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked == null) return;

    _time = picked;
    _addUser(_formatTime(_time!));
    _step = _firstMissingStep();
    _addAssistant(_nextPromptForStep(_step));
  }

  Future<void> _submitInput() async {
    if (_saving || _thinking || _step == _EventBuilderStep.review) return;
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    _inputController.clear();

    EventAssistantTurnResult? aiResult;
    if (_geminiService.isAvailable) {
      setState(() => _thinking = true);
      try {
        aiResult = await _geminiService.analyzeTurn(
          userMessage: input,
          step: _step.name,
          draft: _buildDraftMap(),
          categories: _categories,
        );
      } catch (_) {
        aiResult = null;
      } finally {
        if (mounted) setState(() => _thinking = false);
      }
    }

    if (aiResult != null &&
        (aiResult.intent == EventAssistantIntent.outOfScope ||
            aiResult.intent == EventAssistantIntent.unsafe ||
            aiResult.intent == EventAssistantIntent.appHelp)) {
      _addUser(input);
      _addAssistant(
        aiResult.assistantReply.isNotEmpty
            ? aiResult.assistantReply
            : 'I can help with event creation and related app details. Please share your event info.',
      );
      return;
    }

    final extracted = aiResult?.extracted ?? const <String, dynamic>{};
    final aiCategory = _extractString(extracted['category']);
    final aiName = _extractString(extracted['name']);
    final aiDate = _extractString(extracted['date']);
    final aiTime = _extractString(extracted['time']);
    final aiLocation = _extractString(extracted['location']);
    final aiDescription = _extractString(extracted['description']);
    final aiHasLimit = _extractBool(extracted['hasParticipantLimit']);
    final aiAttendeeCount = _extractInt(extracted['attendeeCount']);

    if (_tryPlannerAdvanceFromAi(
      rawInput: input,
      aiCategory: aiCategory,
      aiName: aiName,
      aiDate: aiDate,
      aiTime: aiTime,
      aiLocation: aiLocation,
      aiDescription: aiDescription,
      aiHasLimit: aiHasLimit,
      aiAttendeeCount: aiAttendeeCount,
      confidence: aiResult?.confidence,
    )) {
      return;
    }

    switch (_step) {
      case _EventBuilderStep.category:
        final matchedCategory =
            _matchCategory(input) ?? _matchCategory(aiCategory);
        if (matchedCategory == null) {
          _addAssistant('Select a category from the chips above to continue.');
          return;
        }
        _category = matchedCategory;
        _addUser(matchedCategory);
        _step = _EventBuilderStep.name;
        _addAssistant('Great choice. What is the event name?');
        break;
      case _EventBuilderStep.name:
        final candidateName =
            (aiName != null && aiName.length >= 3) ? aiName : input;
        if (candidateName.length < 3) {
          _addAssistant('Event name should be at least 3 characters.');
          return;
        }
        _name = candidateName;
        _addUser(candidateName);
        _step = _EventBuilderStep.date;
        _addAssistant(
            'What is the event date? (Example: 2026-04-15 or 15/04/2026)');
        break;
      case _EventBuilderStep.date:
        final parsedDate =
            _parseDate(input) ?? (aiDate == null ? null : _parseDate(aiDate));
        if (parsedDate == null) {
          _addAssistant('Please enter a valid date. Example: 2026-04-15.');
          return;
        }
        _date = parsedDate;
        _addUser(_formatDate(parsedDate));
        _step = _EventBuilderStep.time;
        _addAssistant('What is the start time? (Example: 14:30 or 2:30 PM)');
        break;
      case _EventBuilderStep.time:
        final parsedTime =
            _parseTime(input) ?? (aiTime == null ? null : _parseTime(aiTime));
        if (parsedTime == null) {
          _addAssistant(
              'Please enter a valid time. Example: 14:30 or 2:30 PM.');
          return;
        }
        _time = parsedTime;
        _addUser(_formatTime(parsedTime));
        _step = _EventBuilderStep.location;
        _addAssistant('Where is the event location?');
        break;
      case _EventBuilderStep.location:
        final candidateLocation =
            (aiLocation != null && aiLocation.length >= 3) ? aiLocation : input;
        if (candidateLocation.length < 3) {
          _addAssistant('Location looks too short. Please add a proper venue.');
          return;
        }
        _location = candidateLocation;
        _addUser(candidateLocation);
        _step = _EventBuilderStep.participantMode;
        _addAssistant(
          'Should this event track participant count? Reply yes or no.',
        );
        break;
      case _EventBuilderStep.participantMode:
        final normalized = input.toLowerCase();
        final yesValues = {'yes', 'y', 'track', 'required'};
        final noValues = {'no', 'n', 'skip', 'not needed', 'optional'};

        if (aiHasLimit != null) {
          _hasParticipantLimit = aiHasLimit;
          _participantModeChosen = true;
          _addUser(input);
          if (aiHasLimit) {
            _step = _EventBuilderStep.attendees;
            _addAssistant('How many attendees are expected?');
          } else {
            _attendees = null;
            _step = _EventBuilderStep.description;
            _addAssistant('Got it. Add a short event description or theme.');
          }
          return;
        }

        if (yesValues.contains(normalized)) {
          _hasParticipantLimit = true;
          _participantModeChosen = true;
          _addUser(input);
          _step = _EventBuilderStep.attendees;
          _addAssistant('How many attendees are expected?');
          return;
        }

        if (noValues.contains(normalized)) {
          _hasParticipantLimit = false;
          _participantModeChosen = true;
          _attendees = null;
          _addUser(input);
          _step = _EventBuilderStep.description;
          _addAssistant('Got it. Add a short event description or theme.');
          return;
        }

        _addAssistant('Please answer with yes or no.');
        break;
      case _EventBuilderStep.attendees:
        final count = int.tryParse(input) ?? aiAttendeeCount;
        if (count == null || count <= 0) {
          _addAssistant(
              'Please provide a valid attendee count (numbers only).');
          return;
        }
        _attendees = count;
        _addUser(count.toString());
        _step = _EventBuilderStep.description;
        _addAssistant('Add a short event description or theme.');
        break;
      case _EventBuilderStep.description:
        final candidateDescription =
            (aiDescription != null && aiDescription.length >= 10)
                ? aiDescription
                : input;
        if (candidateDescription.length < 10) {
          _addAssistant('Description should be at least 10 characters.');
          return;
        }
        _description = candidateDescription;
        _addUser(candidateDescription);
        _step = _EventBuilderStep.review;
        _addAssistant('Perfect. Review the event details below and save.');
        break;
      case _EventBuilderStep.review:
        break;
    }
  }

  Map<String, dynamic> _buildDraftMap() {
    return {
      'category': _category,
      'name': _name,
      'date': _date == null
          ? null
          : '${_date!.year}-${_two(_date!.month)}-${_two(_date!.day)}',
      'time':
          _time == null ? null : '${_two(_time!.hour)}:${_two(_time!.minute)}',
      'location': _location,
      'hasParticipantLimit': _hasParticipantLimit,
      'participantModeChosen': _participantModeChosen,
      'attendeeCount': _attendees,
      'description': _description,
    };
  }

  bool _tryPlannerAdvanceFromAi({
    required String rawInput,
    required String? aiCategory,
    required String? aiName,
    required String? aiDate,
    required String? aiTime,
    required String? aiLocation,
    required String? aiDescription,
    required bool? aiHasLimit,
    required int? aiAttendeeCount,
    required double? confidence,
  }) {
    var changed = false;

    final matchedCategory = _matchCategory(aiCategory);
    if (_category == null && matchedCategory != null) {
      _category = matchedCategory;
      changed = true;
    }

    if (_name == null && aiName != null && aiName.length >= 3) {
      _name = aiName;
      changed = true;
    }

    if (_date == null && aiDate != null) {
      final parsed = _parseDate(aiDate);
      if (parsed != null) {
        _date = parsed;
        changed = true;
      }
    }

    if (_time == null && aiTime != null) {
      final parsed = _parseTime(aiTime);
      if (parsed != null) {
        _time = parsed;
        changed = true;
      }
    }

    if (_location == null && aiLocation != null && aiLocation.length >= 3) {
      _location = aiLocation;
      changed = true;
    }

    if (aiHasLimit != null) {
      _hasParticipantLimit = aiHasLimit;
      _participantModeChosen = true;
      if (!aiHasLimit) {
        _attendees = null;
      }
      changed = true;
    }

    if (_participantModeChosen && _hasParticipantLimit && _attendees == null) {
      if (aiAttendeeCount != null && aiAttendeeCount > 0) {
        _attendees = aiAttendeeCount;
        changed = true;
      }
    }

    if (_description == null &&
        aiDescription != null &&
        aiDescription.length >= 10) {
      _description = aiDescription;
      changed = true;
    }

    final shouldAdvance = changed && (confidence ?? 0) >= 0.55;
    if (!shouldAdvance) return false;

    _addUser(rawInput);
    _step = _firstMissingStep();

    if (_step == _EventBuilderStep.review) {
      _addAssistant(
          'Great, I captured the details. Review the summary and save.');
    } else {
      _addAssistant(_nextPromptForStep(_step));
    }

    return true;
  }

  _EventBuilderStep _firstMissingStep() {
    if (_category == null) return _EventBuilderStep.category;
    if (_name == null) return _EventBuilderStep.name;
    if (_date == null) return _EventBuilderStep.date;
    if (_time == null) return _EventBuilderStep.time;
    if (_location == null) return _EventBuilderStep.location;
    if (!_participantModeChosen) return _EventBuilderStep.participantMode;
    if (_hasParticipantLimit && _attendees == null)
      return _EventBuilderStep.attendees;
    if (_description == null) return _EventBuilderStep.description;
    return _EventBuilderStep.review;
  }

  String _nextPromptForStep(_EventBuilderStep step) {
    switch (step) {
      case _EventBuilderStep.category:
        return 'Pick an event category from the chips above.';
      case _EventBuilderStep.name:
        return 'What is the event name?';
      case _EventBuilderStep.date:
        return 'What is the event date? (Example: 2026-04-15 or 15/04/2026)';
      case _EventBuilderStep.time:
        return 'What is the start time? (Example: 14:30 or 2:30 PM)';
      case _EventBuilderStep.location:
        return 'Where is the event location?';
      case _EventBuilderStep.participantMode:
        return 'Should this event track participant count? Reply yes or no.';
      case _EventBuilderStep.attendees:
        return 'How many attendees are expected?';
      case _EventBuilderStep.description:
        return 'Add a short event description or theme.';
      case _EventBuilderStep.review:
        return 'Review the summary and save when ready.';
    }
  }

  String? _extractString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }

  bool? _extractBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == 'yes') return true;
      if (normalized == 'false' || normalized == 'no') return false;
    }
    return null;
  }

  int? _extractInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String? _matchCategory(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final category in _categories) {
      if (category.toLowerCase() == normalized) return category;
    }
    return null;
  }

  Future<void> _saveEvent() async {
    if (_saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addAssistant('You need to be logged in to save events.');
      return;
    }

    if (_category == null ||
        _name == null ||
        _date == null ||
        _time == null ||
        _location == null ||
        (_hasParticipantLimit && _attendees == null) ||
        _description == null) {
      _addAssistant(
          'Some details are still missing. Please complete the flow.');
      return;
    }

    setState(() => _saving = true);
    try {
      final hasParticipantLimit =
          _participantModeChosen ? _hasParticipantLimit : _attendees != null;

      final event = EventModel(
        createdBy: user.uid,
        category: _category!,
        name: _name!,
        date: _date!,
        time: TimeOfDayData(hour: _time!.hour, minute: _time!.minute),
        location: _location!,
        hasParticipantLimit: hasParticipantLimit,
        attendeeCount: hasParticipantLimit ? _attendees : null,
        description: _description!,
      );
      await _eventService.createEvent(event);

      if (!mounted) return;
      _addAssistant(
          'Your event is created successfully. You can start another one.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully.')),
      );
      _resetBuilder();
    } catch (_) {
      _addAssistant('Could not save the event right now. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetBuilder() {
    setState(() {
      _category = null;
      _name = null;
      _date = null;
      _time = null;
      _location = null;
      _hasParticipantLimit = true;
      _participantModeChosen = false;
      _attendees = null;
      _description = null;
      _step = _EventBuilderStep.category;
    });
    _addAssistant('Let us build a new event. First, pick a category.');
  }

  Future<void> _openEditSummarySheet() async {
    final nameCtrl = TextEditingController(text: _name ?? '');
    final locationCtrl = TextEditingController(text: _location ?? '');
    final attendeesCtrl =
        TextEditingController(text: (_attendees ?? '').toString());
    final descriptionCtrl = TextEditingController(text: _description ?? '');

    String tempCategory = _category ?? _categories.first;
    DateTime tempDate = _date ?? DateTime.now();
    TimeOfDay tempTime = _time ?? const TimeOfDay(hour: 9, minute: 0);
    bool tempHasParticipantLimit = _hasParticipantLimit;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F1EB),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit event details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D1B2E),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: tempCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => tempCategory = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Event name'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2040),
                              );
                              if (picked == null) return;
                              setModalState(() => tempDate = picked);
                            },
                            child: Text('Date: ${_formatDate(tempDate)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: tempTime,
                              );
                              if (picked == null) return;
                              setModalState(() => tempTime = picked);
                            },
                            child: Text('Time: ${_formatTime(tempTime)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: tempHasParticipantLimit,
                      onChanged: (value) {
                        setModalState(() => tempHasParticipantLimit = value);
                        if (!value) {
                          attendeesCtrl.clear();
                        }
                      },
                      title: const Text('Track participant count'),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: attendeesCtrl,
                      enabled: tempHasParticipantLimit,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Attendee count'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final attendees =
                              int.tryParse(attendeesCtrl.text.trim());
                          final requiresAttendees = tempHasParticipantLimit;
                          if (nameCtrl.text.trim().isEmpty ||
                              locationCtrl.text.trim().isEmpty ||
                              descriptionCtrl.text.trim().length < 10 ||
                              (requiresAttendees &&
                                  (attendees == null || attendees <= 0))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Please provide valid details.')),
                            );
                            return;
                          }

                          setState(() {
                            _category = tempCategory;
                            _name = nameCtrl.text.trim();
                            _date = DateTime(
                                tempDate.year, tempDate.month, tempDate.day);
                            _time = tempTime;
                            _location = locationCtrl.text.trim();
                            _hasParticipantLimit = tempHasParticipantLimit;
                            _participantModeChosen = true;
                            _attendees =
                                tempHasParticipantLimit ? attendees : null;
                            _description = descriptionCtrl.text.trim();
                            _step = _EventBuilderStep.review;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _parseDate(String input) {
    final value = input.trim().toLowerCase();
    final now = DateTime.now();

    if (value == 'today') return DateTime(now.year, now.month, now.day);
    if (value == 'tomorrow') {
      final t = now.add(const Duration(days: 1));
      return DateTime(t.year, t.month, t.day);
    }

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
    final dmy = RegExp(r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$');

    if (iso.hasMatch(value)) {
      final m = iso.firstMatch(value)!;
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      return DateTime.tryParse('$y-${_two(mo)}-${_two(d)}');
    }

    if (dmy.hasMatch(value)) {
      final m = dmy.firstMatch(value)!;
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      return DateTime.tryParse('$y-${_two(mo)}-${_two(d)}');
    }

    return null;
  }

  TimeOfDay? _parseTime(String input) {
    final value = input.trim().toLowerCase();
    final re = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?$');
    final match = re.firstMatch(value);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3);

    if (minute < 0 || minute > 59) return null;

    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'pm' && hour != 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
    } else {
      if (hour < 0 || hour > 23) return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}';

  String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour12 =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    return '${_two(hour12)}:${_two(time.minute)} $period';
  }

  @override
  Widget build(BuildContext context) {
    final isReview = _step == _EventBuilderStep.review;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D1B2E),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Event Builder',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D1B2E),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C0D1B2E),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guided event chat',
                      style: TextStyle(
                        color: Color(0xFFCB6D22),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'The assistant will collect category, name, date, time, location, and description. Participant count is optional per event.',
                      style: TextStyle(
                        color: Color(0xFF4E6076),
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isReview) _buildSummaryCard(),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                itemCount: _messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return msg.isUser
                      ? _UserMessage(text: msg.text)
                      : _AssistantMessage(text: msg.text);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event category (change anytime)',
                    style: TextStyle(
                      color: Color(0xFF6A5A4A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _CategoryPill(
                                label: c,
                                isSelected: _category == c,
                                onTap: () => _onCategorySelected(c),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E1D8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    if (_step == _EventBuilderStep.date)
                      IconButton(
                        tooltip: 'Pick date',
                        onPressed: _thinking ? null : _pickDateFromCalendar,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    if (_step == _EventBuilderStep.time)
                      IconButton(
                        tooltip: 'Pick time',
                        onPressed: _thinking ? null : _pickTimeFromClock,
                        icon: const Icon(Icons.access_time_rounded),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !isReview && !_saving && !_thinking,
                        minLines: 1,
                        maxLines: 3,
                        onSubmitted: (_) => _submitInput(),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isReview
                              ? 'Review details and save'
                              : _thinking
                                  ? 'Assistant is thinking...'
                                  : 'Type your response...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6D7680),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: isReview || _saving || _thinking
                          ? null
                          : _submitInput,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isReview || _thinking)
                              ? const Color(0xFF8A98A9)
                              : const Color(0xFF0D1B2E),
                          shape: BoxShape.circle,
                        ),
                        child: (_saving || _thinking)
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x180D1B2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event summary',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B2E),
              ),
            ),
            const SizedBox(height: 10),
            _SummaryLine(label: 'Category', value: _category ?? '-'),
            _SummaryLine(label: 'Name', value: _name ?? '-'),
            _SummaryLine(
                label: 'Date',
                value: _date == null ? '-' : _formatDate(_date!)),
            _SummaryLine(
                label: 'Time',
                value: _time == null ? '-' : _formatTime(_time!)),
            _SummaryLine(label: 'Location', value: _location ?? '-'),
            _SummaryLine(
              label: 'Participant count',
              value: _hasParticipantLimit
                  ? (_attendees == null ? '-' : _attendees.toString())
                  : 'Not required',
            ),
            _SummaryLine(label: 'Description', value: _description ?? '-'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openEditSummarySheet,
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _saveEvent,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCB6D22),
                    ),
                    child: const Text('Save event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0D1B2E) : const Color(0x160D1B2E),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF2D4158),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  final String text;

  const _AssistantMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.68;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFCB6D22),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0D1B2E),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF2C3F54),
                  fontSize: 15.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserMessage extends StatelessWidget {
  final String text;

  const _UserMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.7;

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA7C2D),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF8E7A69),
            child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF2C3F54),
            fontSize: 13.5,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
