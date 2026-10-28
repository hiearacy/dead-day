import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/event_director.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/scenario_definition.dart';
import 'package:dead_day/game/story_memory.dart';
import 'package:dead_day/game/world_profile.dart';

class PredictableRandom implements Random {
  const PredictableRandom();
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0.99;
}

void main() {
  test('scenarios constrain setting, while default remains four-region', () {
    final broadcast = GameState.newRun(
      scenarioId: 'lost_signal', random: const PredictableRandom(),
    );
    final coast = GameState.newRun(
      scenarioId: 'silent_coast', random: const PredictableRandom(),
    );
    expect(broadcast.scenario.title, '마지막 송신');
    expect(broadcast.world.id, 'seoul');
    expect(coast.scenario.id, 'silent_coast');
    expect(coast.world.id, 'busan');
    expect(broadcast.messages.first.text, contains('구조 신호'));
    expect(ScenarioCatalog.openSurvival.worldIds.length, 4);
  });

  test('v3 save migrates to v4 with world, chat, legacy stats', () {
    final oldState = GameState(
      world: WorldProfile.jeju, daysSurvived: 17, food: 2,
    );
    final json = oldState.toJson()
      ..['saveVersion'] = 3
      ..remove('scenarioId')
      ..remove('storyThreads')
      ..remove('storyMemories')
      ..remove('pendingStory');
    final state = GameState.fromJson(json);
    expect(state.world.id, 'jeju');
    expect(state.food, 2);
    expect(state.daysSurvived, 17);
    expect(state.scenario.id, 'open_survival');
    expect(state.pendingStory, isNull);
  });

  test('first choice is remembered and changes a later scene', () {
    final state = GameState(
      world: WorldProfile.seoul,
      scenario: ScenarioCatalog.lostSignal,
      daysSurvived: 2,
      npcMet: true,
      food: 90, water: 90,
    );
    final engine = GameEngine(
      initialState: state, random: const PredictableRandom(),
    );

    engine.execute(const GameAction.rest()); // Day 3 starts first story.
    expect(state.daysSurvived, 3);
    expect(state.pendingStory?.id, 'radio_signal_open');
    expect(state.pendingStory!.choices.length, 2);

    final invalid = engine.execute(GameAction.chooseStory('unknown_choice'));
    expect(invalid.accepted, isFalse);
    expect(state.storyMemories, isEmpty);
    expect(state.pendingStory?.id, 'radio_signal_open');

    final choice = engine.execute(GameAction.chooseStory('trace'));
    expect(choice.accepted, isTrue);
    expect(state.water, 88); // 90 - 1 daily ration - 1 tracing cost.
    expect(state.storyMemories.single.tags, contains('trace'));
    expect(state.storyThreads.single.decision, 'trace');
    expect(state.pendingStory, isNull);

    for (var i = 0; i < 3; i++) {
      engine.execute(const GameAction.rest()); // Day 6 follows up.
    }
    expect(state.daysSurvived, 6);
    expect(state.pendingStory?.id, 'radio_signal_followup');
    expect(state.pendingStory!.premise, contains('주파수'));
    final resolve = engine.execute(GameAction.chooseStory('share'));
    expect(resolve.accepted, isTrue);
    expect(state.storyMemories.length, 2);
    expect(state.storyThreads.single.closed, isTrue);
  });

  test('story choice with missing supplies is rejected without mutation', () {
    final state = GameState(
      daysSurvived: 2, food: 0, water: 0, npcMet: true,
    );
    // Create a pending beat through the engine with enough health to survive.
    state.health = 100;
    final engine = GameEngine(
      initialState: state, random: const PredictableRandom(),
    );
    engine.execute(const GameAction.rest()); // Day 3: lacks supplies, HP 75
    expect(state.pendingStory, isNotNull);
    final previous = state.toJson().toString();
    final rejected = engine.execute(GameAction.chooseStory('trace'));
    expect(rejected.code, 'invalid_story_choice');
    expect(state.toJson().toString(), previous);
    expect(state.daysSurvived, 3);
    final valid = engine.execute(GameAction.chooseStory('ignore'));
    expect(valid.accepted, isTrue);
  });

  test('pending story and causal memory survive restart serialization', () {
    final state = GameState(
      daysSurvived: 2, npcMet: true, food: 20, water: 20,
    );
    final engine = GameEngine(
      initialState: state, random: const PredictableRandom(),
    );
    engine.execute(const GameAction.rest());
    final loadedPending = GameState.fromJson(state.toJson());
    expect(loadedPending.pendingStory?.id, 'radio_signal_open');
    final second = GameEngine(initialState: loadedPending);
    second.execute(GameAction.chooseStory('ignore'));
    final loadedMemory = GameState.fromJson(loadedPending.toJson());
    expect(loadedMemory.storyMemories.single.key, 'radio_signal_open_ignore');
    expect(loadedMemory.storyThreads.single.decision, 'ignore');
  });

  test('AI director receives scenario truth and limited key memories', () {
    final state = GameState(
      scenario: ScenarioCatalog.lostSignal, daysSurvived: 8,
    );
    for (var index = 0; index < 20; index++) {
      state.rememberStory(StoryMemory(
        key: 'memory_$index', day: index, threadId: 'radio',
        summary: '기억 $index', tags: const ['radio'],
      ));
    }
    final context = DirectorContext.fromGame(state);
    expect(context.scenarioTitle, '마지막 송신');
    expect(context.storyMemories.length, 4);
    expect(context.storyMemories.first, '기억 19');
    expect(context.compactPrompt, contains('이전 선택의 중요 결과'));
  });
}
