import 'dart:math';
import '../ai/event_director.dart';
import 'chat_message.dart';
import 'generated_world_element.dart';
import 'story_turn.dart';
import 'world_story_validator.dart';
import 'directed_event_system.dart';
import 'event_record.dart';
import 'event_system.dart';
import 'game_action.dart';
import 'models.dart';
import 'npc_system.dart';
import 'story_memory.dart';
import 'story_system.dart';

/// The authoritative rules engine. No Flutter or model runtime imports here.
/// All actions use the same verified dispatch path, regardless of their source.
class GameEngine {
  GameEngine({
    GameState? initialState,
    Random? random,
    NightEventSystem? nightEvents,
    NpcSystem? npcs,
    DirectedEventSystem? directedEvents,
    StorySystem? storySystem,
    WorldStoryValidator? worldStoryValidator,
  })  : state = initialState ?? GameState(),
        _random = random ?? Random(),
        _nightEvents = nightEvents ?? const NightEventSystem(),
        _npcs = npcs ?? const NpcSystem(),
        _directedEvents = directedEvents ?? const DirectedEventSystem(),
        _storySystem = storySystem ?? const StorySystem(),
        _worldStoryValidator = worldStoryValidator ?? const WorldStoryValidator();

  final GameState state;
  final Random _random;
  final NightEventSystem _nightEvents;
  final NpcSystem _npcs;
  final DirectedEventSystem _directedEvents;
  final StorySystem _storySystem;
  final WorldStoryValidator _worldStoryValidator;
  List<GameEventRecord> _emitted = [];

  /// New UI, scripts and future constrained AI agents can dispatch typed actions.
  /// Rejected actions do not advance time or modify inventory.
  GameResult execute(GameAction action) {
    final before = state.daysSurvived;
    _emitted = [];
    if (state.gameOver) return _rejected('game_over', before);

    switch (action.type) {
      case GameActionType.explore:
        if (!state.canStartAction || action.zone == null) {
          return _rejected('pending_decision', before);
        }
        state.addChat(ChatRole.player,
            '${state.world.siteFor(action.zone!.name)}을(를) 수색한다');
        _explore(action.zone!);
        break;
      case GameActionType.rest:
        if (!state.canStartAction) {
          return _rejected('pending_decision', before);
        }
        state.addChat(ChatRole.player, '거점에서 휴식한다');
        _rest();
        break;
      case GameActionType.useMedicine:
        if (!state.canStartAction || state.medicine <= 0 || state.health >= 100) {
          return _rejected('medicine_unavailable', before);
        }
        state.addChat(ChatRole.player, '의약품을 사용한다');
        _useMedicine();
        break;
      case GameActionType.resolveEncounter:
        if (state.encounter == null || action.encounterAction == null) {
          return _rejected('no_encounter', before);
        }
        state.addChat(ChatRole.player, switch (action.encounterAction!) {
          EncounterAction.fight => '싸운다',
          EncounterAction.flee => '도망친다',
          EncounterAction.sneak => '숨는다',
        });
        _resolveEncounter(action.encounterAction!);
        break;
      case GameActionType.recruit:
        if (!state.pendingRecruitment || action.accept == null) {
          return _rejected('no_recruitment', before);
        }
        state.addChat(ChatRole.player, action.accept! ? '함께 지내자' : '거절한다');
        _decideRecruitment(action.accept!);
        break;
      case GameActionType.chooseStory:
        final beat = state.pendingStory;
        if (beat == null || action.choiceId == null) {
          return _rejected('no_story_choice', before);
        }
        final choices = beat.choices.where((item) => item.id == action.choiceId);
        if (choices.isEmpty || !_storySystem.canChoose(state, choices.first)) {
          return _rejected('invalid_story_choice', before);
        }
        state.addChat(ChatRole.player, choices.first.label);
        _resolveStory(action.choiceId!);
        break;
      case GameActionType.chooseDirectedEvent:
        final pending = state.pendingDirectedEvent;
        if (pending == null || action.choiceId == null) {
          return _rejected('no_directed_event', before);
        }
        final selected = pending.choices.where(
          (choice) => choice.id == action.choiceId,
        );
        if (selected.isEmpty) {
          return _rejected('invalid_directed_choice', before);
        }
        state.addChat(ChatRole.player, selected.first.label);
        _resolveDirectedEvent(action.choiceId!);
        break;
      case GameActionType.chooseWorldTurn:
        final turn = state.pendingWorldTurn;
        if (turn == null || action.choiceId == null) {
          return _rejected('no_world_story', before);
        }
        final choices = turn.choices.where((v) => v.id == action.choiceId);
        if (choices.isEmpty) return _rejected('invalid_world_choice', before);
        state.addChat(ChatRole.player, choices.first.text);
        _resolveWorldTurn(choices.first);
        break;
    }

    return GameResult(
      accepted: true,
      code: state.gameOver ? 'game_over' : 'ok',
      dayBefore: before,
      dayAfter: state.daysSurvived,
      events: List<GameEventRecord>.unmodifiable(_emitted),
    );
  }

