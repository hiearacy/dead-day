import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/event_director.dart';
import 'package:dead_day/game/chat_message.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/world_profile.dart';

class FixedRandom implements Random {
  FixedRandom(this.choice, {this.roll = 0.0});
  final int choice;
  final double roll;

  @override
  int nextInt(int max) => choice % max;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => roll;
}

void main() {
  test('starting regions differ in shelter, resources and danger', () {
    final seoul = GameState.newRun(random: FixedRandom(0));
    final busan = GameState.newRun(random: FixedRandom(1));
    final gangwon = GameState.newRun(random: FixedRandom(2));
    final jeju = GameState.newRun(random: FixedRandom(3));

    expect(seoul.world.id, 'seoul');
    expect(busan.world.id, 'busan');
    expect(gangwon.world.id, 'gangwon');
    expect(jeju.world.id, 'jeju');
    expect(busan.world.shelter, isNot(seoul.world.shelter));
    expect(gangwon.water, greaterThan(seoul.water));
    expect(seoul.world.dangerOffset, greaterThan(gangwon.world.dangerOffset));
    expect(busan.messages.single.role, ChatRole.world);
    expect(busan.messages.single.text, contains('항구'));
  });

  test('v2 saves migrate with existing stats and fallback world', () {
    final legacy = GameState(daysSurvived: 22, food: 2).toJson()
      ..['saveVersion'] = 2
      ..remove('world')
      ..remove('messages')
      ..remove('messageSerial')
      ..remove('lastDirectedEventDay');
    final loaded = GameState.fromJson(legacy);
    expect(loaded.daysSurvived, 22);
    expect(loaded.food, 2);
    expect(loaded.world.id, 'seoul');
    expect(loaded.messages, isEmpty);
  });

  test('chat transcript and world survive serialization', () {
    final state = GameState.newRun(random: FixedRandom(3));
    state.addChat(ChatRole.player, '거점으로 돌아간다');
    state.addChat(ChatRole.npc, '알겠어.', speaker: '동료');
    final loaded = GameState.fromJson(state.toJson());
    expect(loaded.world.id, 'jeju');
    expect(loaded.messages.map((m) => m.role).toList(), [
      ChatRole.world, ChatRole.player, ChatRole.npc
    ]);
    expect(loaded.messages.last.speaker, '동료');
  });

  test('accepted actions produce player/world chat messages in order', () {
    final state = GameState.newRun(random: FixedRandom(2));
    final engine = GameEngine(initialState: state, random: FixedRandom(0, roll: 0.99));
    final result = engine.execute(const GameAction.rest());
    expect(result.accepted, isTrue);
    expect(state.messages[1].role, ChatRole.player);
    expect(state.messages[2].role, ChatRole.world);
    expect(state.messages[2].sourceEventId, 'shelter_rest');
  });

  test('director rejects wrong place, missing NPC, and duplicate event', () {
    final state = GameState(
      world: WorldProfile.busan,
      daysSurvived: 5, npcMet: true,
    );
    final engine = GameEngine(initialState: state, random: FixedRandom(0));
    final wrongLocation = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.strangerAtDoor,
      premise: '문 밖에서 수상한 노크가 들려온다.',
      locationId: 'seoul',
    ));
    expect(wrongLocation.accepted, isFalse);
    expect(wrongLocation.code, 'location_mismatch');

    final missingNpc = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.companionConflict,
      premise: '같이 생활하는 사람과 불화가 생겼다.',
      locationId: 'busan',
    ));
    expect(missingNpc.code, 'companion_missing');

    final accepted = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.hiddenSupplies,
      premise: '폐창고 구석에서 덮개가 씌워진 상자가 발견됐다.',
      locationId: 'busan',
    ));
    expect(accepted.accepted, isTrue);
    expect(state.food, 5); // Premises no longer change resources.
    expect(state.pendingDirectedEvent, isNotNull);
    expect(state.messages.last.text, contains('폐창고'));
    final blocked = engine.execute(const GameAction.rest());
    expect(blocked.accepted, isFalse);
    final choice = engine.execute(GameAction.chooseDirectedEvent('inspect'));
    expect(choice.accepted, isTrue);
    expect(state.food, 6);
    expect(state.storyMemories.last.tags, contains('inspect'));
    final duplicate = engine.acceptDirectedEvent(const EventProposal(
      type: DirectedEventType.hiddenSupplies,
      premise: '또 다른 상자에서 반짝이는 물건이 보인다.',
      locationId: 'busan',
    ));
    expect(duplicate.code, 'event_already_generated');
    expect(state.food, 6);
  });

  test('rare unsettling encounters use an independent rarity gate', () {
    const proposal = EventProposal(
      type: DirectedEventType.unsettlingEncounter,
      premise: '낯선 발신자가 문틈으로 무언가를 밀어 넣는다.',
    );
    final rejected = GameEngine(
      initialState: GameState(daysSurvived: 12),
      random: FixedRandom(0, roll: 0.7),
    ).acceptDirectedEvent(proposal);
    expect(rejected.code, 'rarity_roll_failed');

    final state = GameState(daysSurvived: 12);
    final accepted = GameEngine(
      initialState: state,
      random: FixedRandom(0, roll: 0.001),
    ).acceptDirectedEvent(proposal);
    expect(accepted.accepted, isTrue);
    expect(state.noise, 0);
    final result = GameEngine(initialState: state).execute(
      GameAction.chooseDirectedEvent('barricade'));
    expect(result.accepted, isTrue);
    expect(state.noise, 6);
  });

  test('message transcript is bounded on long runs', () {
    final state = GameState();
    for (var index = 0; index < 95; index++) {
      state.addChat(ChatRole.world, '사건 $index');
    }
    expect(state.messages.length, GameState.maxChatMessages);
    expect(state.messages.first.text, '사건 15');
    expect(state.messages.last.text, '사건 94');
  });
}
