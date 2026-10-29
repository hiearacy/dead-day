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
        turn.story.contains(RegExp(r'[\u0000-\u0009\u000b-\u001f]'))) {
      return 'invalid_story';
    }
    if (state.recentWorldTurns.any((old) => old.id == turn.id)) {
      return 'duplicate_turn';
    }
    if (turn.choices.length != 3 ||
        turn.choices.map((v) => v.id).toSet().length != 3) {
      return 'choices_must_be_three_unique';
    }
    if (turn.generatedElements.length > 4 ||
        state.generatedElements.length + turn.generatedElements.length > 500) {
      return 'too_many_world_elements';
    }
    final existing = state.generatedElements.map((v) => v.id).toSet();
    final proposed = <String>{};
    final existingNames = state.generatedElements
        .map((v) => v.name.trim().toLowerCase()).toSet();
    for (final element in turn.generatedElements) {
      if (!RegExp(r'^[a-z][a-z0-9_]{2,63}$').hasMatch(element.id) ||
          element.name.trim().isEmpty || element.name.length > 70 ||
          element.description.length > 300 || !element.discovered ||
          !existingNames.add(element.name.trim().toLowerCase()) ||
          element.origin != 'ai_generated' ||
          element.createdDay != state.currentDay ||
          existing.contains(element.id) || !proposed.add(element.id)) {
        return 'invalid_or_duplicate_element';
      }
      if (element.parentId == element.id) return 'cyclic_parent';
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
    final knownElements = <String, GeneratedWorldElement>{
      for (final v in [...state.generatedElements, ...turn.generatedElements])
        v.id: v,
    };
    final current = knownElements[state.currentLocationId];
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
          final destination = match.first;
          final adjacent = destination.parentId == state.currentLocationId ||
              current?.parentId == destination.id;
          if (!adjacent) return 'unreachable_destination';
        }
      } else if (choice.intent == StoryIntent.collect) {
        if (choice.targetId == null || !knownIds.contains(choice.targetId)) {
          return 'unknown_collect_target';
        }
        final match = [
          ...state.generatedElements, ...turn.generatedElements,
        ].where((v) => v.id == choice.targetId &&
            v.kind == WorldElementKind.item);
        if (match.isEmpty) return 'not_an_item';
        if (match.first.parentId != state.currentLocationId) {
          return 'item_not_here';
        }
        if (state.inventory.any((item) => item.elementId == choice.targetId)) {
          return 'item_already_owned';
        }
      } else if (choice.targetId != null && !knownIds.contains(choice.targetId)) {
        return 'unknown_target';
      }
    }
    return null;
  }
}
