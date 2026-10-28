import 'dart:math';
import 'models.dart';

/// Compact deterministic NPC behavior driven by needs and trust.
/// This is the safe fallback even when optional local AI is unavailable.
class NpcDayOutcome {
  const NpcDayOutcome(this.id, this.text);
  final String id;
  final String text;
}

class NpcSystem {
  const NpcSystem();

  void afterRest(GameState state) {
    final npc = state.companion;
    if (npc == null) return;
    npc.trust = min(100, npc.trust + 2);
    if (npc.trust >= 60) npc.affection = min(100, npc.affection + 1);
    npc.remember('플레이어가 거점에서 함께 휴식했다.');
  }

  NpcDayOutcome? advanceDay(
    GameState state, {
    required bool rationShortage,
    required Random random,
  }) {
    final npc = state.companion;
    if (npc == null) return null;
    if (rationShortage) {
      npc.trust = max(0, npc.trust - 15);
      npc.remember('먹거나 마실 것이 부족해 하루를 힘겹게 보냈다.');
      if (npc.trust < 25 && random.nextDouble() < 0.35) {
        if (state.medicine > 0) state.medicine--;
        state.companion = null;
        return NpcDayOutcome(
          'companion_departed',
          '${npc.name}은(는) 남은 의약품을 챙겨 거점을 떠났다.',
        );
      }
      return NpcDayOutcome(
        'companion_protests',
        '${npc.name}이(가) 배급 부족에 불만을 드러냈다. 신뢰도 -15.',
      );
    }
    npc.trust = min(100, npc.trust + 1);
    return null;
  }
}
