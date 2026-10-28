import 'package:flutter/foundation.dart';
import '../ai/narrator.dart';
import '../data/save_service.dart';
import '../game/game_engine.dart';
import '../game/models.dart';

class GameController extends ChangeNotifier {
  GameController({SaveService? saves, AiNarrator? narrator})
      : _saves = saves ?? SaveService(),
        _narrator = narrator ?? const NoAiNarrator();

  final SaveService _saves;
  final AiNarrator _narrator;
  GameEngine _engine = GameEngine();
  Future<void> _saveQueue = Future<void>.value();
  int _sequence = 0;
  bool loading = true;
  String? error;
  String? aiText;

  GameState get state => _engine.state;

  Future<void> initialize() async {
    try {
      final saved = await _saves.load();
      _engine = GameEngine(initialState: saved);
    } catch (_) {
      error = '저장 데이터를 읽을 수 없어 새 게임으로 시작합니다.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> explore(Zone zone) => _perform(() => _engine.explore(zone));
  Future<void> rest() => _perform(_engine.rest);
  Future<void> useMedicine() => _perform(_engine.useMedicine);
  Future<void> resolve(EncounterAction action) =>
      _perform(() => _engine.resolveEncounter(action));
  Future<void> recruit(bool accept) =>
      _perform(() => _engine.decideRecruitment(accept));

  Future<void> newGame() async {
    _sequence++;
    final best = state.bestDays;
    _engine = GameEngine(initialState: GameState(bestDays: best));
    aiText = null;
    error = null;
    notifyListeners();
    await _persist();
  }

  Future<void> _perform(VoidCallback action) async {
    // Synchronous state transitions prevent duplicate decisions while saving.
    action();
    aiText = null;
    final sequence = ++_sequence;
    notifyListeners();
    await _persist();
    try {
      final generated = await _narrator.narrate(AiScene.fromGame(state));
      if (sequence == _sequence && generated != null && generated.isNotEmpty) {
        aiText = generated;
        notifyListeners();
      }
    } catch (_) {
      // Inference failures must never block gameplay or saving.
    }
  }

  Future<void> _persist() {
    final snapshot = GameState.fromJson(state.toJson());
    _saveQueue = _saveQueue.then((_) => _saves.save(snapshot)).catchError(
      (Object _) {
        error = '저장에 실패했습니다. 현재 게임은 계속할 수 있습니다.';
        notifyListeners();
      },
    );
    return _saveQueue;
  }
}
