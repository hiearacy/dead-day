/// Small *curated* memory, not a full chat transcript. Old chat lines can be
/// dropped without losing causality in the active story threads.
class StoryMemory {
  const StoryMemory({
    required this.key,
    required this.day,
    required this.summary,
    required this.threadId,
    required this.tags,
  });

  final String key;
  final int day;
  final String summary;
  final String threadId;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'key': key,
        'day': day,
        'summary': summary,
        'threadId': threadId,
        'tags': tags,
      };

  factory StoryMemory.fromJson(Map<String, dynamic> json) => StoryMemory(
        key: json['key'] as String? ?? 'unknown',
        day: (json['day'] as num?)?.toInt() ?? 1,
        summary: json['summary'] as String? ?? '',
        threadId: json['threadId'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [],
      );
}

/// One continuing storyline is deliberately small: seed -> consequence -> end.
/// Future scenarios can have more steps, but v0.4 avoids infinite thread state.
class StoryThread {
  StoryThread({
    required this.id,
    required this.seedId,
    this.stage = 0,
    this.lastBeatDay = 0,
    this.decision = '',
    this.closed = false,
  });

  final String id;
  final String seedId;
  int stage;
  int lastBeatDay;
  String decision;
  bool closed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'seedId': seedId,
        'stage': stage,
        'lastBeatDay': lastBeatDay,
        'decision': decision,
        'closed': closed,
      };

  factory StoryThread.fromJson(Map<String, dynamic> json) => StoryThread(
        id: json['id'] as String? ?? 'unknown',
        seedId: json['seedId'] as String? ?? 'radio_signal',
        stage: (json['stage'] as num?)?.toInt() ?? 0,
        lastBeatDay: (json['lastBeatDay'] as num?)?.toInt() ?? 0,
        decision: json['decision'] as String? ?? '',
        closed: json['closed'] == true,
      );
}

class StoryChoice {
  const StoryChoice({
    required this.id,
    required this.label,
    required this.outcome,
    this.foodDelta = 0,
    this.waterDelta = 0,
    this.medicineDelta = 0,
    this.healthDelta = 0,
    this.trustDelta = 0,
  });

  final String id;
  final String label;
  final String outcome;
  final int foodDelta;
  final int waterDelta;
  final int medicineDelta;
  final int healthDelta;
  final int trustDelta;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'outcome': outcome,
        'foodDelta': foodDelta,
        'waterDelta': waterDelta,
        'medicineDelta': medicineDelta,
        'healthDelta': healthDelta,
        'trustDelta': trustDelta,
      };

  factory StoryChoice.fromJson(Map<String, dynamic> json) => StoryChoice(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        outcome: json['outcome'] as String? ?? '',
        foodDelta: (json['foodDelta'] as num?)?.toInt() ?? 0,
        waterDelta: (json['waterDelta'] as num?)?.toInt() ?? 0,
        medicineDelta: (json['medicineDelta'] as num?)?.toInt() ?? 0,
        healthDelta: (json['healthDelta'] as num?)?.toInt() ?? 0,
        trustDelta: (json['trustDelta'] as num?)?.toInt() ?? 0,
      );
}

class StoryBeat {
  const StoryBeat({
    required this.id,
    required this.threadId,
    required this.premise,
    required this.choices,
    required this.createdDay,
  });

  final String id;
  final String threadId;
  final String premise;
  final List<StoryChoice> choices;
  final int createdDay;

  Map<String, dynamic> toJson() => {
        'id': id,
        'threadId': threadId,
        'premise': premise,
        'choices': choices.map((choice) => choice.toJson()).toList(),
        'createdDay': createdDay,
      };

  factory StoryBeat.fromJson(Map<String, dynamic> json) => StoryBeat(
        id: json['id'] as String? ?? 'unknown',
        threadId: json['threadId'] as String? ?? '',
        premise: json['premise'] as String? ?? '',
        choices: (json['choices'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((item) => StoryChoice.fromJson(Map<String, dynamic>.from(item)))
                .toList() ??
            const [],
        createdDay: (json['createdDay'] as num?)?.toInt() ?? 1,
      );
}
