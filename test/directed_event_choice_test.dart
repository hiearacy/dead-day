import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/event_director.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/directed_event_choice.dart';
import 'package:dead_day/game/world_profile.dart';

class AlwaysLucky implements Random {
  const AlwaysLucky();
  @override
  double nextDouble() => 0.0;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => true;
}

void main() {
  test('a Gemini premise cannot immediately award food or advance a day', () {
    final state = GameState(
      world: WorldProfile.busan,
      food: 3, water: 2, daysSurvived: 4, npcMet: true,
    );
    final engine = GameEngine(initialState: state);
    final offered = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.hiddenSupplies,
      premise: '컨테이너 뒤에서 테이프로 밀봉된 상자가 발견됐다.',
      locationId: 'busan',
    ));
    expect(offered.accepted, isTrue);
    expect(state.pendingDirectedEvent?.choices.length, 2);
    expect(state.food, 3);
    expect(state.water, 2);
    expect(state.daysSurvived, 4);
    expect(state.storyMemories, isEmpty);

    final blocked = engine.execute(const GameAction.rest());
    expect(blocked.code, 'pending_decision');

    final invalid = engine.execute(
      GameAction.chooseDirectedEvent('makeInfiniteFood'),
    );
    expect(invalid.accepted, isFalse);
    expect(invalid.code, 'invalid_directed_choice');
    expect(state.food, 3);

    final chosen = engine.execute(GameAction.chooseDirectedEvent('inspect'));
    expect(chosen.accepted, isTrue);
    expect(state.pendingDirectedEvent, isNull);
    expect(state.food, 4);
    expect(state.noise, 4);
    expect(state.storyMemories.single.tags, contains('inspect'));
    expect(state.messages.last.text, contains('식량 +1'));

    final repeated = engine.execute(GameAction.chooseDirectedEvent('inspect'));
    expect(repeated.code, 'no_directed_event');
    expect(state.food, 4);
    expect(state.daysSurvived, 4);
  });

  test('a pending event survives a save and can be finished after restart', () {
    final state = GameState(daysSurvived: 7, water: 2, medicine: 1);
    final engine = GameEngine(initialState: state);
    engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.taintedWater,
      premise: '보관 중이던 물통에서 이상한 냄새가 올라온다.',
    ));
    final restored = GameState.fromJson(state.toJson());
    expect(restored.pendingDirectedEvent, isNotNull);
    expect(restored.pendingDirectedEvent!.choices.map((c) => c.id),
        contains('purify'));
    final savedVersion = restored.toJson()['saveVersion'];
    expect(savedVersion, GameState.saveVersion);

    final resumed = GameEngine(initialState: restored);
    final selected = resumed.execute(GameAction.chooseDirectedEvent('purify'));
    expect(selected.accepted, isTrue);
    expect(restored.medicine, 0);
    expect(restored.water, 2);
    expect(restored.pendingDirectedEvent, isNull);
    expect(restored.storyMemories.single.tags, contains('purify'));
  });

  test('a visitor does not offer a food gift when supplies are empty', () {
    final state = GameState(daysSurvived: 7, food: 0);
    GameEngine(initialState: state).acceptDirectedEvent(
      const EventProposal(
        type: DirectedEventType.strangerAtDoor,
        premise: '문 밖에서 낯선 생존자가 끊임없이 도움을 요청한다.',
      ),
    );
    expect(state.pendingDirectedEvent!.choices.map((c) => c.id),
        ['refuse']);
  });

  test('the same day cannot produce another AI incident after resolution', () {
    final state = GameState(daysSurvived: 12, npcMet: true);
    final engine = GameEngine(initialState: state);
    engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.strangeBroadcast,
      premise: '잡음 속에서 낯선 목소리가 지명을 반복한다.',
    ));
    engine.execute(GameAction.chooseDirectedEvent('off'));
    final duplicate = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.hiddenSupplies,
      premise: '닫혀 있던 창고 문이 갑자기 열렸다.',
    ));
    expect(duplicate.code, 'event_already_generated');
    expect(state.storyMemories.length, 1);
  });

  test('companion trust changes only after an accepted choice', () {
    final state = GameState(
      daysSurvived: 9,
      companion: Companion(name: '서윤', trust: 30),
    );
    final engine = GameEngine(initialState: state);
    final proposal = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.companionConflict,
      premise: '서윤이 며칠 동안 쌓인 불만을 털어놓는다.',
      npcName: '서윤',
    ));
    expect(proposal.accepted, isTrue);
    expect(state.companion!.trust, 30);
    engine.execute(GameAction.chooseDirectedEvent('talk'));
    expect(state.companion!.trust, 35);
    expect(state.companion!.memories.last, contains('들어주었다'));
  });

  test('a legacy v4 save migrates without an unresolved director event', () {
    final old = GameState(daysSurvived: 19, food: 7).toJson()
      ..['saveVersion'] = 4
      ..remove('pendingDirectedEvent');
    final migrated = GameState.fromJson(old);
    expect(migrated.daysSurvived, 19);
    expect(migrated.food, 7);
    expect(migrated.pendingDirectedEvent, isNull);
  });

  test('event choices remain serializable without Flutter or an AI model', () {
    const pending = PendingDirectedEvent(
      id: 'director_hiddenSupplies_8',
      typeName: 'hiddenSupplies',
      premise: '오래된 상자에 이상한 문양이 새겨져 있다.',
      locationId: 'seoul',
      createdDay: 9,
      choices: [
        DirectedChoice(id: 'inspect', label: '살펴본다'),
        DirectedChoice(id: 'leave', label: '지나간다'),
      ],
    );
    final serialized = pending.toJson();
    final copy = PendingDirectedEvent.fromJson(serialized);
    expect(copy.typeName, 'hiddenSupplies');
    expect(copy.choices.last.id, 'leave');
    expect(copy.createdDay, 9);
  });
}