  // Compatibility with the v0.1 controller; new code can use execute().
  void explore(Zone zone) { execute(GameAction.explore(zone)); }
  void resolveEncounter(EncounterAction action) { execute(GameAction.resolve(action)); }
  void rest() { execute(const GameAction.rest()); }
  void useMedicine() { execute(const GameAction.useMedicine()); }
  void decideRecruitment(bool accept) { execute(GameAction.recruit(accept)); }

  /// Safe late-bound integration for a future *optional* mobile AI director.
  /// This does not consume a day or bypass pending player choices.
  GameResult acceptDirectedEvent(EventProposal proposal) {
    final before = state.daysSurvived;
    _emitted = [];
    final problem = _directedEvents.rejection(state, proposal);
    if (problem != null) return _rejected(problem, before);
    if (!_directedEvents.passesRarity(proposal, _random)) {
      return _rejected('rarity_roll_failed', before);
    }
    final pending = _directedEvents.offer(state, proposal);
    state.pendingDirectedEvent = pending;
    state.lastDirectedEventDay = state.daysSurvived;
    state.log = pending.premise;
    _record(pending.id, EventKind.hazard, pending.premise);
    return GameResult(
      accepted: true,
      code: 'event_accepted',
      dayBefore: before,
      dayAfter: state.daysSurvived,
      events: List<GameEventRecord>.unmodifiable(_emitted),
    );
  }

  /// A proposed scene and its discovered elements are accepted atomically.
  /// The LLM can *describe* a location but cannot force movement or inventory.
  GameResult acceptWorldTurn(StoryTurn turn) {
    final before = state.daysSurvived;
    _emitted = [];
    final issue = _worldStoryValidator.rejection(state, turn);
    if (issue != null) return _rejected(issue, before);
    state.generatedElements.addAll(turn.generatedElements);
    state.pendingWorldTurn = turn;
    state.log = turn.story;
    _record('world_turn_${turn.id}', EventKind.system, turn.story);
    return GameResult(
      accepted: true, code: 'world_story_offered',
      dayBefore: before, dayAfter: state.daysSurvived,
      events: List<GameEventRecord>.unmodifiable(_emitted),
    );
  }

  void _resolveWorldTurn(TurnChoice choice) {
    final turn = state.pendingWorldTurn!;
    state.pendingWorldTurn = null;
    switch (choice.intent) {
      case StoryIntent.move:
        state.currentLocationId = choice.targetId!;
        state.noise = min(100, state.noise + 2);
        break;
      case StoryIntent.investigate:
        state.noise = min(100, state.noise + 4);
        break;
      case StoryIntent.talk:
        if (state.companion != null) {
          state.companion!.trust = min(100, state.companion!.trust + 1);
        }
        break;
      case StoryIntent.observe:
        state.noise = max(0, state.noise - 2);
        break;
    }
    state.latestChoiceSummary = choice.text;
    final summary = '${choice.text} (행동: ${choice.intent.name})';
    state.rememberStory(StoryMemory(
      key: 'world_choice_${turn.id}_${choice.id}',
      day: state.currentDay, summary: summary,
      threadId: 'world_${turn.id}',
      tags: ['world', choice.intent.name, choice.targetId ?? ''],
    ));
    state.archiveWorldTurn(turn);
    _record('world_choice_${choice.id}', EventKind.system, summary);
    _endDay(summary);
  }

  void _resolveDirectedEvent(String choiceId) {
    final pending = state.pendingDirectedEvent!;
    final outcome = _directedEvents.resolve(state, pending, choiceId);
    state.pendingDirectedEvent = null; // Decision may not be replayed.
    final text = outcome.text;
    state.log = text;
    _record('director_choice_${pending.typeName}_$choiceId',
        EventKind.hazard, text);
    state.rememberStory(StoryMemory(
      key: '${pending.id}_$choiceId',
      day: state.currentDay,
      summary: '${pending.premise} 선택: $choiceId. $text',
      threadId: pending.id,
      tags: ['director', pending.typeName, choiceId],
    ));
    if (state.health <= 0) _die(text);
  }

