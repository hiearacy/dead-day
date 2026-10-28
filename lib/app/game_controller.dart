import 'package:flutter/foundation.dart';
import '../ai/narrator.dart';
import '../data/save_service.dart';
import '../game/event_record.dart';
import '../game/game_action.dart';
import '../game/game_engine.dart';
import '../game/models.dart';

/// UI adapter: gameplay decisions always go through the Dart engine.
/// AI is optional, read-only, and invoked for notable events only.
class GameController extends ChangeNotifier {
  GameController({SaveService? saves, AiNarrator? narrator})
      : _saves = saves ?? SaveService(),
        _narrator = narrator ?? const NoAiNarrator();

  final SaveService _saves;
  final AiNarrator _narrator;
  GameEngine _engine = GameEngine();
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
      _engine = GameEngine(initialState: saved);
    } catch (_) {
      error = '저장 데이터를 읽을 수 없어 새 게임으로 시작합니다.';
    } finally {
      loading = false;
      _notify();
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

  /// This one API can later be used by UI, scripts and validated NPC agents.
  Future<GameResult> dispatch(GameAction action) async {
    final result = _engine.execute(action);
    if (!result.accepted) return result; // Invalid taps never cost inference.
    lastResult = result;
    aiText = null;
    final sequence = ++_sequence;
    _notify();
    await _persist();

    if (_shouldNarrate(result)) {
      try {
        final scene = AiScene.fromGame(state);
        final generated = await _narrator.narrate(scene);
        if (sequence == _sequence && generated != null && generated.isNotEmpty) {
          aiText = generated;
          _notify();
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
            event.id == 'distant_horde',
      );

  Future<void> newGame() async {
    _sequence++;
    final best = state.bestDays;
    _engine = GameEngine(initialState: GameState(bestDays: best));
    lastResult = null;
    aiText = null;
    error = null;
    _notify();
    await _persist();
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
