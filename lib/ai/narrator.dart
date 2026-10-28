import '../game/models.dart';

/// A future platform-specific local model only receives a *read-only* scene.
/// It cannot modify combat results, health, supplies or NPC state.
abstract class AiNarrator {
  Future<String?> narrate(AiScene scene);
}

class AiScene {
  const AiScene({
    required this.day,
    required this.place,
    required this.outcome,
    required this.recentEvents,
    required this.npcMemories,
    this.npcName,
    this.npcTrait,
    this.npcTrust,
  });

  final int day;
  final String place;
  final String outcome;
  final String? npcName;
  final String? npcTrait;
  final int? npcTrust;
  final List<String> recentEvents;
  final List<String> npcMemories;

  factory AiScene.fromGame(GameState state) => AiScene(
        day: state.currentDay,
        place: state.encounter?.zone.label ?? '거점',
        // Keep prompts small enough for inexpensive on-device models.
        outcome: _truncate(state.log, 300),
        npcName: state.companion?.name,
        npcTrait: state.companion?.trait.name,
        npcTrust: state.companion?.trust,
        recentEvents: state.journal.reversed
            .take(3)
            .map((record) => _truncate(record.text, 100))
            .toList(growable: false),
        npcMemories: state.companion?.memories.reversed
                .take(3)
                .map((memory) => _truncate(memory, 80))
                .toList(growable: false) ??
            const <String>[],
      );

  static String _truncate(String text, int limit) =>
      text.length > limit ? text.substring(0, limit) : text;

  String get compactPrompt => '''
너는 모바일 좀비 생존 게임의 한국어 내레이터다.
확정된 사건의 사실을 바꾸지 마라.
사망, 자원, 전투, NPC 관계 수치 등 게임 결과를 만들거나 수정하지 마라.
짧은 한국어 두 문장 이내로 인물의 감정과 상황만 묘사하라.
날짜: $day
장소: $place
NPC: ${npcName ?? '없음'}, 성격: ${npcTrait ?? '없음'}, 신뢰도: ${npcTrust ?? '없음'}
최근 사건: ${recentEvents.join(' | ')}
NPC의 기억: ${npcMemories.join(' | ')}
확정된 사건: $outcome
''';
}

/// No model is installed in v0.2. Android, iOS and Web share this fallback.
class NoAiNarrator implements AiNarrator {
  const NoAiNarrator();

  @override
  Future<String?> narrate(AiScene scene) async => null;
}
