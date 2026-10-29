import 'generated_world_element.dart';

/// Invented people exist in the world before they become active companions.
class WorldCharacter {
  const WorldCharacter(this.id, this.name, this.description);
  final String id;
  final String name;
  final String description;

  factory WorldCharacter.fromElement(GeneratedWorldElement e) =>
      WorldCharacter(e.id, e.name, e.description);
}
