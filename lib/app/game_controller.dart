import 'package:flutter/foundation.dart';
import '../ai/narrator.dart';
import '../ai/world_story_provider.dart';
import '../ai/event_director.dart';
import '../ai/procedural_director.dart';
import '../game/chat_message.dart';
import '../data/save_service.dart';
import '../game/event_record.dart';
import '../game/game_action.dart';
import '../game/game_engine.dart';
import '../game/models.dart';

/// UI adapter: gameplay decisions always go through the Dart engine.
/// AI is optional, read-only, and invoked for notable events only.
class GameController extends ChangeNotifier {
  GameController({SaveService? saves, AiNarrator? narrator,
      EventDirector? director, WorldStoryProvider? worldStoryProvider})
      : _saves = saves ?? SaveService(),
        _narrator = narrator ?? const NoAiNarrator(),
        _director = director ?? ProceduralEventDirector(),
        _worldStoryProvider = worldStoryProvider ?? ProceduralWorldStoryProvider();

  final SaveService _saves;
  final AiNarrator _narrator;
  final EventDirector _director;
  final WorldStoryProvider _worldStoryProvider;
  bool generatingWorldStory = false;
  String storySource = 'offline';
  Map<String, dynamic>? storyUsage;
  String? storySourceNote;
  GameEngine _engine = GameEngine(initialState: GameState.newRun());
  Future<void> _saveQueue = Future<void>.value();
  int _sequence = 0;
  bool _disposed = false;
  bool loading = true;
  String? error;
  String? aiText;
  GameResult? lastResult;

  GameState get state => _engine.state;

  Future<void> initialize() async {
    try {
      final saved = await _saves.load();
      if (_disposed) return;
      _engine = GameEngine(initialState: saved ?? GameState.newRun());
    } catch (_) {
      error = '저장 데이터를 읽을 수 없어 새 게임으로 시작합니다.';
    } finally {
      loading = false;
      _notify();
    }
    if (!_disposed && state.interactiveMode && !state.waitingForChoice) {
      await requestWorldStory();
    }
  }

  Future<void> explore(Zone zone) async {
    await dispatch(GameAction.explore(zone));
  }

  Future<void> rest() async {
    await dispatch(const GameAction.rest());
  }

  Future<void> useMedicine() async {
    await dispatch(const GameAction.useMedicine());
  }

  Future<void> resolve(EncounterAction action) async {
    await dispatch(GameAction.resolve(action));
  }

  Future<void> recruit(bool accept) async {
    await dispatch(GameAction.recruit(accept));
  }

  Future<void> chooseStory(String choiceId) async {
    await dispatch(GameAction.chooseStory(choiceId));
  }

  Future<void> chooseDirectedEvent(String choiceId) async {
    await dispatch(GameAction.chooseDirectedEvent(choiceId));
  }

  Future<void> chooseWorldTurn(String choiceId) async {
    await dispatch(GameAction.chooseWorldTurn(choiceId));
  }

  /// No state is mutated while waiting for network/model output.
  Future<void> requestWorldStory() async {
    if (generatingWorldStory || _disposed || !state.interactiveMode ||
        state.gameOver || state.waitingForChoice) {
      return;
    }
    final engine = _engine;
    final sequence = _sequence;
    generatingWorldStory = true;
    _notify();
    try {
      final proposal = await _worldStoryProvider.generate(
        StoryContext.fromGame(engine.state),
      );
      if (_disposed || engine != _engine || sequence != _sequence ||
          engine.state.waitingForChoice) {
        return;
      }
      storySource = _worldStoryProvider is StoryProviderDiagnostics
          ? (_worldStoryProvider as StoryProviderDiagnostics).lastSource
          : (_worldStoryProvider is ProceduralWorldStoryProvider
              ? 'offline' : 'custom');
      storyUsage = _worldStoryProvider is StoryProviderDiagnostics
          ? (_worldStoryProvider as StoryProviderDiagnostics).lastUsage
          : null;
      storySourceNote = _worldStoryProvider is StoryProviderDiagnostics &&
              (_worldStoryProvider as StoryProviderDiagnostics).usedFallback
          ? 'Gemini 연결·할당량·응답 문제로 규칙 기반 장면을 사용합니다.'
          : null;
      var applied = engine.acceptWorldTurn(proposal);
      if (!applied.accepted) {
        storySource = 'offline';
        storyUsage = null;
        storySourceNote = 'AI 장면이 게임 규칙을 통과하지 못해 대체 장면을 생성했습니다.';
        // A provider can return structurally valid JSON that still
        // contradicts the engine. Never trust it; try the same local fallback.
        final fallback = await ProceduralWorldStoryProvider().generate(
          StoryContext.fromGame(engine.state),
        );
        applied = engine.acceptWorldTurn(fallback);
      }
      if (applied.accepted) {
        error = null;
        lastResult = applied;
        _notify();
        await _persist();
      } else {
        error = '새 장면을 검증하지 못했습니다. 다시 시도할 수 있습니다.';
      }
    } catch (_) {
      storySource = 'offline';
      storyUsage = null;
      error = '이야기 생성에 실패했습니다. 다시 시도할 수 있습니다.';
    } finally {
      generatingWorldStory = false;
      _notify();
    }
  }

