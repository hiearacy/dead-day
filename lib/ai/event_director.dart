import '../game/models.dart';

/// Bounded mechanical archetypes, but the setup/premise is free-form.
/// New archetypes can be added without tying the narrative to one city.
enum DirectedEventType {
  hiddenSupplies,
  taintedWater,
  strangeBroadcast,
  strangerAtDoor,
  companionConflict,
  unsettlingEncounter,
}

class EventProposal {
  const EventProposal({
    required this.type,
    required this.premise,
    this.locationId,
    this.npcName,
  });

  final DirectedEventType type;
  /// A *setup*, not a factual outcome. Rules determine all effects.
  final String premise;
  final String? locationId;
  final String? npcName;
}

class DirectorContext {
  const DirectorContext({
    required this.day,
    required this.locationId,
    required this.locationLabel,
    required this.biome,
    required this.food,
    required this.water,
    required this.health,
    required this.noise,
    required this.recentEvents,
    this.npcName,
    this.npcTrust,
  });

  final int day;
  final String locationId;
  final String locationLabel;
  final String biome;
  final int food;
  final int water;
  final int health;
  final int noise;
  final String? npcName;
  final int? npcTrust;
  final List<String> recentEvents;

  factory DirectorContext.fromGame(GameState state) => DirectorContext(
        day: state.currentDay,
        locationId: state.world.id,
        locationLabel: state.world.label,
        biome: state.world.biome.name,
        food: state.food,
        water: state.water,
        health: state.health,
        noise: state.noise,
        npcName: state.companion?.name,
        npcTrust: state.companion?.trust,
        recentEvents: state.journal.reversed
            .take(3)
            .map((event) => event.id)
            .toList(growable: false),
      );

  String get compactPrompt => '''
역할: 오프라인 좀비 생존 게임의 이벤트 디렉터.
다음 월드 상태를 고려해 게임 사건의 '시작 상황' 하나만 제안한다.
지역: $locationLabel / 환경: $biome / 날짜: $day
체력: $health / 식량: $food / 물: $water / 소음: $noise
NPC: ${npcName ?? '없음'} / 신뢰: ${npcTrust ?? '없음'}
최근 사건 ID: ${recentEvents.join(', ')}
허용 타입: ${DirectedEventType.values.map((value) => value.name).join(', ')}
출력: 타입 하나, 170자 이내 사건 도입부. 결말이나 아이템 수치를 결정하지 않는다.
충격적이고 기묘한 사건도 가능하지만 인물의 인과관계와 세계 설정을 지켜라.
''';
}

/// Offline inference is an optional future adapter. No network/API required.
abstract class EventDirector {
  Future<EventProposal?> propose(DirectorContext context);
}

class NoEventDirector implements EventDirector {
  const NoEventDirector();
  @override
  Future<EventProposal?> propose(DirectorContext context) async => null;
}
