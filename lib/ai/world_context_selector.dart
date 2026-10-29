import '../game/generated_world_element.dart';
import '../game/models.dart';

/// Select world facts by relevance, not only by creation timestamp.
///
/// Earlier important places must remain visible to the AI even after newer
/// locations are invented. This is a pure read-only projection of GameState.
class WorldContextSelector {
  const WorldContextSelector();

  List<GeneratedWorldElement> select(GameState state, {int limit = 12}) {
    if (limit <= 0) return const <GeneratedWorldElement>[];
    final byId = <String, GeneratedWorldElement>{
      for (final element in state.generatedElements) element.id: element,
    };
    final selected = <String, GeneratedWorldElement>{};

    void add(GeneratedWorldElement? element) {
      if (element == null || selected.length >= limit) return;
      selected.putIfAbsent(element.id, () => element);
    }

    void includeAncestors(String? id) {
      final visited = <String>{};
      var cursor = id;
      while (cursor != null && visited.add(cursor) && selected.length < limit) {
        final element = byId[cursor];
        if (element == null) break;
        add(element);
        cursor = element.parentId;
      }
    }

    // Current location, then its parent chain. Preserve older discoveries.
    includeAncestors(state.currentLocationId);

    // Nearby places and clues usually matter more than globally recent ones.
    for (final element in state.generatedElements.reversed) {
      if (element.parentId == state.currentLocationId) add(element);
      if (selected.length >= limit) break;
    }

    // Owned item facts should accompany inventory identifiers.
    for (final item in state.inventory.reversed.take(5)) {
      includeAncestors(item.elementId);
    }

    // Important past decisions can point to otherwise-old locations.
    for (final memory in state.storyMemories.reversed.take(8)) {
      for (final id in memory.tags) {
        includeAncestors(id);
      }
    }

    // Fill remaining space with new facts for novelty.
    for (final element in state.generatedElements.reversed) {
      add(element);
      if (selected.length >= limit) break;
    }
    return List<GeneratedWorldElement>.unmodifiable(selected.values);
  }
}
