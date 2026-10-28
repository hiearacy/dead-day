import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/models.dart';

void main() {
  test('rest consumes one day and one food/water without NPC', () {
    final engine = GameEngine(random: Random(1));
    engine.rest();
    expect(engine.state.daysSurvived, 1);
    expect(engine.state.food, 4);
    expect(engine.state.water, 4);
    expect(engine.state.bestDays, 1);
  });

  test('medicine does not advance day', () {
    final engine = GameEngine(initialState: GameState(health: 30, medicine: 1));
    engine.useMedicine();
    expect(engine.state.health, 60);
    expect(engine.state.medicine, 0);
    expect(engine.state.daysSurvived, 0);
  });

  test('starvation can cause game over', () {
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
      encounter: const Encounter(zone: Zone.pharmacy, zombies: 2),
      companion: Companion(name: '서윤', trust: 14),
    );
    final restored = GameState.fromJson(original.toJson());
    expect(restored.daysSurvived, 5);
    expect(restored.encounter!.zone, Zone.pharmacy);
    expect(restored.encounter!.zombies, 2);
    expect(restored.companion!.trust, 14);
  });

  test('companion consumes another ration per day', () {
    final engine = GameEngine(
      initialState: GameState(companion: Companion(name: '서윤')),
      random: Random(2),
    );
    engine.rest();
    expect(engine.state.food, 3);
    expect(engine.state.water, 3);
  });
}
