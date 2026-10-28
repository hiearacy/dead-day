import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dead_day/ai/gemini_proxy_text_generator.dart';

void main() {
  final endpoint = Uri.parse('https://example.workers.dev/v1/director');

  test('Gemini proxy receives bounded prompt, never Google API key', () async {
    final client = MockClient((request) async {
      expect(request.url, endpoint);
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer demo-token');
      expect(request.headers.containsKey('x-goog-api-key'), isFalse);
      final input = jsonDecode(request.body) as Map<String, dynamic>;
      expect(input['prompt'], 'scenario and game state');
      expect(input['maxOutputTokens'], 128);
      expect(input['temperature'], 0.75);
      return http.Response(jsonEncode({
        'text': '{"type":"strangerAtDoor","premise":"문이 천천히 열린다."}',
      }), 200);
    });
    final generator = GeminiProxyTextGenerator(
      endpoint: endpoint, demoToken: 'demo-token', client: client,
    );
    final text = await generator.generate(
      prompt: 'scenario and game state',
      maxOutputTokens: 128, temperature: 0.75,
    );
    expect(text, contains('strangerAtDoor'));
    generator.close();
  });

  test('429 quota exhaustion fails closed for procedural fallback', () async {
    final client = MockClient((request) async =>
        http.Response('{"error":"gemini_quota_exceeded"}', 429));
    final generator = GeminiProxyTextGenerator(
      endpoint: endpoint, demoToken: 'demo-token', client: client,
    );
    expect(
      () => generator.generate(
        prompt: 'scenario and game state',
        maxOutputTokens: 128, temperature: 0.75,
      ),
      throwsStateError,
    );
    generator.close();
  });

  test('rejects insecure public HTTP API endpoint', () {
    expect(
      () => GeminiProxyTextGenerator(
        endpoint: Uri.parse('http://example.com/v1/director'),
        demoToken: 'demo-token',
      ),
      throwsArgumentError,
    );
  });
}
