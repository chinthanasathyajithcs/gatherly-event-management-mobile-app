import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/gemini_event_assistant_service.dart';

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
  duration,
  location,
  participantMode,
  attendees,
  description,
  qnaMode,
  qrAttendanceMode,
  review
}

class _StudentEventBuilderScreenState extends State<StudentEventBuilderScreen> {
  final EventService _eventService = EventService();
  final GeminiEventAssistantService _geminiService =
      GeminiEventAssistantService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _categories = const [
    'Hackathon',
    'Workshop',
    'Seminar',
    'Conference',
    'Festival',
    'Meetup',
    'Webinar',
    'Competition',
    'Career Fair',
    'Networking',
    'Sports',
    'Cultural',
    'Orientation',
    'Volunteering',
  ];

  final List<_ChatMessage> _messages = [];

  _EventBuilderStep _step = _EventBuilderStep.category;
  String? _category;
  String? _name;
  DateTime? _date;
  TimeOfDay? _time;
  int? _durationHours;
  String? _location;
  bool _hasParticipantLimit = true;
  bool _participantModeChosen = false;
  int? _attendees;
  String? _description;
  String? _posterImageUrl;
  bool _isQnaEnabled = false;
  bool _qnaModeChosen = false;
  bool _isQrAttendanceEnabled = false;
  bool _qrAttendanceModeChosen = false;
  bool _saving = false;
  bool _thinking = false;
  bool _uploadingPoster = false;
  String? _clubId;
  String? _clubName;