  /// This one API can later be used by UI, scripts and validated NPC agents.
  Future<GameResult> dispatch(GameAction action) async {
    final result = _engine.execute(action);
    if (!result.accepted) return result; // Invalid taps never cost inference.
    lastResult = result;
    aiText = null;
    final sequence = ++_sequence;
    _notify();
    await _persist();
    if (action.type == GameActionType.chooseWorldTurn &&
        sequence == _sequence && state.interactiveMode &&
        !state.waitingForChoice && !state.gameOver) {
      await requestWorldStory();
      return result;
    }

    // Skip stale requests: a newer action or a new game may have started.
    // The director can propose a rare situation after a fully completed day.
    // A small procedural fallback runs by default; a local model can replace it.
    var directedEventAccepted = false;
    if (sequence == _sequence &&
        result.dayAfter > result.dayBefore &&
        state.daysSurvived % 4 == 0 &&
        !state.waitingForChoice &&
        !state.gameOver) {
      try {
        final proposal = await _director.propose(DirectorContext.fromGame(state));
        if (sequence == _sequence && proposal != null) {
          final directed = _engine.acceptDirectedEvent(proposal);
          if (directed.accepted) {
            directedEventAccepted = true;
            lastResult = directed;
            _notify();
            await _persist();
          }
        }
      } catch (_) {
        // Model failure must not change or pause the survival loop.
      }
    }

    if (sequence == _sequence && (_shouldNarrate(result) || directedEventAccepted)) {
      try {
        final scene = AiScene.fromGame(state);
        final generated = await _narrator.narrate(scene);
        if (sequence == _sequence && generated != null && generated.isNotEmpty) {
          aiText = generated;
          state.addChat(ChatRole.world, generated, eventId: 'ai_narration');
          _notify();
          await _persist();
        }
      } catch (_) {
        // Missing or failing models never block saving or gameplay.
      }
    }
    return result;
  }

  bool _shouldNarrate(GameResult result) => result.events.any(
        (event) => event.kind == EventKind.combat ||
            event.kind == EventKind.companion ||
            event.id.startsWith('story_') ||
            event.id.startsWith('director_') ||
            event.id == 'distant_horde',
      );

  Future<void> newGame({String scenarioId = 'open_survival'}) async {
    _sequence++;
    final best = state.bestDays;
    _engine = GameEngine(
        initialState: GameState.newRun(bestDays: best, scenarioId: scenarioId));
    lastResult = null;
    aiText = null;
    error = null;
    storySource = 'offline';
    storyUsage = null;
    storySourceNote = null;
    _notify();
    await _persist();
    if (state.interactiveMode) await requestWorldStory();
  }

  Future<void> _persist() {
    final snapshot = GameState.fromJson(state.toJson());
    _saveQueue = _saveQueue.then((_) => _saves.save(snapshot)).catchError(
      (Object _) {
        error = '저장에 실패했습니다. 현재 게임은 계속할 수 있습니다.';
        _notify();
      },
    );
    return _saveQueue;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
