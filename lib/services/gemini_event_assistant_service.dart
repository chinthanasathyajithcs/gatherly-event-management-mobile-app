import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

enum EventAssistantIntent {
  createEvent,
  appHelp,
  outOfScope,
  unsafe,
  unknown,
}

class EventAssistantTurnResult {
  final EventAssistantIntent intent;
  final String assistantReply;
  final double confidence;
  final Map<String, dynamic> extracted;

  const EventAssistantTurnResult({
    required this.intent,
    required this.assistantReply,
    required this.confidence,
    required this.extracted,
  });
}

class GeminiEventAssistantService {
  GeminiEventAssistantService()
      : _apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  final String _apiKey;

  bool get isAvailable => _apiKey.isNotEmpty;

  Future<EventAssistantTurnResult?> analyzeTurn({
    required String userMessage,
    required String step,
    required Map<String, dynamic> draft,
    required List<String> categories,
  }) async {
    if (!isAvailable) return null;

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

    final prompt = '''
You are an AI assistant for a University Event Management app.
Your job:
1) Classify user intent.
2) Extract event fields if user is creating/updating an event.
3) Return strict JSON only.

Allowed intent values:
- create_event
- app_help
- out_of_scope
- unsafe

Rules:
- Stay in app scope: event creation, event details, event workflow help.
- If user asks unrelated things, set intent to out_of_scope.
- If user asks harmful/unsafe requests, set intent to unsafe.
- Never invent app features not given.
- For create_event, extract only what is reasonably clear.
- Do not force fields; use null when unknown.
- If user gives a custom category not in the allowed categories, keep it in "category".
- Also suggest the closest allowed category in "suggestedCategory" when possible.
- If user mentions an image/poster URL, put it in "posterImageUrl".

Current builder step: $step
Allowed categories: ${jsonEncode(categories)}
Current draft object: ${jsonEncode(draft)}
User message: ${jsonEncode(userMessage)}

Return JSON in this exact shape:
{
  "intent": "create_event|app_help|out_of_scope|unsafe",
  "assistantReply": "short reply for user",
  "confidence": 0.0,
  "extracted": {
    "category": "string|null",
    "suggestedCategory": "string|null",
    "name": "string|null",
    "date": "YYYY-MM-DD|null",
    "time": "HH:mm|null",
    "location": "string|null",
    "hasParticipantLimit": true,
    "attendeeCount": 0,
    "description": "string|null",
    "posterImageUrl": "string|null",
    "isQnaEnabled": "boolean|null",
    "isQrAttendanceEnabled": "boolean|null"
  }
}

Important:
- Output JSON only, no markdown, no extra text.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final rawText = response.text;
    if (rawText == null || rawText.trim().isEmpty) return null;

    final cleaned = _stripCodeFence(rawText);
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) return null;

    final intent = _parseIntent(decoded['intent'] as String?);
    final reply = (decoded['assistantReply'] as String? ?? '').trim();

    final confidenceRaw = decoded['confidence'];
    final confidence = switch (confidenceRaw) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0.0,
      _ => 0.0,
    };

    final extractedRaw = decoded['extracted'];
    final extracted = extractedRaw is Map<String, dynamic>
        ? extractedRaw
        : <String, dynamic>{};

    return EventAssistantTurnResult(
      intent: intent,
      assistantReply: reply,
      confidence: confidence,
      extracted: extracted,
    );
  }

  EventAssistantIntent _parseIntent(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'create_event':
        return EventAssistantIntent.createEvent;
      case 'app_help':
        return EventAssistantIntent.appHelp;
      case 'out_of_scope':
        return EventAssistantIntent.outOfScope;
      case 'unsafe':
        return EventAssistantIntent.unsafe;
      default:
        return EventAssistantIntent.unknown;
    }
  }

  String _stripCodeFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) return trimmed;

    final firstNewLine = trimmed.indexOf('\n');
    final lastFence = trimmed.lastIndexOf('```');
    if (firstNewLine == -1 || lastFence == -1 || lastFence <= firstNewLine) {
      return trimmed;
    }
    return trimmed.substring(firstNewLine + 1, lastFence).trim();
  }
}
