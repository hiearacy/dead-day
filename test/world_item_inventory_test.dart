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

void main() {
  test('AI-declared item is not owned until a validated collect choice', () {
    final state = GameState.newRun(random: const QuietRandom());
    final engine = GameEngine(initialState: state, random: const QuietRandom());
    final turn = StoryTurn(
      id: 'test_item_turn',
      story: '바닥에 오래된 지도 한 장이 펼쳐져 있다. '
          '지도에는 알 수 없는 지하 시설이 표시되어 있다. '
          '하지만 주변에 발소리가 들려오고 있다.',
      choices: const [
        TurnChoice(id: 'take', text: '지도를 주워 챙긴다',
            intent: StoryIntent.collect, targetId: 'item_map'),
        TurnChoice(id: 'inspect', text: '지도 내용만 확인한다',
            intent: StoryIntent.investigate),
        TurnChoice(id: 'leave', text: '지도는 그대로 두고 물러난다',
            intent: StoryIntent.observe),
      ],
      generatedElements: [
        GeneratedWorldElement(
          id: 'item_map', name: '지하 시설 지도',
          kind: WorldElementKind.item,
          description: '지하 시설의 구조 일부가 기록된 지도.',
          parentId: state.currentLocationId, createdDay: state.currentDay,
        ),
      ],
    );
    expect(engine.acceptWorldTurn(turn).accepted, isTrue);
    expect(state.worldState.find('item_map')?.kind, WorldElementKind.item);
    expect(state.inventory, isEmpty);
    final save = GameState.fromJson(state.toJson());
    expect(save.inventory, isEmpty);
    final resumed = GameEngine(initialState: save, random: const QuietRandom());
    expect(resumed.execute(GameAction.chooseWorldTurn('take')).accepted, isTrue);
    expect(save.inventory.single.elementId, 'item_map');
    expect(save.inventory.single.quantity, 1);
    expect(save.daysSurvived, 1);
    expect(GameState.fromJson(save.toJson()).inventory.single.elementId,
        'item_map');
  });

  test('AI cannot cause inventory of nonexistent item via fabricated target', () {
    final state = GameState.newRun(random: const QuietRandom());
    final turn = StoryTurn(
      id: 'invalid_collect',
      story: '무너진 터널 입구에서 가방을 발견했다. '
          '가방 내부가 비어 있는지 아직 알 수 없다.',
      choices: const [
        TurnChoice(id: 'take', text: '없는 아이템을 획득한다',
            intent: StoryIntent.collect, targetId: 'not_real'),
        TurnChoice(id: 'look', text: '주변을 살핀다',
            intent: StoryIntent.investigate),
        TurnChoice(id: 'wait', text: '조용히 기다린다',
            intent: StoryIntent.observe),
      ],
      generatedElements: const [],
    );
    final previous = state.toJson().toString();
    final result = GameEngine(initialState: state).acceptWorldTurn(turn);
    expect(result.code, 'unknown_collect_target');
    expect(state.toJson().toString(), previous);
  });

  test('context distinguishes discovered items from owned inventory', () {
    final state = GameState.newRun(random: const QuietRandom());
    state.generatedElements.add(GeneratedWorldElement(
      id: 'item_lantern', name: '손전등',
      kind: WorldElementKind.item, description: '배터리가 약한 손전등',
      parentId: state.currentLocationId, createdDay: 1,
    ));
    final data = StoryContext.fromGame(state).data;
    expect(data['generated_elements'], isNotEmpty);
    expect(data['inventory'], isEmpty);
    expect((data['scenario'] as Map)['items'], isNotEmpty);
  });
}
