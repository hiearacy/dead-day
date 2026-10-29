import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/generated_world_element.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/story_turn.dart';
import 'package:dead_day/ai/world_story_provider.dart';

class QuietRandom implements Random {
  const QuietRandom();
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => true;
}

StoryTurn locationTurn(GameState state, {String? targetId}) {
  final locationId = targetId ?? 'location_b3';
  return StoryTurn(
    id: 'turn_${state.currentDay}_${state.generatedElements.length}',
    story: '서울역 통로의 끝에서 불빛이 보인다. 잠겨 있던 문 옆에는 '
        'B3 구역으로 내려가는 계단이 있다. 어떻게 행동할까?',
    choices: [
      TurnChoice(id: 'choice_1', text: 'B3 구역으로 내려간다',
          intent: StoryIntent.move, targetId: locationId),
      const TurnChoice(id: 'choice_2', text: '문 주변을 조사한다',
          intent: StoryIntent.investigate),
      const TurnChoice(id: 'choice_3', text: '안전한 거점에서 살펴본다',
          intent: StoryIntent.observe),
    ],
    generatedElements: [
      GeneratedWorldElement(
        id: locationId, name: '서울역 B3 구역',
        kind: WorldElementKind.location,
        description: '지하에 연결된 미지의 통로',
        parentId: state.currentLocationId,
        createdDay: state.currentDay,
      ),
    ],
  );
}

