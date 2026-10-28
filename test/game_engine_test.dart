import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/game/event_record.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/models.dart';

class ScriptedRandom implements Random {
  ScriptedRandom([this.doubles = const [0.99]]);
  final List<double> doubles;
  int _index = 0;

  @override
  double nextDouble() {
    final index = _index++;
    return index < doubles.length ? doubles[index] : 0.99;
  }

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => true;
}

void main() {
  test('rest consumes one day and one food/water without NPC', () {
    final engine = GameEngine(random: ScriptedRandom());
    engine.rest();
    expect(engine.state.daysSurvived, 1);
    expect(engine.state.food, 4);
    expect(engine.state.water, 4);
    expect(engine.state.bestDays, 1);
  });

  test('medicine does not advance day', () {
    final engine = GameEngine(initialState: GameState(health: 30, medicine: 1));
    final result = engine.execute(const GameAction.useMedicine());
    expect(result.accepted, isTrue);
    expect(engine.state.health, 60);
    expect(engine.state.medicine, 0);
    expect(engine.state.daysSurvived, 0);
    expect(engine.state.journal.last.id, 'medicine_used');
  });

  test('starvation can cause game over without crediting unfinished day', () {
    final engine = GameEngine(
      initialState: GameState(health: 1, food: 0, water: 0),
    );
    engine.rest();
    expect(engine.state.gameOver, isTrue);
    expect(engine.state.health, 0);
    expect(engine.state.daysSurvived, 0);
  });

  test('unresolved encounter and NPC round-trip through JSON', () {
    final original = GameState(
      daysSurvived: 5,
      noise: 40,
      encounter: const Encounter(zone: Zone.pharmacy, zombies: 2),
      companion: Companion(name: '서윤', trust: 14)
        ..remember('오늘 물이 부족했다.'),
    );
    original.record(const GameEventRecord(
      id: 'encounter',
      day: 6,
      kind: EventKind.combat,
      text: '좀비 발견',
    ));
    final restored = GameState.fromJson(original.toJson());
    expect(restored.daysSurvived, 5);
    expect(restored.encounter!.zone, Zone.pharmacy);
    expect(restored.encounter!.zombies, 2);
    expect(restored.companion!.trust, 14);
    expect(restored.companion!.memories, hasLength(1));
    expect(restored.noise, 40);
    expect(restored.journal.single.id, 'encounter');
  });

  test('migrate previous save v1 without losing player progress', () {
    final oldSave = GameState(daysSurvived: 18, bestDays: 22).toJson()
      ..['saveVersion'] = 1
      ..remove('journal')
      ..remove('noise');
    final restored = GameState.fromJson(oldSave);
    expect(restored.daysSurvived, 18);
    expect(restored.bestDays, 22);
    expect(restored.noise, 0);
    expect(restored.journal, isEmpty);
  });

  test('companion consumes another ration per day', () {
    final engine = GameEngine(
      initialState: GameState(companion: Companion(name: '서윤')),
      random: ScriptedRandom(),
    );
    engine.rest();
    expect(engine.state.food, 3);
    expect(engine.state.water, 3);
  });

  test('pending zombie encounter can only be resolved once', () {
    final engine = GameEngine(random: ScriptedRandom([0.0, 0.0, 0.99]));
    final start = engine.execute(GameAction.explore(Zone.market));
    expect(start.accepted, isTrue);
    expect(engine.state.encounter, isNotNull);
    expect(engine.state.daysSurvived, 0);

    final waiting = engine.execute(const GameAction.rest());
    expect(waiting.accepted, isFalse);
    expect(waiting.code, 'pending_decision');

    final done = engine.execute(GameAction.resolve(EncounterAction.flee));
    expect(done.accepted, isTrue);
    expect(engine.state.encounter, isNull);
    expect(engine.state.daysSurvived, 1);

    final repeated = engine.execute(GameAction.resolve(EncounterAction.flee));
    expect(repeated.accepted, isFalse);
    expect(engine.state.daysSurvived, 1);
  });

  test('noise increases encounter risk without changing zone definitions', () {
    final lowNoise = GameEngine(
      initialState: GameState(daysSurvived: 8, npcMet: true),
      random: ScriptedRandom([0.65]),
    );
    final highNoise = GameEngine(
      initialState: GameState(daysSurvived: 8, noise: 100, npcMet: true),
      random: ScriptedRandom([0.65]),
    );
    lowNoise.explore(Zone.market);
    highNoise.explore(Zone.market);
    expect(lowNoise.state.encounter, isNull);
    expect(highNoise.state.encounter, isNotNull);
  });

  test('scarcity with low trust can cause companion to leave', () {
    final engine = GameEngine(
      initialState: GameState(
        food: 0,
        water: 0,
        medicine: 1,
        companion: Companion(name: '서윤', trust: 35),
        npcMet: true,
      ),
      random: ScriptedRandom([0.0]),
    );
    engine.rest();
    expect(engine.state.companion, isNull);
    expect(engine.state.medicine, 0);
    expect(engine.state.journal.map((e) => e.id), contains('companion_departed'));
  });

  test('night events obey the event catalogue and report structured id', () {
    final engine = GameEngine(
      initialState: GameState(npcMet: true),
      random: ScriptedRandom([0.0]),
    );
    final result = engine.execute(const GameAction.rest());
    expect(result.events.map((event) => event.id), contains('forgotten_supplies'));
    expect(engine.state.food, 5); // 5 initial - 1 daily + 1 night event.
    expect(engine.state.daysSurvived, 1);
  });

  test('event journal is bounded on very long runs', () {
    final state = GameState();
    for (var i = 0; i < 40; i++) {
      state.record(GameEventRecord(
        id: 'event_$i',
        day: i + 1,
        kind: EventKind.system,
        text: '이벤트',
      ));
    }
    expect(state.journal.length, GameState.maxJournalEntries);
    expect(state.journal.first.id, 'event_16');
    expect(state.journal.last.id, 'event_39');
  });
}
