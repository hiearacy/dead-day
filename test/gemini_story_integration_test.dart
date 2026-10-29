import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dead_day/ai/gemini_world_story_provider.dart';
import 'package:dead_day/ai/world_story_provider.dart';
import 'package:dead_day/game/models.dart';

void main() {
  final endpoint = Uri.parse('https://dead-day.example.workers.dev/v1/story');
  final context = StoryContext.fromGame(GameState.newRun());

  test('Gemini story proxy returns a typed full scene with three options',
      () async {
    final client = MockClient((request) async {
      expect(request.url, endpoint);
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer private-test-only');
      expect(request.headers.containsKey('x-goog-api-key'), isFalse);
      final requestJson = jsonDecode(request.body) as Map<String, dynamic>;
      final game = requestJson['context'] as Map<String, dynamic>;
      expect(game['scenario'], isA<Map>());
      expect(game['location_id'], startsWith('start_'));
      expect(game['player'], isA<Map>());
      return http.Response.bytes(utf8.encode(jsonEncode({
        'diagnostics': {
          'source': 'gemini', 'model': 'test-model',
          'latency_ms': 555, 'total_tokens': 350,
        },
        'turn': {
          'id': 'world_turn_1_test',
          'story': '서울역 지하 통로에서 희미한 불빛이 보인다. '
              '그 아래에서 멀리 발소리가 들려온다. 어떻게 할까?',
          'choices': [
            {'id': 'choice_1', 'text': '통로로 내려간다',
             'intent': 'move', 'target_id': 'location_b3'},
            {'id': 'choice_2', 'text': '주변을 조사한다',
             'intent': 'investigate', 'target_id': null},
            {'id': 'choice_3', 'text': '안전한 곳에서 기다린다',
             'intent': 'observe', 'target_id': null},
          ],
          'generated_elements': [
            {'id': 'location_b3', 'name': '서울역 B3 구역',
             'kind': 'location', 'description': '폐쇄된 통제 구역',
             'parentId': game['location_id'],
             'createdDay': game['day'],
             'origin': 'ai_generated', 'discovered': true},
          ],
        }
      })), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final provider = GeminiWorldStoryProvider(
      endpoint: endpoint, demoToken: 'private-test-only', client: client,
    );
    final turn = await provider.generate(context);
    expect(turn.choices, hasLength(3));
    expect(turn.choices.first.targetId, 'location_b3');
    expect(turn.generatedElements.first.id, 'location_b3');
    expect(provider.lastSource, 'gemini');
    expect(provider.lastUsage?['total_tokens'], 350);
    provider.close();
  });

  test('quota failure falls back to offline story provider without a retry',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{"error":"gemini_quota_exceeded"}', 429);
    });
    final primary = GeminiWorldStoryProvider(
      endpoint: endpoint, demoToken: 'private-test-only', client: client,
    );
    final provider = FallbackWorldStoryProvider(
      primary, ProceduralWorldStoryProvider(),
    );
    final turn = await provider.generate(context);
    expect(calls, 1);
    expect(turn.choices, hasLength(3));
    expect(turn.generatedElements, hasLength(1));
    expect(turn.id, contains('fallback'));
    expect(provider.lastSource, 'offline');
    expect(provider.usedFallback, isTrue);
    expect(provider.lastUsage, isNull);
    primary.close();
  });

  test('invalid JSON also uses offline fallback', () async {
    final client = MockClient((_) async => http.Response(
      '{"turn":{"choices":"invalid"}}', 200,
    ));
    final primary = GeminiWorldStoryProvider(
      endpoint: endpoint, demoToken: 'private-test-only', client: client,
    );
    final turn = await FallbackWorldStoryProvider(
      primary, ProceduralWorldStoryProvider(),
    ).generate(context);
    expect(turn.id, contains('fallback'));
    expect(turn.choices, hasLength(3));
    primary.close();
  });
}
