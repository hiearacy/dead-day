import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/event_director.dart';
import 'package:dead_day/ai/procedural_director.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/world_profile.dart';

class StableRandom implements Random {
  StableRandom(this.value);
  final int value;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.9;
  @override
  int nextInt(int max) => value % max;
}

void main() {
  test('world names give different sites for the same loot category', () {
    expect(WorldProfile.seoul.siteFor('market'), isNot(WorldProfile.busan.siteFor('market')));
    expect(WorldProfile.gangwon.siteFor('pharmacy'), contains('보건지소'));
    expect(WorldProfile.jeju.siteFor('apartments'), contains('게스트하우스'));
  });

  test('procedural director suggests compatible event with world context', () async {
    final state = GameState(world: WorldProfile.gangwon, daysSurvived: 6);
    final director = ProceduralEventDirector(random: StableRandom(1));
    final proposal = await director.propose(DirectorContext.fromGame(state));
    expect(proposal, isNotNull);
    expect(proposal!.locationId, 'gangwon');
    expect(proposal.premise, contains('강원'));
    final result = GameEngine(initialState: state).acceptDirectedEvent(proposal);
    expect(result.accepted, isTrue);
    expect(state.lastDirectedEventDay, 6);
    expect(state.messages, isNotEmpty);
  });

  test('event proposal never directly changes resources', () {
    final state = GameState(world: WorldProfile.seoul, daysSurvived: 4);
    final before = state.toJson().toString();
    const proposal = EventProposal(
      type: DirectedEventType.hiddenSupplies,
      premise: '버려진 창고에서 닫힌 상자가 발견됐다.',
      locationId: 'seoul',
    );
    expect(state.toJson().toString(), before);
    final result = GameEngine(initialState: state).acceptDirectedEvent(proposal);
    expect(result.accepted, isTrue);
    expect(state.food, 5); // No result until the player's choice.
    expect(state.pendingDirectedEvent?.typeName, 'hiddenSupplies');
    final chosen = GameEngine(initialState: state).execute(
      GameAction.chooseDirectedEvent('inspect'));
    expect(chosen.accepted, isTrue);
    expect(state.food, 6);
    expect(state.daysSurvived, 4); // Side event does not advance day.
  });
}
