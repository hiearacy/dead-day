import 'generated_world_element.dart';

class WorldLocation {
  const WorldLocation(this.id, this.name, this.description, this.discovered);
  final String id;
  final String name;
  final String description;
  final bool discovered;

  factory WorldLocation.fromElement(GeneratedWorldElement e) =>
      WorldLocation(e.id, e.name, e.description, e.discovered);
}