  static const int _builderStepsCount = 11;

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
    _focusNode.dispose();
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
    _focusNode.requestFocus();
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
    _focusNode.requestFocus();
  }

  Future<void> _submitInput() async {
    if (_saving || _thinking || _step == _EventBuilderStep.review) return;
    final input = _inputController.text.trim();
    if (input.isEmpty) return;

    _inputController.clear();
    _addUser(input);

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
        if (mounted) {
          setState(() => _thinking = false);
          if (_step != _EventBuilderStep.review) {
            _focusNode.requestFocus();
          }
        }
      }
    }

    if (aiResult != null &&
        (aiResult.intent == EventAssistantIntent.outOfScope ||
            aiResult.intent == EventAssistantIntent.unsafe ||
            aiResult.intent == EventAssistantIntent.appHelp)) {
      _addAssistant(
        aiResult.assistantReply.isNotEmpty
            ? aiResult.assistantReply
            : 'I can help with event creation and related app details. Please share your event info.',
      );
      return;
    }

    final extracted = aiResult?.extracted ?? const <String, dynamic>{};
    final aiCategory = _extractString(extracted['category']);
    final aiSuggestedCategory = _extractString(extracted['suggestedCategory']);
    final aiName = _extractString(extracted['name']);
    final aiDate = _extractString(extracted['date']);
    final aiTime = _extractString(extracted['time']);
    final aiLocation = _extractString(extracted['location']);
    final aiDescription = _extractString(extracted['description']);
    final aiPosterImageUrl = _extractString(extracted['posterImageUrl']);
    final aiHasLimit = _extractBool(extracted['hasParticipantLimit']);
    final aiAttendeeCount = _extractInt(extracted['attendeeCount']);

    if (_tryPlannerAdvanceFromAi(
      aiCategory: aiCategory,
      aiName: aiName,
      aiDate: aiDate,
      aiTime: aiTime,
      aiLocation: aiLocation,
      aiDescription: aiDescription,
      aiPosterImageUrl: aiPosterImageUrl,
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
        final customCategory = _sanitizeCustomCategory(aiCategory ?? input);
        final resolvedCategory = matchedCategory ?? customCategory;

        if (resolvedCategory == null) {
          _addAssistant(
              'Please type a category (you can write your own) or pick one from the chips.');
          return;
        }

        _category = resolvedCategory;
        final suggestedCategory = _matchCategory(aiSuggestedCategory) ??
            _suggestKnownCategory(input) ??
            _suggestKnownCategory(aiCategory);

        _step = _EventBuilderStep.name;
        if (suggestedCategory != null &&
            suggestedCategory.toLowerCase() != resolvedCategory.toLowerCase()) {
          _addAssistant(
            'Nice category: "$resolvedCategory". Suggested standard category: "$suggestedCategory". You can tap the chip to switch, or keep your custom one.\n\nWhat is the event name?',
          );
        } else {
          _addAssistant('Great choice. What is the event name?');
        }
        break;
      case _EventBuilderStep.name:
        final candidateName =
            (aiName != null && aiName.length >= 3) ? aiName : input;
        if (candidateName.length < 2) {
          _addAssistant('Event name is too short. Add at least 2 characters.');
          return;
        }
        _name = candidateName;
        _step = _EventBuilderStep.date;
        _addAssistant(
            'What is the event date? (Example: 2026-04-15 or 15/04/2026)');
        break;
      case _EventBuilderStep.date:
        final parsedDate =
            _parseDate(input) ?? (aiDate == null ? null : _parseDate(aiDate));
        if (parsedDate == null) {
          _addAssistant(
              'Please enter a valid date. Example: 2026-04-15, 15/04/2026, or tomorrow.');
          return;
        }
        _date = parsedDate;
        _step = _EventBuilderStep.time;
        _addAssistant(
            'What is the start time? (Example: 14:30, 2:30 PM, or 2pm)');
        break;
      case _EventBuilderStep.time:
        final parsedTime =
            _parseTime(input) ?? (aiTime == null ? null : _parseTime(aiTime));
        if (parsedTime == null) {
          _addAssistant(
              'Please enter a valid time. Example: 14:30, 2:30 PM, or 2pm.');
          return;
        }
        _time = parsedTime;
        _step = _EventBuilderStep.duration;
        _addAssistant('How long is the event in hours? (Example: 2, 4)');
        break;
      case _EventBuilderStep.duration:
        final extractedDuration = RegExp(r'\d+').firstMatch(input)?.group(0);
        final parsedDuration = int.tryParse(extractedDuration ?? '');
        if (parsedDuration == null || parsedDuration <= 0) {
          _addAssistant('Please enter a valid duration in hours. Example: 2, 4');
          return;
        }
        _durationHours = parsedDuration;
        _step = _EventBuilderStep.location;
        _addAssistant('Where is the event location?');
        break;
      case _EventBuilderStep.location:
        final candidateLocation =
            (aiLocation != null && aiLocation.length >= 3) ? aiLocation : input;
        if (candidateLocation.length < 2) {
          _addAssistant('Location looks too short. Please add a proper venue.');
          return;
        }
        _location = candidateLocation;
        _step = _EventBuilderStep.participantMode;
        _addAssistant(
          'Should this event track participant count? Reply yes or no.',
        );
        break;
      case _EventBuilderStep.participantMode:
        final normalized = input.toLowerCase();
        final yesValues = {'yes', 'y', 'track', 'required'};
        final noValues = {'no', 'n', 'skip', 'not needed', 'optional'};
        final hasYesSignal = yesValues.any(normalized.contains);
        final hasNoSignal = noValues.any(normalized.contains);

        if (aiHasLimit != null) {
          _hasParticipantLimit = aiHasLimit;
          _participantModeChosen = true;
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

        if (hasYesSignal) {
          _hasParticipantLimit = true;
          _participantModeChosen = true;
          _step = _EventBuilderStep.attendees;
          _addAssistant('How many attendees are expected?');
          return;
        }

        if (hasNoSignal) {
          _hasParticipantLimit = false;
          _participantModeChosen = true;
          _attendees = null;
          _step = _EventBuilderStep.description;
          _addAssistant('Got it. Add a short event description or theme.');
          return;
        }

        _addAssistant('Please answer with yes or no.');
        break;
      case _EventBuilderStep.attendees:
        final extractedCount = RegExp(r'\d+').firstMatch(input)?.group(0);
        final count = int.tryParse(extractedCount ?? '') ?? aiAttendeeCount;
        if (count == null || count <= 0) {
          _addAssistant(
              'Please provide a valid attendee count (numbers only).');
          return;
        }
        _attendees = count;
        _step = _EventBuilderStep.description;
        _addAssistant('Add a short event description or theme.');
        break;
      case _EventBuilderStep.description:
        final candidateDescription =
            (aiDescription != null && aiDescription.length >= 8)
                ? aiDescription
                : input;
        if (candidateDescription.length < 8) {
          _addAssistant(
              'Description is a bit short. Add at least 8 characters.');
          return;
        }
        _description = candidateDescription;
        _step = _EventBuilderStep.qnaMode;
        _addAssistant('Perfect. Will this event feature a live Q&A session? Reply yes or no.');
        break;
      case _EventBuilderStep.qnaMode:
        final normalized = input.toLowerCase();
        final yesValues = {'yes', 'y', 'enable', 'sure'};
        final noValues = {'no', 'n', 'disable', 'skip'};
        final hasYesSignal = yesValues.any(normalized.contains);
        final hasNoSignal = noValues.any(normalized.contains);

        if (hasYesSignal) {
          _isQnaEnabled = true;
          _qnaModeChosen = true;
          _step = _EventBuilderStep.qrAttendanceMode;
          _addAssistant('Live Q&A enabled. Will this event require QR code check-in for attendance? Reply yes or no.');
          return;
        }

        if (hasNoSignal) {
          _isQnaEnabled = false;
          _qnaModeChosen = true;
          _step = _EventBuilderStep.qrAttendanceMode;
          _addAssistant('Live Q&A skipped. Will this event require QR code check-in for attendance? Reply yes or no.');
          return;
        }

        _addAssistant('Please answer with yes or no.');
        break;
      case _EventBuilderStep.qrAttendanceMode:
        final normalizedQr = input.toLowerCase();
        final yesValuesQr = {'yes', 'y', 'enable', 'sure', 'require'};
        final noValuesQr = {'no', 'n', 'disable', 'skip'};
        final hasYesSignalQr = yesValuesQr.any(normalizedQr.contains);
        final hasNoSignalQr = noValuesQr.any(normalizedQr.contains);

        if (hasYesSignalQr) {
          _isQrAttendanceEnabled = true;
          _qrAttendanceModeChosen = true;
          _step = _EventBuilderStep.review;
          _addAssistant('QR check-in enabled. Review the event details below and save.');
          return;
        }

        if (hasNoSignalQr) {
          _isQrAttendanceEnabled = false;
          _qrAttendanceModeChosen = true;
          _step = _EventBuilderStep.review;
          _addAssistant('QR check-in skipped. Review the event details below and save.');
          return;
        }

        _addAssistant('Please answer with yes or no.');
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
      'posterImageUrl': _posterImageUrl,
      'isQnaEnabled': _isQnaEnabled,
      'isQrAttendanceEnabled': _isQrAttendanceEnabled,
    };
  }

  bool _tryPlannerAdvanceFromAi({
    required String? aiCategory,
    required String? aiName,
    required String? aiDate,
    required String? aiTime,
    required String? aiLocation,
    required String? aiDescription,
    required String? aiPosterImageUrl,
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

    if (_posterImageUrl == null && aiPosterImageUrl != null) {
      final normalized = _normalizePosterUrl(aiPosterImageUrl);
      if (normalized != null) {
        _posterImageUrl = normalized;
        changed = true;
      }
    }

    final shouldAdvance = changed && (confidence ?? 0) >= 0.55;
    if (!shouldAdvance) return false;

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
    if (_durationHours == null) return _EventBuilderStep.duration;
    if (_location == null) return _EventBuilderStep.location;
    if (!_participantModeChosen) return _EventBuilderStep.participantMode;
    if (_hasParticipantLimit && _attendees == null)
      return _EventBuilderStep.attendees;
    if (_description == null) return _EventBuilderStep.description;
    if (!_qnaModeChosen) return _EventBuilderStep.qnaMode;
    if (!_qrAttendanceModeChosen) return _EventBuilderStep.qrAttendanceMode;
    return _EventBuilderStep.review;
  }

  String _nextPromptForStep(_EventBuilderStep step) {
    switch (step) {
      case _EventBuilderStep.category:
        return 'Pick an event category from the chips, or type your own category.';
      case _EventBuilderStep.name:
        return 'What is the event name?';
      case _EventBuilderStep.date:
        return 'What is the event date? (Example: 2026-04-15 or 15/04/2026)';
      case _EventBuilderStep.time:
        return 'What is the start time? (Example: 14:30, 2:30 PM, or 2pm)';
      case _EventBuilderStep.duration:
        return 'How long is the event in hours? (Example: 2, 4)';
      case _EventBuilderStep.location:
        return 'Where is the event location?';
      case _EventBuilderStep.participantMode:
        return 'Should this event track participant count? Reply yes or no.';
      case _EventBuilderStep.attendees:
        return 'How many attendees are expected?';
      case _EventBuilderStep.description:
        return 'Add a short event description or theme.';
      case _EventBuilderStep.qnaMode:
        return 'Will this event feature a live Q&A session? Reply yes or no.';
      case _EventBuilderStep.qrAttendanceMode:
        return 'Will this event require QR code check-in for attendance? Reply yes or no.';
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

  String? _sanitizeCustomCategory(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.length < 2) return null;
    return _toTitleCase(value);
  }

  String? _suggestKnownCategory(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final category in _categories) {
      final categoryLower = category.toLowerCase();
      if (normalized.contains(categoryLower) ||
          categoryLower.contains(normalized)) {
        return category;
      }
    }

    if (normalized.contains('code') ||
        normalized.contains('build') ||
        normalized.contains('prototype')) {
      return 'Hackathon';
    }
    if (normalized.contains('training') ||
        normalized.contains('hands-on') ||
        normalized.contains('bootcamp')) {
      return 'Workshop';
    }
    if (normalized.contains('talk') || normalized.contains('speaker')) {
      return 'Seminar';
    }
    if (normalized.contains('virtual') || normalized.contains('online')) {
      return 'Webinar';
    }
    if (normalized.contains('job') || normalized.contains('career')) {
      return 'Career Fair';
    }
    if (normalized.contains('network')) {
      return 'Networking';
    }
    if (normalized.contains('sport') || normalized.contains('tournament')) {
      return 'Sports';
    }
    if (normalized.contains('culture') || normalized.contains('dance')) {
      return 'Cultural';
    }

    return null;
  }

  String _toTitleCase(String value) {
    final words = value.split(' ');
    return words.map((word) {
      if (word.isEmpty) return word;
      final first = word.substring(0, 1).toUpperCase();
      final rest = word.substring(1).toLowerCase();
      return '$first$rest';
    }).join(' ');
  }

  String? _normalizePosterUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return value;
  }

  Future<String?> _pickAndUploadPoster() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in first to upload an event poster.'),
          ),
        );
      }
      return null;
    }

    try {
      setState(() => _uploadingPoster = true);

      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (picked == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected from gallery.')),
          );
        }
        return null;
      }

      final bytes = await picked.readAsBytes();
      final fileName =
          'poster_${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';
      final app = FirebaseAuth.instance.app;
      final bucket = app.options.storageBucket;
      final fallbackBucket = (bucket != null && bucket.isNotEmpty)
          ? bucket
          : '${app.options.projectId}.firebasestorage.app';
      final storage = FirebaseStorage.instanceFor(bucket: fallbackBucket);

      final ref = storage.ref().child('event_posters/${user.uid}/$fileName');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() => _posterImageUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster uploaded successfully.')),
        );
      }
      _addAssistant(
          'Poster uploaded successfully. I attached it to the event.');
      return url;
    } on FirebaseException catch (e) {
      if (mounted) {
        final msg = switch (e.code) {
          'unauthorized' =>
            'Upload blocked by Firebase Storage rules. Please allow authenticated uploads.',
          'object-not-found' =>
            'Storage bucket not found. Please verify Firebase Storage is configured.',
          _ => 'Poster upload failed: ${e.message ?? e.code}',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Poster upload failed: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingPoster = false);
    }
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
        _durationHours == null ||
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
        durationHours: _durationHours ?? 2,
        location: _location!,
        hasParticipantLimit: hasParticipantLimit,
        attendeeCount: hasParticipantLimit ? _attendees : null,
        description: _description!,
        posterImageUrl: _normalizePosterUrl(_posterImageUrl),
        isQnaEnabled: _isQnaEnabled,
        isQrAttendanceEnabled: _isQrAttendanceEnabled,
        clubId: _clubId,
        clubName: _clubName,
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
      _durationHours = null;
      _location = null;
      _hasParticipantLimit = true;
      _participantModeChosen = false;
      _attendees = null;
      _description = null;
      _posterImageUrl = null;
      _isQnaEnabled = false;
      _qnaModeChosen = false;
      _isQrAttendanceEnabled = false;
      _qrAttendanceModeChosen = false;
      _clubId = null;
      _clubName = null;
      _step = _EventBuilderStep.category;
    });
    _addAssistant('Let us build a new event. First, pick a category.');
    _focusNode.requestFocus();
  }

  Future<void> _openEditSummarySheet() async {
    final nameCtrl = TextEditingController(text: _name ?? '');
    final durationCtrl = TextEditingController(text: (_durationHours ?? 2).toString());
    final locationCtrl = TextEditingController(text: _location ?? '');
    final attendeesCtrl =
        TextEditingController(text: (_attendees ?? '').toString());
    final descriptionCtrl = TextEditingController(text: _description ?? '');
    final posterCtrl = TextEditingController(text: _posterImageUrl ?? '');

    String tempCategory = _category ?? _categories.first;
    DateTime tempDate = _date ?? DateTime.now();
    TimeOfDay tempTime = _time ?? const TimeOfDay(hour: 9, minute: 0);
    bool tempHasParticipantLimit = _hasParticipantLimit;
    bool tempIsQnaEnabled = _isQnaEnabled;

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
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (hours)'),
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
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: tempIsQnaEnabled,
                      onChanged: (value) {
                        setModalState(() => tempIsQnaEnabled = value);
                      },
                      title: const Text('Enable Live Q&A Session'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: posterCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Poster image URL (optional)',
                        hintText: 'https://example.com/event-poster.jpg',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _uploadingPoster
                            ? null
                            : () async {
                                final uploadedUrl =
                                    await _pickAndUploadPoster();
                                if (uploadedUrl == null) return;
                                setModalState(() {
                                  posterCtrl.text = uploadedUrl;
                                });
                              },
                        icon: _uploadingPoster
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _uploadingPoster
                              ? 'Uploading from gallery...'
                              : 'Upload from gallery',
                        ),
                      ),
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
                            _durationHours = int.tryParse(durationCtrl.text.trim()) ?? 2;
                            _location = locationCtrl.text.trim();
                            _hasParticipantLimit = tempHasParticipantLimit;
                            _participantModeChosen = true;
                            _attendees =
                                tempHasParticipantLimit ? attendees : null;
                            _description = descriptionCtrl.text.trim();
                            _posterImageUrl =
                                _normalizePosterUrl(posterCtrl.text.trim());
                            _isQnaEnabled = tempIsQnaEnabled;
                            _qnaModeChosen = true;
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
    final dmyDash = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$');

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

    if (dmyDash.hasMatch(value)) {
      final m = dmyDash.firstMatch(value)!;
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      return DateTime.tryParse('$y-${_two(mo)}-${_two(d)}');
    }

    final parsed = DateTime.tryParse(input.trim());
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return null;
  }

  TimeOfDay? _parseTime(String input) {
    final value = input.trim().toLowerCase();
    final re = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?$');
    final match = re.firstMatch(value);
    if (match == null) {
      final shortRe = RegExp(r'^(\d{1,2})\s*(am|pm)$');
      final shortMatch = shortRe.firstMatch(value);
      if (shortMatch == null) return null;

      var hour = int.parse(shortMatch.group(1)!);
      if (hour < 1 || hour > 12) return null;
      final meridiem = shortMatch.group(2);
      if (meridiem == 'pm' && hour != 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: 0);
    }

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

  int _completedStepCount() {
    var count = 0;
    if (_category != null) count++;
    if (_name != null) count++;
    if (_date != null) count++;
    if (_time != null) count++;
    if (_durationHours != null) count++;
    if (_location != null) count++;
    if (_participantModeChosen) count++;
    if (!_hasParticipantLimit || _attendees != null) count++;
    if (_description != null) count++;
    if (_qnaModeChosen) count++;
    if (_qrAttendanceModeChosen) count++;
    return count;
  }

  String _stepLabel(_EventBuilderStep step) {
    switch (step) {
      case _EventBuilderStep.category:
        return 'Category';
      case _EventBuilderStep.name:
        return 'Name';
      case _EventBuilderStep.date:
        return 'Date';
      case _EventBuilderStep.time:
        return 'Time';
      case _EventBuilderStep.duration:
        return 'Duration';
      case _EventBuilderStep.location:
        return 'Location';
      case _EventBuilderStep.participantMode:
        return 'Participant Mode';
      case _EventBuilderStep.attendees:
        return 'Attendees';
      case _EventBuilderStep.description:
        return 'Description';
      case _EventBuilderStep.qnaMode:
        return 'Live Q&A';
      case _EventBuilderStep.qrAttendanceMode:
        return 'QR Check-in';
      case _EventBuilderStep.review:
        return 'Review';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReview = _step == _EventBuilderStep.review;
    final completed = _completedStepCount();
    final progress = (completed / _builderStepsCount).clamp(0.0, 1.0);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guided event chat',
                      style: TextStyle(
                        color: Color(0xFFCB6D22),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Step $completed of $_builderStepsCount • ${isReview ? 'Ready to save' : _stepLabel(_step)}',
                      style: const TextStyle(
                        color: Color(0xFF0D1B2E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE7D9C8),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFCB6D22)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                itemCount:
                    _messages.length + (_thinking ? 1 : 0) + (isReview ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final messageCount = _messages.length;
                  final thinkingIndex = _thinking ? messageCount : -1;
                  final summaryIndex =
                      isReview ? messageCount + (_thinking ? 1 : 0) : -1;

                  if (_thinking && index == thinkingIndex) {
                    return const _AssistantTypingIndicator();
                  }
                  if (isReview && index == summaryIndex) {
                    return _buildSummaryCard(key: const ValueKey('summary'));
                  }

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
                  Text(
                    isReview
                        ? 'Review mode: you can still change category'
                        : 'Event category (change anytime)',
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
                        focusNode: _focusNode,
                        enabled: !isReview && !_saving && !_thinking,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _submitInput(),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isReview
                              ? 'Review details and save'
                              : _thinking
                                  ? 'Assistant is thinking...'
                                  : _nextPromptForStep(_step),
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

  Widget _buildSummaryCard({Key? key}) {
    return Container(
      key: key,
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
              label: 'Date', value: _date == null ? '-' : _formatDate(_date!)),
          _SummaryLine(
              label: 'Time', value: _time == null ? '-' : _formatTime(_time!)),
          _SummaryLine(
              label: 'Duration', value: _durationHours == null ? '-' : '${_durationHours} hours'),
          _SummaryLine(label: 'Location', value: _location ?? '-'),
          _SummaryLine(
            label: 'Participant count',
            value: _hasParticipantLimit
                ? (_attendees == null ? '-' : _attendees.toString())
                : 'Not required',
          ),
          const _SummaryLine(label: 'Approval status', value: 'Pending'),
          _SummaryLine(
            label: 'Live Q&A',
            value: _isQnaEnabled ? 'Enabled' : 'Disabled',
          ),
          _SummaryLine(label: 'Description', value: _description ?? '-'),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String?>(
                  value: _clubId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Club (Optional)',
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'No club (Independent)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String?>(
                        value: doc.id,
                        child: Text(
                          data['name']?.toString() ?? 'Unnamed club',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _clubId = val;
                      if (val == null) {
                        _clubName = null;
                      } else {
                        final data = docs.firstWhere((d) => d.id == val).data() as Map<String, dynamic>;
                        _clubName = data['name']?.toString();
                      }
                    });
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Poster',
            value: _posterImageUrl == null
                ? 'Category illustration'
                : 'Custom image',
          ),
          const SizedBox(height: 8),
          _EventPosterThumb(
            category: _category ?? 'Event',
            title: _name ?? 'Event',
            imageUrl: _posterImageUrl,
            height: 120,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadingPoster ? null : _pickAndUploadPoster,
              icon: _uploadingPoster
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_rounded),
              label: Text(
                _uploadingPoster
                    ? 'Uploading from gallery...'
                    : 'Upload poster from gallery',
              ),
            ),
          ),
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

class _AssistantTypingIndicator extends StatelessWidget {
  const _AssistantTypingIndicator();

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.5;

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
        ConstrainedBox(
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(),
                SizedBox(width: 6),
                _TypingDot(),
                SizedBox(width: 6),
                _TypingDot(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot();

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: const CircleAvatar(
        radius: 3,
        backgroundColor: Color(0xFF9AA8B6),
      ),
    );
  }
}

class _EventPosterThumb extends StatelessWidget {
  final String category;
  final String title;
  final String? imageUrl;
  final double height;

  const _EventPosterThumb({
    required this.category,
    required this.title,
    this.imageUrl,
    this.height = 100,
  });

  static const _categoryStyles = {
    'hackathon': [Color(0xFF0D1B2E), Color(0xFF1D4E89)],
    'workshop': [Color(0xFF1F6E8C), Color(0xFF2E8A99)],
    'seminar': [Color(0xFF6A4C93), Color(0xFF9C6ADE)],
    'conference': [Color(0xFF213555), Color(0xFF4F709C)],
    'festival': [Color(0xFFB84A00), Color(0xFFFF8A3D)],
    'meetup': [Color(0xFF355E3B), Color(0xFF5F8D4E)],
    'webinar': [Color(0xFF005B96), Color(0xFF00A8CC)],
    'competition': [Color(0xFF6A040F), Color(0xFFDC2F02)],
    'career fair': [Color(0xFF3A0CA3), Color(0xFF4361EE)],
    'networking': [Color(0xFF004B23), Color(0xFF38B000)],
    'sports': [Color(0xFF14213D), Color(0xFFFCA311)],
    'cultural': [Color(0xFF7B2CBF), Color(0xFFE0AAFF)],
    'orientation': [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    'volunteering': [Color(0xFF166534), Color(0xFF22C55E)],
  };

  @override
  Widget build(BuildContext context) {
    final normalizedCategory = category.trim().toLowerCase();
    final palette = _categoryStyles[normalizedCategory] ??
        const [Color(0xFF374151), Color(0xFF6B7280)];

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl!,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _FallbackPoster(
              category: category,
              title: title,
              palette: palette,
              height: height,
            );
          },
        ),
      );
    }

    return _FallbackPoster(
      category: category,
      title: title,
      palette: palette,
      height: height,
    );
  }
}

class _FallbackPoster extends StatelessWidget {
  final String category;
  final String title;
  final List<Color> palette;
  final double height;

  const _FallbackPoster({
    required this.category,
    required this.title,
    required this.palette,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            category,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.1,
            ),
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
