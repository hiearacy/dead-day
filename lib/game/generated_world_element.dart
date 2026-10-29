/// AI-proposed facts that have been accepted into the authoritative world.
/// A proposal never grants inventory or teleports the player.
enum WorldElementKind { location, character, item, clue, event }

class GeneratedWorldElement {
  const GeneratedWorldElement({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.parentId,
    required this.createdDay,
    this.discovered = true,
    this.origin = 'ai_generated',
  });

  final String id;
  final String name;
  final WorldElementKind kind;
  final String description;
  final String? parentId;
  final int createdDay;
  final bool discovered;
  final String origin;

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'kind': kind.name,
        'description': description, 'parentId': parentId,
        'createdDay': createdDay, 'discovered': discovered, 'origin': origin,
      };

  factory GeneratedWorldElement.fromJson(Map<String, dynamic> json) =>
      GeneratedWorldElement(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: WorldElementKind.values.firstWhere(
          (v) => v.name == json['kind'],
          orElse: () => WorldElementKind.clue,
        ),
        description: json['description'] as String? ?? '',
        parentId: json['parentId'] as String?,
        createdDay: (json['createdDay'] as num?)?.toInt() ?? 1,
        discovered: json['discovered'] != false,
        origin: json['origin'] as String? ?? 'ai_generated',
      );
}
