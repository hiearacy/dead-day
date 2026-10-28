import 'dart:math';
import 'event_director.dart';

/// Tiny on-device procedural fallback: no network, model, RAM spikes or heat.
/// Uses world + needs + optional companion; model adapter can replace this.
class ProceduralEventDirector implements EventDirector {
  ProceduralEventDirector({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const _omens = [
    '바깥이 잠잠해진 순간',
    '발전기 소리가 끊긴 직후',
    '창문 아래서 작은 소리가 들리더니',
    '날이 완전히 어두워지자',
    '먼 곳에서 무언가 쓰러지는 소리와 함께',
  ];

  static const _objects = [
    '봉인된 상자',
    '낡은 지도',
    '정체불명의 배낭',
    '젖어 있는 쪽지',
    '녹슨 자물쇠',
  ];

  @override
  Future<EventProposal?> propose(DirectorContext context) async {
    final types = <DirectedEventType>[
      DirectedEventType.hiddenSupplies,
      DirectedEventType.strangeBroadcast,
      DirectedEventType.strangerAtDoor,
      if (context.water > 0) DirectedEventType.taintedWater,
      if (context.npcName != null) DirectedEventType.companionConflict,
    ];

    // Exceptionally rare branch. The engine applies its own final rarity roll.
    if (_random.nextInt(300) == 0) {
      types.add(DirectedEventType.unsettlingEncounter);
    }
    final type = types[_random.nextInt(types.length)];
    final omens = _omens[_random.nextInt(_omens.length)];
    final object = _objects[_random.nextInt(_objects.length)];
    final environment = context.locationLabel;

    final premise = switch (type) {
      DirectedEventType.hiddenSupplies =>
        '$environment, $omens 구석에서 $object이(가) 발견됐다.',
      DirectedEventType.taintedWater =>
        '$environment의 거점에서 보관한 식수에서 이상한 냄새가 난다.',
      DirectedEventType.strangeBroadcast =>
        '$environment, $omens 끊어진 라디오에서 짧은 신호가 들린다.',
      DirectedEventType.strangerAtDoor =>
        '$environment의 거점 문 밖에서 누군가 세 차례 노크한다.',
      DirectedEventType.companionConflict =>
        '$omens ${context.npcName}이(가) 물자 분배에 불만을 드러낸다.',
      DirectedEventType.unsettlingEncounter =>
        '$environment, 문을 잠근 뒤에도 집 안쪽에서 정체 모를 발소리가 들린다.',
    };

    return EventProposal(
      type: type,
      premise: premise,
      locationId: context.locationId,
      npcName: type == DirectedEventType.companionConflict
          ? context.npcName
          : null,
    );
  }
}
