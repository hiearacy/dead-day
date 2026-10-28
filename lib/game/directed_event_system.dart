import 'dart:math';
import '../ai/event_director.dart';
import 'directed_event_choice.dart';
import 'models.dart';

/// The AI only chooses a situation. The rulebook supplies options and results.
class DirectedResolution {
  const DirectedResolution(this.text);
  final String text;
}

class DirectedEventSystem {
  const DirectedEventSystem();

  String? rejection(GameState state, EventProposal proposal) {
    if (state.gameOver || state.waitingForChoice || state.daysSurvived < 1) {
      return 'unsafe_game_phase';
    }
    if (state.lastDirectedEventDay == state.daysSurvived) {
      return 'event_already_generated';
    }
    if (proposal.locationId != null &&
        proposal.locationId != state.world.id) {
      return 'location_mismatch';
    }
    final premise = proposal.premise.trim();
    if (premise.length < 8 ||
        premise.length > 180 ||
        premise.contains(RegExp(r'[\u0000-\u001f]'))) {
      return 'invalid_premise';
    }
    if (proposal.type == DirectedEventType.companionConflict) {
      if (state.companion == null) return 'companion_missing';
      if (proposal.npcName != null &&
          proposal.npcName != state.companion!.name) {
        return 'npc_mismatch';
      }
    }
    if (proposal.type == DirectedEventType.taintedWater && state.water <= 0) {
      return 'no_water';
    }
    return null;
  }

  /// The 0.2% gate applies to eligible unsettling proposals, independently
  /// from any sampling performed by the procedural or cloud director.
  bool passesRarity(EventProposal proposal, Random random) {
    if (proposal.type != DirectedEventType.unsettlingEncounter) return true;
    return random.nextDouble() < 0.002;
  }

  PendingDirectedEvent offer(GameState state, EventProposal proposal) {
    return PendingDirectedEvent(
      id: 'director_${proposal.type.name}_${state.daysSurvived}',
      typeName: proposal.type.name,
      premise: proposal.premise.trim(),
      locationId: state.world.id,
      npcName: proposal.npcName,
      createdDay: state.currentDay,
      choices: _choices(state, proposal.type),
    );
  }

  List<DirectedChoice> _choices(GameState state, DirectedEventType type) {
    switch (type) {
      case DirectedEventType.hiddenSupplies:
        return const [
          DirectedChoice(id: 'inspect', label: '조심스럽게 상자를 조사한다'),
          DirectedChoice(id: 'leave', label: '수상하니 그대로 둔다'),
        ];
      case DirectedEventType.taintedWater:
        return [
          const DirectedChoice(id: 'discard', label: '물을 버리고 안전을 택한다'),
          const DirectedChoice(id: 'risk', label: '물을 버리지 않고 위험을 감수한다'),
          if (state.medicine > 0)
            const DirectedChoice(id: 'purify', label: '의약품을 소모해 소독을 시도한다'),
        ];
      case DirectedEventType.strangeBroadcast:
        return const [
          DirectedChoice(id: 'listen', label: '주파수를 기록한다'),
          DirectedChoice(id: 'off', label: '라디오를 끈다'),
        ];
      case DirectedEventType.strangerAtDoor:
        return [
          if (state.food > 0)
            const DirectedChoice(id: 'share', label: '식량 한 개를 건네준다'),
          const DirectedChoice(id: 'refuse', label: '문을 잠그고 돌려보낸다'),
        ];
      case DirectedEventType.companionConflict:
        return const [
          DirectedChoice(id: 'talk', label: '동료의 이야기를 듣는다'),
          DirectedChoice(id: 'dismiss', label: '갈등을 일단 무시한다'),
        ];
      case DirectedEventType.unsettlingEncounter:
        return const [
          DirectedChoice(id: 'barricade', label: '문을 막고 몸을 숨긴다'),
          DirectedChoice(id: 'investigate', label: '위험을 감수하고 확인한다'),
        ];
    }
  }

  /// Called only after the engine has verified that the option belongs to
  /// the unresolved event. The choice determines ALL mechanical changes.
  DirectedResolution resolve(
    GameState state,
    PendingDirectedEvent pending,
    String choiceId,
  ) {
    final type = DirectedEventType.values.firstWhere(
      (candidate) => candidate.name == pending.typeName,
    );
    switch (type) {
      case DirectedEventType.hiddenSupplies:
        if (choiceId == 'inspect') {
          state.food++;
          state.noise = min(100, state.noise + 4);
          return const DirectedResolution('수상한 상자를 열었다. 식량 +1, 소음 +4.');
        }
        return const DirectedResolution('상자를 건드리지 않고 자리를 떠났다.');
      case DirectedEventType.taintedWater:
        if (choiceId == 'discard') {
          state.water--;
          return const DirectedResolution('오염된 식수를 폐기했다. 식수 -1.');
        }
        if (choiceId == 'purify') {
          state.medicine--;
          return const DirectedResolution('소독에 의약품 하나를 사용했다. 의약품 -1.');
        }
        state.health = max(0, state.health - 10);
        return const DirectedResolution('물을 보관했지만 몸 상태가 나빠졌다. 체력 -10.');
      case DirectedEventType.strangeBroadcast:
        if (choiceId == 'listen') {
          state.noise = min(100, state.noise + 7);
          return const DirectedResolution(
            '주파수와 반복되는 숫자를 기록했다. 단서를 얻었지만 소음 +7.',
          );
        }
        state.noise = max(0, state.noise - 4);
        return const DirectedResolution('라디오를 껐다. 주변이 조금 조용해졌다.');
      case DirectedEventType.strangerAtDoor:
        if (choiceId == 'share') {
          state.food--;
          return const DirectedResolution(
            '식량을 건넸다. 방문자는 감사하다고 말하고 떠났다. 식량 -1.',
          );
        }
        state.noise = min(100, state.noise + 4);
        return const DirectedResolution(
          '문을 열지 않았다. 방문자가 몇 번 더 문을 두드린 뒤 떠났다. 소음 +4.',
        );
      case DirectedEventType.companionConflict:
        final companion = state.companion!;
        if (choiceId == 'talk') {
          companion.trust = min(100, companion.trust + 5);
          companion.remember('플레이어가 자신의 불만을 끝까지 들어주었다.');
          return DirectedResolution('${companion.name}의 말을 들었다. 신뢰 +5.');
        }
        companion.trust = max(0, companion.trust - 8);
        companion.remember('플레이어가 자신의 불만을 무시했다.');
        return DirectedResolution('${companion.name}이(가) 실망했다. 신뢰 -8.');
      case DirectedEventType.unsettlingEncounter:
        if (choiceId == 'barricade') {
          state.noise = min(100, state.noise + 6);
          return const DirectedResolution('입구를 막고 상황을 지켜봤다. 소음 +6.');
        }
        state.health = max(0, state.health - 9);
        return const DirectedResolution(
          '조사 과정에서 상처를 입었다. 체력 -9.',
        );
    }
  }
}
