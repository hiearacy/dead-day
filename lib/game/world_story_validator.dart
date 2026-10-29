import 'generated_world_element.dart';
import 'models.dart';
import 'story_turn.dart';

/// Validate untrusted LLM output *before* committing any new world facts.
/// Mechanical validity is checkable; semantic contradictions in free text
/// remain a known limitation requiring subsequent guardrails/playtesting.
class WorldStoryValidator {
  const WorldStoryValidator();

  String? rejection(GameState state, StoryTurn turn) {
    if (state.gameOver || state.waitingForChoice || state.pendingWorldTurn != null) {
      return 'unavailable_game_phase';
    }
    if (turn.id.length < 3 || turn.id.length > 90 ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(turn.id)) {
      return 'invalid_turn_id';
    }
    if (turn.story.trim().length < 20 || turn.story.length > 1800 ||
        turn.story.contains(RegExp(r'[\u0000-\u001f]'))) {
      return 'invalid_story';
    }
    if (turn.choices.length != 3 ||
        turn.choices.map((v) => v.id).toSet().length != 3) {
      return 'choices_must_be_three_unique';
    }
    if (turn.generatedElements.length > 4 ||
        state.generatedElements.length + turn.generatedElements.length > 50) {
      return 'too_many_world_elements';
    }
    final existing = state.generatedElements.map((v) => v.id).toSet();
    final proposed = <String>{};
    for (final element in turn.generatedElements) {
      if (!RegExp(r'^[a-z][a-z0-9_]{2,63}$').hasMatch(element.id) ||
          element.name.trim().isEmpty || element.name.length > 70 ||
          element.description.length > 300 ||
          element.origin != 'ai_generated' ||
          element.createdDay != state.currentDay ||
          existing.contains(element.id) || !proposed.add(element.id)) {
        return 'invalid_or_duplicate_element';
      }
      if (element.parentId != null &&
          element.parentId != state.currentLocationId &&
          !existing.contains(element.parentId) &&
          !proposed.contains(element.parentId)) {
        return 'unresolved_parent';
      }
    }
    final knownIds = <String>{
      state.currentLocationId,
      ...existing,
      ...proposed,
    };
    for (final choice in turn.choices) {
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,50}$').hasMatch(choice.id) ||
          choice.text.trim().length < 3 || choice.text.length > 120 ||
          choice.text.contains(RegExp(r'[\u0000-\u001f]'))) {
        return 'invalid_choice';
      }
      if (choice.intent == StoryIntent.move) {
        if (choice.targetId == null || !knownIds.contains(choice.targetId)) {
          return 'unknown_destination';
        }
        if (choice.targetId != state.currentLocationId) {
          final match = [
            ...state.generatedElements, ...turn.generatedElements,
          ].where((element) => element.id == choice.targetId &&
              element.kind == WorldElementKind.location);
          if (match.isEmpty) return 'not_a_location';
        }
      } else if (choice.targetId != null && !knownIds.contains(choice.targetId)) {
        return 'unknown_target';
      }
    }
    return null;
  }
}