  void _resolveStory(String choiceId) {
    final resolved = _storySystem.resolve(state, choiceId);
    if (resolved == null) return; // Prevalidated at dispatch boundary.
    state.log = resolved.summary;
    _record('story_choice_$choiceId', EventKind.companion, resolved.summary);
    if (state.health <= 0) _die(resolved.summary);
  }

  GameResult _rejected(String code, int dayBefore) => GameResult(
        accepted: false,
        code: code,
        dayBefore: dayBefore,
        dayAfter: state.daysSurvived,
        events: const <GameEventRecord>[],
      );

  void _record(String id, EventKind kind, String text) {
    final entry = GameEventRecord(
      id: id,
      day: state.currentDay,
      kind: kind,
      text: text,
    );
    state.record(entry);
    state.addChat(ChatRole.world, text, eventId: id);
    _emitted.add(entry);
  }

  void _explore(Zone zone) {
    final site = state.world.siteFor(zone.name);
    // Later days and recent combat noise increase danger, but stay bounded.
    final dayPressure = min(0.15, state.daysSurvived * 0.006);
    final noisePressure = state.noise / 400.0;
    final chance =
        (zone.encounterChance + state.world.dangerOffset + dayPressure + noisePressure)
            .clamp(0.0, 0.95);
    if (_random.nextDouble() < chance) {
      state.encounter = Encounter(
        zone: zone,
        zombies: 1 + _random.nextInt(zone == Zone.apartments ? 3 : 2),
      );
      final text = '$site에서 물자를 찾다가 좀비 '
          '${state.encounter!.zombies}마리와 마주쳤다. 어떻게 할까?';
      state.log = text;
      _record('zombie_encounter', EventKind.exploration, text);
      return;
    }
    final loot = _collectLoot(zone);
    final text = '좀비를 피해 $site을(를) 수색했다. $loot';
    _record('search_success', EventKind.exploration, text);
    _endDay(text);
  }

  void _resolveEncounter(EncounterAction action) {
    final encounter = state.encounter!;
    state.encounter = null; // This encounter cannot be resolved twice.
    final countPenalty = 0.10 * (encounter.zombies - 1);
    late String outcome;
    switch (action) {
      case EncounterAction.fight:
        final rate = (0.57 +
                0.16 * state.weaponLevel -
                countPenalty +
                (state.health >= 60 ? 0.06 : -0.08))
            .clamp(0.05, 0.95);
        state.noise = min(100, state.noise + 18);
        if (_random.nextDouble() < rate) {
          final damage = 4 + _random.nextInt(10);
          state.health -= damage;
          outcome = '좀비를 처치했다. 체력 -$damage. ${_collectLoot(encounter.zone)}';
        } else {
          final damage = 20 + _random.nextInt(21);
          state.health -= damage;
          outcome = '전투에 실패했다. 체력 -$damage. 빈손으로 귀환했다.';
        }
        break;
      case EncounterAction.flee:
        final rate = (0.80 -
                countPenalty +
                (state.health < 35 ? -0.20 : 0.0))
            .clamp(0.05, 0.95);
        if (_random.nextDouble() < rate) {
          outcome = '도주에 성공했다. 물품은 얻지 못했다.';
        } else {
          state.health -= 14;
          state.noise = min(100, state.noise + 8);
          outcome = '도주 중 넘어져 체력 14를 잃었다.';
        }
        break;
      case EncounterAction.sneak:
        final rate = (0.63 - countPenalty).clamp(0.05, 0.95);
        if (_random.nextDouble() < rate) {
          outcome = '은신에 성공했다. ${_collectLoot(encounter.zone)}';
        } else {
          state.health -= 17;
          state.noise = min(100, state.noise + 8);
          outcome = '좀비에게 발각되어 체력 17을 잃었다.';
        }
        break;
    }
    _record('encounter_${action.name}', EventKind.combat, outcome);
    if (state.health <= 0) {
      _die(outcome);
    } else {
      _endDay(outcome);
    }
  }

  void _rest() {
    final healed = min(100 - state.health, state.companion == null ? 12 : 17);
    state.health += healed;
    _npcs.afterRest(state);
    final text = '거점에서 휴식했다. 체력 +$healed.';
    _record('shelter_rest', EventKind.system, text);
    _endDay(text);
  }

