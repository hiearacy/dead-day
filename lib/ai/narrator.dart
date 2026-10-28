import '../game/models.dart';

/// Optional local-model integration boundary.
/// AI can only return flavor text; it cannot update the game state.
abstract class AiNarrator {
  Future<String?> narrate(AiScene scene);
}

class AiScene {
  const AiScene({
    required this.day,
    required this.place,
    required this.outcome,
    this.npcName,
    this.npcTrust,
  });

  final int day;
  final String place;
  final String outcome;
  final String? npcName;
  final int? npcTrust;

  factory AiScene.fromGame(GameState state) => AiScene(
    day: state.currentDay,
    place: state.encounter?.zone.label ?? '거점',
    outcome: state.log,
    npcName: state.companion?.name,
    npcTrust: state.companion?.trust,
  );

  String get compactPrompt => '''
너는 모바일 좀비 생존 게임의 한국어 내레이터다.
이미 확정된 사건의 사실을 바꾸지 마라.
사망, 자원, 전투 결과, 관계 수치를 변경하지 마라.
2문장 이내로 상황이나 감정을 묘사하라.
현재 날짜: $day
장소: $place
NPC: $npcName / 신뢰도: $npcTrust
확정 사건: $outcome
''';
}

/// Base game has no model download, background inference, or heating cost.
class NoAiNarrator implements AiNarrator {
  const NoAiNarrator();
  @override
  Future<String?> narrate(AiScene scene) async => null;
}
