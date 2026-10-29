import 'generated_world_element.dart';
import 'character.dart';
import 'location.dart';

/// Read-only projection of the world, separate from player survival stats.
/// The owning GameState serializes this data and only GameEngine mutates it.
class WorldState {
  const WorldState({
    required this.currentLocationId,
    required this.elements,
  });

  final String currentLocationId;
  final List<GeneratedWorldElement> elements;

  List<WorldLocation> get locations => elements
      .where((e) => e.kind == WorldElementKind.location)
      .map(WorldLocation.fromElement).toList(growable: false);

  List<WorldCharacter> get characters => elements
      .where((e) => e.kind == WorldElementKind.character)
      .map(WorldCharacter.fromElement).toList(growable: false);

  GeneratedWorldElement? find(String id) {
    for (final value in elements) {
      if (value.id == id) return value;
    }
    return null;
  }
}