void main() {
  test('AI can propose a new B3 location without teleporting or adding inventory', () {
    final state = GameState.newRun(random: const QuietRandom(),
        scenarioId: 'lost_signal');
    final engine = GameEngine(initialState: state, random: const QuietRandom());
    final beforeLocation = state.currentLocationId;
    final beforeFood = state.food;
    final proposed = engine.acceptWorldTurn(locationTurn(state));
    expect(proposed.accepted, isTrue);
    expect(state.worldState.find('location_b3')?.discovered, isTrue);
    expect(state.worldState.find('location_b3')?.origin, 'ai_generated');
    expect(state.currentLocationId, beforeLocation);
    expect(state.food, beforeFood);
    expect(state.pendingWorldTurn?.choices.length, 3);

    final blocked = engine.execute(const GameAction.rest());
    expect(blocked.code, 'pending_decision');
    final unknown = engine.execute(GameAction.chooseWorldTurn('fake'));
    expect(unknown.accepted, isFalse);
    expect(state.pendingWorldTurn, isNotNull);

    final chosen = engine.execute(GameAction.chooseWorldTurn('choice_1'));
    expect(chosen.accepted, isTrue);
    expect(state.currentLocationId, 'location_b3');
    expect(state.daysSurvived, 1);
    expect(state.food, beforeFood - 1);
    expect(state.latestChoiceSummary, 'B3 구역으로 내려간다');
    expect(state.storyMemories.last.summary, contains('B3 구역'));
    expect(state.pendingWorldTurn, isNull);
    final repeat = engine.execute(GameAction.chooseWorldTurn('choice_1'));
    expect(repeat.accepted, isFalse);
  });

  test('duplicates and invalid destinations are rejected atomically', () {
    final state = GameState.newRun(random: const QuietRandom());
    final engine = GameEngine(initialState: state, random: const QuietRandom());
    final invalid = locationTurn(state, targetId: 'unknown_room');
    // The new element happens to have that ID too, which is a legitimate
    // new location; test an actually missing destination separately.
    final wrongMove = StoryTurn(
      id: 'invalid_move',
      story: invalid.story,
      generatedElements: const [],
      choices: invalid.choices,
    );
    final old = state.toJson().toString();
    expect(engine.acceptWorldTurn(wrongMove).code, 'unknown_destination');
    expect(state.toJson().toString(), old);
    final accepted = engine.acceptWorldTurn(locationTurn(state));
    expect(accepted.accepted, isTrue);
    engine.execute(GameAction.chooseWorldTurn('choice_2'));
    final past = state.generatedElements.length;
    final duplicate = locationTurn(state);
    expect(engine.acceptWorldTurn(duplicate).code, 'invalid_or_duplicate_element');
    expect(state.generatedElements.length, past);
  });

  test('pending turn, invented world, and memories roundtrip on restart', () {
    final initial = GameState.newRun(random: const QuietRandom());
    final original = GameEngine(
      initialState: initial, random: const QuietRandom(),
    );
    original.acceptWorldTurn(locationTurn(initial));
    final restored = GameState.fromJson(initial.toJson());
    expect(restored.pendingWorldTurn, isNotNull);
    expect(restored.generatedElements.single.id, 'location_b3');
    expect(restored.scenario.id, initial.scenario.id);
    final later = GameEngine(
      initialState: restored, random: const QuietRandom(),
    );
    later.execute(GameAction.chooseWorldTurn('choice_3'));
    final again = GameState.fromJson(restored.toJson());
    expect(again.pendingWorldTurn, isNull);
    expect(again.recentWorldTurns, hasLength(1));
    expect(again.storyMemories.single.tags, contains('observe'));
    expect(again.currentLocationId, startsWith('start_'));
  });

  test('fallback generator continues stories and remembers world history', () async {
    final state = GameState.newRun(random: const QuietRandom());
    state.food = 40;
    state.water = 40;
    state.npcMet = true;
    for (var i = 0; i < 6; i++) {
      final provider = ProceduralWorldStoryProvider(random: const QuietRandom());
      final context = StoryContext.fromGame(state);
      final turn = await provider.generate(context);
      final engine = GameEngine(initialState: state, random: const QuietRandom());
      expect(engine.acceptWorldTurn(turn).accepted, isTrue);
      expect(engine.execute(GameAction.chooseWorldTurn('move')).accepted, isTrue);
      final roundtrip = GameState.fromJson(state.toJson());
      expect(roundtrip.generatedElements.length, i + 1);
      expect(roundtrip.recentWorldTurns.length, lessThanOrEqualTo(4));
      expect(roundtrip.latestChoiceSummary, contains('이동'));
      // Continue with a serialized state, just like an app restart.
      state.currentLocationId = roundtrip.currentLocationId;
    }
    expect(state.daysSurvived, 6);
    expect(state.generatedElements.length, 6);
  });

  test('previous v5 saves load with no new world state and legacy behavior', () {
    final old = GameState(daysSurvived: 10, food: 3).toJson()
      ..['saveVersion'] = 5
      ..remove('generatedElements')
      ..remove('pendingWorldTurn')
      ..remove('recentWorldTurns')
      ..remove('interactiveMode')
      ..remove('currentLocationId');
    final loaded = GameState.fromJson(old);
    expect(loaded.daysSurvived, 10);
    expect(loaded.generatedElements, isEmpty);
    expect(loaded.interactiveMode, isFalse);
    expect(loaded.currentLocationId, startsWith('start_'));
  });

  test('remote locations cannot be selected as teleport destinations', () {
    final state = GameState.newRun(random: const QuietRandom());
    state.generatedElements.addAll([
      GeneratedWorldElement(
        id: 'location_branch_a', name: 'A 통로',
        kind: WorldElementKind.location,
        description: '현재 자리의 연결 통로',
        parentId: state.currentLocationId, createdDay: state.currentDay,
      ),
      GeneratedWorldElement(
        id: 'location_remote', name: '멀리 떨어진 구역',
        kind: WorldElementKind.location,
        description: 'A 통로 너머의 먼 구역',
        parentId: 'location_branch_a', createdDay: state.currentDay,
      ),
    ]);
    final before = state.toJson().toString();
    final remoteTurn = StoryTurn(
      id: 'invalid_teleport',
      story: '통로 너머 멀리 떨어진 구역의 불빛이 보인다. '
          '현재 위치에서 바로 건너갈 수는 없을 것 같다.',
      choices: const [
        TurnChoice(id: 'go', text: '먼 구역으로 순간이동한다',
            intent: StoryIntent.move, targetId: 'location_remote'),
        TurnChoice(id: 'look', text: '주변을 조사한다',
            intent: StoryIntent.investigate),
        TurnChoice(id: 'wait', text: '여기서 기다린다',
            intent: StoryIntent.observe),
      ],
      generatedElements: const [],
    );
    final result = GameEngine(initialState: state).acceptWorldTurn(remoteTurn);
    expect(result.code, 'unreachable_destination');
    expect(state.toJson().toString(), before);
  });
}
