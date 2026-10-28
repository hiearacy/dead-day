/// Stable event data that a future UI can render without parsing story text.
enum EventKind { exploration, combat, resource, companion, hazard, system }

class GameEventRecord {
  const GameEventRecord({
    required this.id,
    required this.day,
    required this.kind,
    required this.text,
  });

  final String id;
  final int day;
  final EventKind kind;
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'kind': kind.name,
        'text': text,
      };

  factory GameEventRecord.fromJson(Map<String, dynamic> json) {
    return GameEventRecord(
      id: json['id'] as String? ?? 'unknown',
      day: (json['day'] as num?)?.toInt() ?? 1,
      kind: EventKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => EventKind.system,
      ),
      text: json['text'] as String? ?? '',
    );
  }
}