  void _useMedicine() {
    state.medicine--;
    final healed = min(100 - state.health, 30);
    state.health += healed;
    final text = '의약품을 사용해 체력 $healed을(를) 회복했다. 하루 행동은 소모되지 않는다.';
    state.log = text;
    _record('medicine_used', EventKind.resource, text);
  }

  void _decideRecruitment(bool accept) {
    state.pendingRecruitment = false;
    if (accept) {
      state.companion = Companion(name: '서윤');
      state.log = '서윤을 받아들였다. 매일 식량과 식수 소모량이 각각 1 증가하지만 '
          '동료의 도움으로 휴식 시 회복량이 늘어난다.';
      state.companion!.remember('플레이어가 자신의 영입을 허락했다.');
    } else {
      state.log = '낯선 생존자를 돌려보냈다. 다시 혼자 남았다.';
    }
    _record(
      accept ? 'companion_joined' : 'companion_refused',
      EventKind.companion,
      state.log,
    );
  }

  String _collectLoot(Zone zone) {
    final amount = 1 + _random.nextInt(3);
    switch (zone) {
      case Zone.market:
        if (_random.nextBool()) {
          state.food += amount;
          return '식량 +$amount';
        }
        state.water += amount;
        return '식수 +$amount';
      case Zone.pharmacy:
        state.medicine += amount;
        return '의약품 +$amount';
      case Zone.apartments:
        if (state.weaponLevel < 2 && _random.nextDouble() < 0.30) {
          state.weaponLevel++;
          return '무기 단계 +1';
        }
        state.food += amount;
        state.water++;
        return '식량 +$amount, 식수 +1';
    }
  }

  void _endDay(String event) {
    final consumption = state.companion == null ? 1 : 2;
    final foodShortage = max(0, consumption - state.food);
    final waterShortage = max(0, consumption - state.water);
    state.food = max(0, state.food - consumption);
    state.water = max(0, state.water - consumption);
    final damage = 10 * foodShortage + 15 * waterShortage;
    state.health -= damage;
    var summary = '$event\n하루가 지났다. 식량 -$consumption, 식수 -$consumption.';
    if (damage > 0) {
      summary += ' 물자 부족으로 체력 -$damage.';
      _record('ration_shortage', EventKind.resource,
          '물자가 부족해 체력 $damage을(를) 잃었다.');
    }

    final npcEvent = _npcs.advanceDay(
      state,
      rationShortage: foodShortage > 0 || waterShortage > 0,
      random: _random,
    );
    if (npcEvent != null) {
      summary += ' ${npcEvent.text}';
      _record(npcEvent.id, EventKind.companion, npcEvent.text);
    }

    if (state.health <= 0) {
      _die(summary);
      return;
    }

    final night = _nightEvents.maybeTrigger(state, _random);
    if (night != null) {
      summary += '\n${night.text}';
      _record(night.id, night.kind, night.text);
    }

    state.noise = max(0, state.noise - 8);
    state.health = state.health.clamp(1, 100).toInt();
    state.daysSurvived++;
    state.bestDays = max(state.bestDays, state.daysSurvived);

    if (!state.interactiveMode && !state.npcMet &&
        state.daysSurvived >= 2 &&
        _random.nextDouble() < 0.35) {
      state.npcMet = true;
      state.pendingRecruitment = true;
      const text = '의료 지식이 있다는 생존자 서윤이 거점 문을 두드린다. '
          '함께 지낼 수 있는지 묻는다.';
      summary += '\n$text';
      _record('companion_appears', EventKind.companion, text);
    }
    // Offer continuing story beats after an ordinary day finishes. The
    // player chooses before the next main action; this costs no extra day.
    if (!state.interactiveMode && !state.waitingForChoice) {
      final beat = _storySystem.maybeOffer(state);
      if (beat != null) {
        summary += '\n' + beat.premise;
        _record('story_${beat.id}', EventKind.system, beat.premise);
      }
    }
    state.log = summary;
  }

  void _die(String story) {
    state.health = 0;
    state.gameOver = true;
    state.encounter = null;
    state.pendingRecruitment = false;
    state.pendingDirectedEvent = null;
    state.bestDays = max(state.bestDays, state.daysSurvived);
    state.log = '$story\n생존 실패. 최종 기록: ${state.daysSurvived}일.';
    _record('player_died', EventKind.system, state.log);
  }
}
