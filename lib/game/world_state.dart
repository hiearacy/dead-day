import 'generated_world_element.dart';

/// Read-only projection of the world, separate from player survival stats.
/// The owning GameState serializes this data and only GameEngine mutates it.
class WorldState {
  const WorldState({
    required this.currentLocationId,
    required this.elements,
  });

  final String currentLocationId;
  final List<GeneratedWorldElement> elements;

  GeneratedWorldElement? find(String id) {
    for (final value in elements) {
      if (value.id == id) return value;
    }
    return null;
  }
}
