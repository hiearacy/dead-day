import 'dart:math';
import '../ai/event_director.dart';
import 'models.dart';

/// Validates model-proposed situations before the engine accepts them.
/// Mechanical effects are deliberately finite, regardless of generated prose.
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
    if (premise.length < 8 || premise.length > 180 ||
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
    if (proposal.type == DirectedEventType.taintedWater &&
        state.water <= 0) {
      return 'no_water';
    }
    return null;
  }

  /// An exceptionally rare unsettling situation, never a forced outcome.
  bool passesRarity(EventProposal proposal, Random random) {
    if (proposal.type != DirectedEventType.unsettlingEncounter) return true;
    return random.nextDouble() < 0.002; // 0.2% of eligible proposals.
  }

  String apply(GameState state, EventProposal proposal) {
    switch (proposal.type) {
      case DirectedEventType.hiddenSupplies:
        state.food++;
        return '주변을 조사해 식량 한 개를 발견했다.';
      case DirectedEventType.taintedWater:
        state.water--;
        return '오염된 식수를 확인해 한 개를 폐기했다.';
      case DirectedEventType.strangeBroadcast:
        state.noise = min(100, state.noise + 4);
        return '수상한 신호를 확인하는 동안 소음이 조금 증가했다.';
      case DirectedEventType.strangerAtDoor:
        state.noise = min(100, state.noise + 2);
        return '낯선 방문자를 경계하며 거점을 점검했다.';
      case DirectedEventType.companionConflict:
        final npc = state.companion!;
        npc.trust = max(0, npc.trust - 5);
        npc.remember('의견 충돌로 신뢰가 흔들렸다.');
        return '${npc.name}과(와)의 갈등으로 신뢰도 5를 잃었다.';
      case DirectedEventType.unsettlingEncounter:
        state.noise = min(100, state.noise + 7);
        return '기묘하고 위협적인 상황에서 조심스럽게 거점 경계를 강화했다.';
    }
  }
}
