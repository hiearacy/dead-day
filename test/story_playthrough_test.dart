import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/game/game_action.dart';
import 'package:dead_day/game/game_engine.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/scenario_definition.dart';

class QuietRandom implements Random {
  const QuietRandom();
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0.99;
}

void main() {
  test('18-day run resolves four linked story beats across reloads', () {
    var current = GameState(
      scenario: ScenarioCatalog.lostSignal,
      daysSurvived: 2,
      npcMet: true,
      food: 100,
      water: 100,
      medicine: 5,
    );
    final storyIds = <String>[];
    final choiceIds = <String>[];

    while (current.daysSurvived < 18 && !current.gameOver) {
      final engine = GameEngine(
        initialState: current,
        random: const QuietRandom(),
      );
      if (current.pendingStory != null) {
        final beat = current.pendingStory!;
        storyIds.add(beat.id);
        final selected = beat.choices.first;
        choiceIds.add(selected.id);
        final result = engine.execute(GameAction.chooseStory(selected.id));
        expect(result.accepted, isTrue);
        expect(current.pendingStory, isNull);
      } else {
        final result = engine.execute(const GameAction.rest());
        expect(result.accepted, isTrue);
      }
      // Model the app being closed and reopened after every single action.
      current = GameState.fromJson(current.toJson());
    }

    expect(current.daysSurvived, 18);
    expect(current.gameOver, isFalse);
    expect(storyIds, [
      'radio_signal_open',
      'radio_signal_followup',
      'visitor_open',
      'visitor_followup',
    ]);
    expect(choiceIds, ['trace', 'share', 'help', 'accept_tip']);
    expect(current.storyThreads.length, 2);
    expect(current.storyThreads.every((thread) => thread.closed), isTrue);
    expect(current.storyMemories.length, 4);
    expect(current.pendingStory, isNull);
    expect(current.messages.length, lessThanOrEqualTo(GameState.maxChatMessages));
  });
}
