import 'dart:convert';
import 'event_director.dart';

/// Model-provider-agnostic generator; Gemini proxy supplies the text remotely.
abstract class TextGenerator {
  Future<String> generate({
    required String prompt,
    required int maxOutputTokens,
    required double temperature,
  });
}

/// The model suggests an event; it never gets access to engine mutators.
/// Invalid JSON, unknown kinds or excessive text are rejected before gameplay.
class StructuredAiEventDirector implements EventDirector {
  const StructuredAiEventDirector(this.generator);

  final TextGenerator generator;

  @override
  Future<EventProposal?> propose(DirectorContext context) async {
    try {
      final output = await generator.generate(
        prompt: '${context.compactPrompt}\n'
            '오직 JSON 객체만 반환: '
            '{"type":"strangerAtDoor","premise":"사건의 도입만","locationId":"${context.locationId}"}',
        maxOutputTokens: 128,
        temperature: 0.75,
      );
      if (output.length > 1200) return null;
      final decoded = jsonDecode(output);
      if (decoded is! Map<String, dynamic>) return null;

      final typeName = decoded['type'];
      final premise = decoded['premise'];
      if (typeName is! String || premise is! String) return null;
      final match = DirectedEventType.values.where((v) => v.name == typeName);
      if (match.isEmpty || premise.trim().length < 8 ||
          premise.trim().length > 180) {
        return null;
      }

      final locationId = decoded['locationId'];
      final npcName = decoded['npcName'];
      if (locationId != null && locationId is! String) return null;
      if (npcName != null && npcName is! String) return null;
      return EventProposal(
        type: match.first,
        premise: premise.trim(),
        locationId: locationId as String?,
        npcName: npcName as String?,
      );
    } catch (_) {
      // A lightweight model may produce malformed JSON: fall back cleanly.
      return null;
    }
  }
}

/// A failed, limited or unavailable API falls back to procedural events.
class FallbackEventDirector implements EventDirector {
  const FallbackEventDirector(this.primary, this.fallback);

  final EventDirector primary;
  final EventDirector fallback;

  @override
  Future<EventProposal?> propose(DirectorContext context) async {
    try {
      return await primary.propose(context) ?? await fallback.propose(context);
    } catch (_) {
      return fallback.propose(context);
    }
  }
}
