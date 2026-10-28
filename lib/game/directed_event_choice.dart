/// A proposed incident stays unresolved until the player responds.
///
/// This is plain serializable data, independent of the actual AI provider and
/// independent of Flutter. The engine owns all choice consequences.
class DirectedChoice {
  const DirectedChoice({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
      };

  factory DirectedChoice.fromJson(Map<String, dynamic> json) => DirectedChoice(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class PendingDirectedEvent {
  const PendingDirectedEvent({
    required this.id,
    required this.typeName,
    required this.premise,
    required this.locationId,
    required this.createdDay,
    required this.choices,
    this.npcName,
  });

  final String id;
  final String typeName;
  final String premise;
  final String locationId;
  final String? npcName;
  final int createdDay;
  final List<DirectedChoice> choices;

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeName': typeName,
        'premise': premise,
        'locationId': locationId,
        'npcName': npcName,
        'createdDay': createdDay,
        'choices': choices.map((choice) => choice.toJson()).toList(),
      };

  factory PendingDirectedEvent.fromJson(Map<String, dynamic> json) =>
      PendingDirectedEvent(
        id: json['id'] as String? ?? '',
        typeName: json['typeName'] as String? ?? '',
        premise: json['premise'] as String? ?? '',
        locationId: json['locationId'] as String? ?? '',
        npcName: json['npcName'] as String?,
        createdDay: (json['createdDay'] as num?)?.toInt() ?? 1,
        choices: (json['choices'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((entry) =>
                    DirectedChoice.fromJson(Map<String, dynamic>.from(entry)))
                .toList(growable: false) ??
            const <DirectedChoice>[],
      );
}
