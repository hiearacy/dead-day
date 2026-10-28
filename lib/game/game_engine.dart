import 'dart:math';
import 'models.dart';

/// Source of truth for outcomes, survival rules, and NPC state transitions.
/// The AI narrator never mutates this engine.
class GameEngine {
  GameEngine({GameState? initialState, Random? random})
      : state = initialState ?? GameState(),
        _random = random ?? Random();

  final GameState state;
  final Random _random;

  void explore(Zone zone) {
    if (!state.canStartAction) return;
    if (_random.nextDouble() < zone.encounterChance) {
      state.encounter = Encounter(
        zone: zone,
        zombies: 1 + _random.nextInt(zone == Zone.apartments ? 3 : 2),
      );
      state.log = zone.label + '에서 물자를 찾던 중 좀비 ' +
          state.encounter!.zombies.toString() + '마리와 마주쳤다. 어떻게 할까?';
      return;
    }
    _endDay('좀비를 피해 ' + zone.label + '을(를) 수색했다. ' + _collectLoot(zone));
  }

  void resolveEncounter(EncounterAction action) {
    final encounter = state.encounter;
    if (state.gameOver || encounter == null) return;
    // Clear pending action before resolving, preventing a double resolution.
    state.encounter = null;
    final countPenalty = 0.10 * (encounter.zombies - 1);
    late String outcome;
    switch (action) {
      case EncounterAction.fight:
        final rate = (0.57 + 0.16 * state.weaponLevel - countPenalty +
                (state.health >= 60 ? 0.06 : -0.08))
            .clamp(0.05, 0.95);
        if (_random.nextDouble() < rate) {
          final damage = 4 + _random.nextInt(10);
          state.health -= damage;
          outcome = '좀비를 처치했다. 체력 -' + damage.toString() +
              '. ' + _collectLoot(encounter.zone);
        } else {
          final damage = 20 + _random.nextInt(21);
          state.health -= damage;
          outcome = '전투에 실패했다. 체력 -' + damage.toString() +
              '. 빈손으로 귀환했다.';
        }
        break;
      case EncounterAction.flee:
        final rate = (0.80 - countPenalty +
                (state.health < 35 ? -0.20 : 0.0))
            .clamp(0.05, 0.95);
        if (_random.nextDouble() < rate) {
          outcome = '도주에 성공했다. 물품은 얻지 못했다.';
        } else {
          state.health -= 14;
          outcome = '도주 중 넘어져 체력 14를 잃었다.';
        }
        break;
      case EncounterAction.sneak:
        final rate = (0.63 - countPenalty).clamp(0.05, 0.95);
        if (_random.nextDouble() < rate) {
          outcome = '은신에 성공했다. ' + _collectLoot(encounter.zone);
        } else {
          state.health -= 17;
          outcome = '좀비에게 발각되어 체력 17을 잃었다.';
        }
        break;
    }
    if (state.health <= 0) {
      _die(outcome);
    } else {
      _endDay(outcome);
    }
  }

  void rest() {
    if (!state.canStartAction) return;
    final healed = min(100 - state.health, state.companion == null ? 12 : 17);
    state.health += healed;
    if (state.companion != null) {
      state.companion!.trust = min(100, state.companion!.trust + 2);
    }
    _endDay('거점에서 휴식했다. 체력 +' + healed.toString() + '.');
  }

  void useMedicine() {
    if (!state.canStartAction || state.medicine <= 0 || state.health >= 100) {
      return;
    }
    state.medicine--;
    final healed = min(100 - state.health, 30);
    state.health += healed;
    state.log = '의약품을 사용해 체력 ' + healed.toString() +
        '을(를) 회복했다. (하루 행동은 소모되지 않는다.)';
  }

  void decideRecruitment(bool accept) {
    if (state.gameOver || !state.pendingRecruitment) return;
    state.pendingRecruitment = false;
    if (accept) {
      state.companion = Companion(name: '서윤');
      state.log = '서윤을 받아들였다. 하루 식량과 식수 소모량이 각각 1 증가하지만 '
          '동료의 치료 보조로 휴식 시 회복량이 늘어난다.';
    } else {
      state.log = '낯선 생존자를 돌려보냈다. 다시 혼자 남았다.';
    }
  }

  String _collectLoot(Zone zone) {
    final amount = 1 + _random.nextInt(3);
    switch (zone) {
      case Zone.market:
        if (_random.nextBool()) {
          state.food += amount;
          return '식량 +' + amount.toString();
        }
        state.water += amount;
        return '식수 +' + amount.toString();
      case Zone.pharmacy:
        state.medicine += amount;
        return '의약품 +' + amount.toString();
      case Zone.apartments:
        if (state.weaponLevel < 2 && _random.nextDouble() < 0.30) {
          state.weaponLevel++;
          return '무기 단계 +1';
        }
        state.food += amount;
        state.water++;
        return '식량 +' + amount.toString() + ', 식수 +1';
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
    var summary = event + '\n하루가 지났다. 식량 -' +
        consumption.toString() + ', 식수 -' + consumption.toString() + '.';
    if (damage > 0) {
      summary += ' 물자 부족으로 체력 -' + damage.toString() + '.';
    }

    final npc = state.companion;
    if (npc != null) {
      if (foodShortage > 0 || waterShortage > 0) {
        npc.trust = max(0, npc.trust - 15);
        summary += ' 서윤은 배급 부족에 불만을 드러냈다.';
      } else {
        npc.trust = min(100, npc.trust + 1);
      }
      if (npc.trust < 25 &&
          (foodShortage > 0 || waterShortage > 0) &&
          _random.nextDouble() < 0.35) {
        if (state.medicine > 0) state.medicine--;
        state.companion = null;
        summary += ' 새벽에 서윤이 의약품을 챙겨 거점을 떠났다.';
      }
    }

    if (state.health <= 0) {
      _die(summary);
      return;
    }
    state.health = state.health.clamp(1, 100).toInt();
    state.daysSurvived++;
    state.bestDays = max(state.bestDays, state.daysSurvived);

    if (!state.npcMet &&
        state.daysSurvived >= 2 &&
        _random.nextDouble() < 0.35) {
      state.npcMet = true;
      state.pendingRecruitment = true;
      summary += '\n누군가 거점 문을 두드린다. 의료 지식이 있다는 생존자 '
          '서윤이 함께 지낼 수 있는지 묻는다.';
    }
    state.log = summary;
  }

  void _die(String story) {
    state.health = 0;
    state.gameOver = true;
    state.encounter = null;
    state.pendingRecruitment = false;
    state.bestDays = max(state.bestDays, state.daysSurvived);
    state.log = story + '\n생존 실패. 최종 기록: ' +
        state.daysSurvived.toString() + '일.';
  }
}
