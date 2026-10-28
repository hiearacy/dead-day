import 'models.dart';
import 'event_record.dart';

/// UI, future NPC agents and tests send the same typed commands to the engine.
/// Never let an AI-produced string invoke arbitrary code or write game state.
enum GameActionType { explore, rest, useMedicine, resolveEncounter, recruit, chooseStory, chooseDirectedEvent }

class GameAction {
  const GameAction._(this.type, {this.zone, this.encounterAction, this.accept, this.choiceId});

  final GameActionType type;
  final Zone? zone;
  final EncounterAction? encounterAction;
  final bool? accept;
  final String? choiceId;

  factory GameAction.explore(Zone zone) =>
      GameAction._(GameActionType.explore, zone: zone);
  const GameAction.rest() : this._(GameActionType.rest);
  const GameAction.useMedicine() : this._(GameActionType.useMedicine);
  factory GameAction.resolve(EncounterAction action) =>
      GameAction._(GameActionType.resolveEncounter, encounterAction: action);
  factory GameAction.recruit(bool accept) =>
      GameAction._(GameActionType.recruit, accept: accept);
  factory GameAction.chooseStory(String choiceId) =>
      GameAction._(GameActionType.chooseStory, choiceId: choiceId);
  factory GameAction.chooseDirectedEvent(String choiceId) =>
      GameAction._(GameActionType.chooseDirectedEvent, choiceId: choiceId);
}

/// Immutable result contract for future UI / replay / AI narration.
/// All changes to gameplay take place before a result is returned.
class GameResult {
  const GameResult({
    required this.accepted,
    required this.code,
    required this.dayBefore,
    required this.dayAfter,
    required this.events,
  });

  final bool accepted;
  final String code;
  final int dayBefore;
  final int dayAfter;
  final List<GameEventRecord> events;
}
