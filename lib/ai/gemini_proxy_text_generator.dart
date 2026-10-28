import 'dart:convert';
import 'package:http/http.dart' as http;
import 'structured_event_director.dart';

/// Flutter client -> your secret-holding proxy -> Gemini.
/// Never include a Gemini API key in this app or in --dart-define.
/// The optional DEMO bearer token below is for *private testing only* and is
/// extractable from distributed apps. Real deployment needs user auth.
class GeminiProxyTextGenerator implements TextGenerator {
  GeminiProxyTextGenerator({
    required Uri endpoint,
    required String demoToken,
    http.Client? client,
  })  : _endpoint = endpoint,
        _demoToken = demoToken,
        _client = client ?? http.Client() {
    if (endpoint.scheme != 'https' && endpoint.host != 'localhost' &&
        endpoint.host != '127.0.0.1') {
      throw ArgumentError('Gemini proxy must use HTTPS');
    }
    if (demoToken.isEmpty) {
      throw ArgumentError('Private test token is required');
    }
  }

  final Uri _endpoint;
  final String _demoToken;
  final http.Client _client;

  @override
  Future<String> generate({
    required String prompt,
    required int maxOutputTokens,
    required double temperature,
  }) async {
    if (prompt.length > 6000) throw const FormatException('Prompt too large');
    final response = await _client.post(
      _endpoint,
      headers: {
        'authorization': 'Bearer $_demoToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'prompt': prompt,
        'maxOutputTokens': maxOutputTokens,
        'temperature': temperature,
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      // HTTP 429 etc trigger procedural fallback; never include secrets in logs.
      throw StateError('AI proxy returned status ${response.statusCode}');
    }
    if (response.body.length > 4000) {
      throw const FormatException('Oversized AI response');
    }
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    if (result is! Map<String, dynamic> || result['text'] is! String) {
      throw const FormatException('Malformed AI response');
    }
    return result['text'] as String;
  }

  void close() => _client.close();
}
