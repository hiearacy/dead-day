import 'dart:math';
import 'event_record.dart';
import 'models.dart';

/// Engine-owned outcomes. One RNG input permits seeded or mocked tests.
class NightEventOutcome {
  const NightEventOutcome(this.id, this.kind, this.text);
  final String id;
  final EventKind kind;
  final String text;
}

/// Small data-driven event catalogue. No AI or Flutter dependencies.
class NightEventDefinition {
  const NightEventDefinition({
    required this.id,
    required this.text,
    required this.kind,
    required this.canRun,
    required this.apply,
    this.weight = 1,
    this.minDay = 1,
  });

  final String id;
  final String text;
  final EventKind kind;
  final bool Function(GameState) canRun;
  final void Function(GameState) apply;
  final int weight;
  final int minDay;
}

class NightEventSystem {
  const NightEventSystem();

  static final List<NightEventDefinition> catalogue = [
    NightEventDefinition(
      id: 'forgotten_supplies',
      text: '거점의 오래된 상자에서 식량 한 개를 발견했다.',
      kind: EventKind.resource,
      canRun: (_) => true,
      apply: (state) => state.food++,
      weight: 2,
    ),
    NightEventDefinition(
      id: 'rain_catch',
      text: '밤새 빗물을 받아 식수 한 개를 확보했다.',
      kind: EventKind.resource,
      canRun: (_) => true,
      apply: (state) => state.water++,
    ),
    NightEventDefinition(
      id: 'water_leak',
      text: '보관통이 새어 식수 한 개를 잃었다.',
      kind: EventKind.hazard,
      canRun: (state) => state.water > 0,
      apply: (state) => state.water--,
      minDay: 3,
    ),
    NightEventDefinition(
      id: 'distant_horde',
      text: '새벽에 몰려온 좀비 떼가 주변을 배회한다. 거점의 소음 위험이 커졌다.',
      kind: EventKind.hazard,
      canRun: (_) => true,
      apply: (state) => state.noise = min(100, state.noise + 18),
      minDay: 4,
    ),
    NightEventDefinition(
      id: 'quiet_night',
      text: '조용한 밤이었다. 주변의 좀비들이 조금씩 멀어졌다.',
      kind: EventKind.system,
      canRun: (state) => state.noise >= 12,
      apply: (state) => state.noise = max(0, state.noise - 12),
      minDay: 2,
    ),
  ];

  NightEventOutcome? maybeTrigger(GameState state, Random random) {
    // Nights are usually quiet; event frequency will be play-tested.
    if (random.nextDouble() >= 0.28) return null;
    final candidates = catalogue
        .where((event) => state.currentDay >= event.minDay && event.canRun(state))
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    final totalWeight = candidates.fold<int>(0, (sum, event) => sum + event.weight);
    var roll = random.nextInt(totalWeight);
    for (final event in candidates) {
      if (roll < event.weight) {
        event.apply(state);
        return NightEventOutcome(event.id, event.kind, event.text);
      }
      roll -= event.weight;
    }
    return null;
  }
}
