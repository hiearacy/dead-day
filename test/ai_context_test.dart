import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/narrator.dart';
import 'package:dead_day/game/event_record.dart';
import 'package:dead_day/game/models.dart';

void main() {
  test('AI context exposes bounded recent events without state mutation', () {
    final companion = Companion(name: '서윤');
    for (var i = 0; i < 9; i++) {
      companion.remember('기억 $i: ${List.filled(160, '가').join()}');
    }
    final state = GameState(
      companion: companion,
      log: '확정 사건 ${List.filled(500, '나').join()}',
    );
    for (var i = 0; i < 7; i++) {
      state.record(GameEventRecord(
        id: 'event_$i',
        day: i,
        kind: EventKind.system,
        text: '사건 $i: ${List.filled(120, '다').join()}',
      ));
    }

    final before = state.toJson().toString();
    final context = AiScene.fromGame(state);
    expect(context.outcome.length, lessThanOrEqualTo(300));
    expect(context.recentEvents, hasLength(3));
    expect(context.npcMemories, hasLength(3));
    expect(context.recentEvents.every((item) => item.length <= 100), isTrue);
    expect(context.npcMemories.every((item) => item.length <= 80), isTrue);
    expect(context.compactPrompt, contains('확정된 사건'));
    expect(state.toJson().toString(), before);
  });

  test('no-AI fallback can be called without installed model', () async {
    final state = GameState();
    final text = await const NoAiNarrator().narrate(AiScene.fromGame(state));
    expect(text, isNull);
  });
}
