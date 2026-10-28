import 'dart:math';
import 'world_profile.dart';

/// The 'novel bible' for a run: stable facts, possible settings and conflict
/// seeds. An AI director may elaborate scenes but never overwrite these facts.
class ScenarioDefinition {
  const ScenarioDefinition({
    required this.id,
    required this.title,
    required this.premise,
    required this.tone,
    required this.worldIds,
    required this.rules,
    required this.storySeeds,
  });

  final String id;
  final String title;
  final String premise;
  final String tone;
  final List<String> worldIds;
  final List<String> rules;
  final List<String> storySeeds;

  WorldProfile pickWorld(Random random) =>
      WorldProfile.byId(worldIds[random.nextInt(worldIds.length)]);
}

class ScenarioCatalog {
  const ScenarioCatalog._();

  static const openSurvival = ScenarioDefinition(
    id: 'open_survival',
    title: '무너진 일상',
    premise: '좀비 사태로 사회가 무너졌다. 탈출보다는 오늘을 살아남는 것이 목표다.',
    tone: '차갑고 현실적인 생존, 때때로 기이한 인간관계',
    worldIds: ['seoul', 'busan', 'gangwon', 'jeju'],
    rules: [
      '좀비는 소리에 민감하다.',
      '식량과 식수는 하루가 지나면 소비된다.',
      '주인공의 죽음은 되돌릴 수 없다.',
    ],
    storySeeds: ['radio_signal', 'unknown_visitor'],
  );

  static const lostSignal = ScenarioDefinition(
    id: 'lost_signal',
    title: '마지막 송신',
    premise: '도시의 통신망이 붕괴한 뒤, 같은 주파수에서 매일 짧은 구조 신호가 들린다.',
    tone: '서늘한 미스터리, 생존과 불신',
    worldIds: ['seoul', 'busan'],
    rules: [
      '군의 구조 방송은 진짜라는 보장이 없다.',
      '외부와의 통신은 대부분 끊겼다.',
      '좀비는 소리에 민감하다.',
    ],
    storySeeds: ['radio_signal', 'unknown_visitor'],
  );

  static const silentCoast = ScenarioDefinition(
    id: 'silent_coast',
    title: '바다의 끝',
    premise: '해안의 보급선이 끊겼다. 생존자들은 폐쇄된 해안 시설에서 하루하루 버틴다.',
    tone: '고립감, 생존자 사이의 갈등과 희망',
    worldIds: ['busan', 'jeju'],
    rules: [
      '섬이나 항구 밖으로 쉽게 이동할 수 없다.',
      '외부 지원은 기대하기 어렵다.',
      '해안의 시설에는 남겨진 물자가 있다.',
    ],
    storySeeds: ['unknown_visitor', 'radio_signal'],
  );

  static const scenarios = [openSurvival, lostSignal, silentCoast];

  static ScenarioDefinition byId(String? id) {
    for (final scenario in scenarios) {
      if (scenario.id == id) return scenario;
    }
    return openSurvival;
  }
}
