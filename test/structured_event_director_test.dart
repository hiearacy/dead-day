import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/event_director.dart';
import 'package:dead_day/ai/structured_event_director.dart';
import 'package:dead_day/game/models.dart';

class FakeGenerator implements TextGenerator {
  FakeGenerator(this.response);
  final String response;
  int calls = 0;
  int? maxOutputTokens;
  @override
  Future<String> generate({
    required String prompt,
    required int maxOutputTokens,
    required double temperature,
  }) async {
    calls++;
    this.maxOutputTokens = maxOutputTokens;
    expect(prompt, contains('시나리오'));
    return response;
  }
}

class FakeDirector implements EventDirector {
  const FakeDirector();
  @override
  Future<EventProposal?> propose(DirectorContext context) async =>
      const EventProposal(
        type: DirectedEventType.strangerAtDoor,
        premise: '문 밖에서 두 사람이 낮게 속삭이고 있다.',
      );
}

void main() {
  final context = DirectorContext.fromGame(GameState(daysSurvived: 7));

  test('bounded structured JSON can become an event proposal', () async {
    final generator = FakeGenerator(
      '{"type":"strangerAtDoor","premise":"문 밖에서 낯선 사람이 문을 두드린다.",'
      '"locationId":"seoul"}',
    );
    final proposal = await StructuredAiEventDirector(generator).propose(context);
    expect(proposal?.type, DirectedEventType.strangerAtDoor);
    expect(proposal?.locationId, 'seoul');
    expect(generator.maxOutputTokens, 128);
  });

  test('unrecognized, malformed or bloated model output is ignored', () async {
    for (final invalid in [
      '일반 자연어 응답',
      '{"type":"inventWeapons","premise":"임의의 무기를 무한 생성한다."}',
      '{"type":"strangerAtDoor","premise":"짧음"}',
      List.filled(1300, 'x').join(),
    ]) {
      final result = await StructuredAiEventDirector(FakeGenerator(invalid))
          .propose(context);
      expect(result, isNull);
    }
  });

  test('fallback director continues despite broken local model', () async {
    final fallback = FallbackEventDirector(
      StructuredAiEventDirector(FakeGenerator('not JSON')),
      const FakeDirector(),
    );
    final result = await fallback.propose(context);
    expect(result?.type, DirectedEventType.strangerAtDoor);
  });
}
