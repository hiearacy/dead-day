import 'generated_world_element.dart';

/// Typed player intent. The engine chooses effects, not the model.
enum StoryIntent { investigate, move, talk, observe }

class TurnChoice {
  const TurnChoice({
    required this.id, required this.text, required this.intent, this.targetId,
  });

  final String id;
  final String text;
  final StoryIntent intent;
  final String? targetId;

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'intent': intent.name, 'target_id': targetId};

  factory TurnChoice.fromJson(Map<String, dynamic> json) => TurnChoice(
        id: json['id'] as String,
        text: json['text'] as String,
        intent: StoryIntent.values.firstWhere(
          (kind) => kind.name == json['intent'],
          orElse: () => StoryIntent.observe,
        ),
        targetId: json['target_id'] as String?,
      );
}

/// A complete (non-streaming) story beat and its optional newly invented facts.
class StoryTurn {
  const StoryTurn({
    required this.id,
    required this.story,
    required this.choices,
    required this.generatedElements,
  });
  final String id;
  final String story;
  final List<TurnChoice> choices;
  final List<GeneratedWorldElement> generatedElements;

  Map<String, dynamic> toJson() => {
        'id': id, 'story': story,
        'choices': choices.map((v) => v.toJson()).toList(),
        'generated_elements': generatedElements.map((v) => v.toJson()).toList(),
      };

  factory StoryTurn.fromJson(Map<String, dynamic> json) => StoryTurn(
        id: json['id'] as String,
        story: json['story'] as String,
        choices: (json['choices'] as List<dynamic>)
            .map((v) => TurnChoice.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(growable: false),
        generatedElements: (json['generated_elements'] as List<dynamic>? ?? [])
            .map((v) => GeneratedWorldElement.fromJson(
                Map<String, dynamic>.from(v as Map)))
            .toList(growable: false),
      );
}
