import 'event_director.dart';
import 'world_story_provider.dart';
import 'gemini_world_story_provider.dart';
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

  static WorldStoryProvider createWorldStoryProvider() {
    final fallback = ProceduralWorldStoryProvider();
    if (endpointUrl.isEmpty || privateDemoToken.isEmpty) return fallback;
    final base = Uri.tryParse(endpointUrl);
    if (base == null) return fallback;
    try {
      return FallbackWorldStoryProvider(
        GeminiWorldStoryProvider(
          endpoint: base.replace(path: '/v1/story'),
          demoToken: privateDemoToken,
        ),
        fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

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
