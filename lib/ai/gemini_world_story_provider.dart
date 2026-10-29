import 'dart:convert';
import 'package:http/http.dart' as http;
import '../game/story_turn.dart';
import 'world_story_provider.dart';

/// Gemini API key stays in the Worker. The demo bearer is a temporary
/// private-testing credential and MUST NOT be shipped in a public release.
class GeminiWorldStoryProvider
    implements WorldStoryProvider, StoryProviderDiagnostics {
  GeminiWorldStoryProvider({
    required this.endpoint, required this.demoToken, http.Client? client,
  }) : _client = client ?? http.Client() {
    if (endpoint.scheme != 'https' && endpoint.host != 'localhost') {
      throw ArgumentError('Story endpoint requires HTTPS');
    }
    if (endpoint.path != '/v1/story' || demoToken.isEmpty) {
      throw ArgumentError('Invalid story proxy configuration');
    }
  }

  final Uri endpoint;
  final String demoToken;
  final http.Client _client;

  @override
  String get lastSource => 'gemini';

  @override
  bool get usedFallback => false;

  @override
  Map<String, dynamic>? lastUsage;

  @override
  Future<StoryTurn> generate(StoryContext context) async {
    final response = await _client.post(endpoint, headers: {
      'content-type': 'application/json',
      'authorization': 'Bearer $demoToken',
    }, body: jsonEncode({'context': context.data})).timeout(
      const Duration(seconds: 28),
    );
    if (response.statusCode != 200 || response.bodyBytes.length > 16000) {
      throw StateError('Gemini story API unavailable');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['turn'] is! Map) {
      throw const FormatException('Invalid story response');
    }
    final rawDiagnostics = data['diagnostics'];
    lastUsage = rawDiagnostics is Map &&
            rawDiagnostics['source'] == 'gemini'
        ? Map<String, dynamic>.from(rawDiagnostics)
        : null;
    return StoryTurn.fromJson(Map<String, dynamic>.from(data['turn'] as Map));
  }

  void close() => _client.close();
}
