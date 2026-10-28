import 'event_director.dart';
import 'gemini_proxy_text_generator.dart';
import 'procedural_director.dart';
import 'structured_event_director.dart';

/// AI is OFF unless a private test endpoint+credential are supplied at build.
/// A public client build must not embed a shared credential.
class AiConfiguration {
  const AiConfiguration._();

  static const String endpointUrl =
      String.fromEnvironment('DEAD_DAY_AI_PROXY_URL');
  static const String privateDemoToken =
      String.fromEnvironment('DEAD_DAY_PRIVATE_DEMO_TOKEN');

  static EventDirector createDirector() {
    final fallback = ProceduralEventDirector();
    if (endpointUrl.isEmpty || privateDemoToken.isEmpty) return fallback;

    final uri = Uri.tryParse(endpointUrl);
    if (uri == null || uri.path != '/v1/director') return fallback;
    try {
      final generator = GeminiProxyTextGenerator(
        endpoint: uri,
        demoToken: privateDemoToken,
      );
      return FallbackEventDirector(
        StructuredAiEventDirector(generator),
        fallback,
      );
    } catch (_) {
      return fallback;
    }
  }
}
