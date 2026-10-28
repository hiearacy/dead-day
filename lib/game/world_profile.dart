import 'dart:math';

/// A small catalog of starting environments. Game rules use the profile
/// properties, not hardcoded city names or narrative strings.
enum Biome { metropolis, port, mountain, island }

class WorldProfile {
  const WorldProfile({
    required this.id,
    required this.label,
    required this.shelter,
    required this.biome,
    required this.intro,
    required this.food,
    required this.water,
    required this.dangerOffset,
  });

  final String id;
  final String label;
  final String shelter;
  final Biome biome;
  final String intro;
  final int food;
  final int water;
  final double dangerOffset;

  Map<String, dynamic> toJson() => {'id': id};

  static const seoul = WorldProfile(
    id: 'seoul', label: '서울', shelter: '버려진 주거용 건물',
    biome: Biome.metropolis,
    intro: '도시가 멈췄다. 창밖 도로에는 폐차와 좀비가 가득하다.',
    food: 5, water: 5, dangerOffset: 0.08,
  );
  static const busan = WorldProfile(
    id: 'busan', label: '부산', shelter: '항구 근처 창고',
    biome: Biome.port,
    intro: '항구의 경적 소리가 끊겼다. 밀려온 컨테이너 뒤에서 움직임이 보인다.',
    food: 6, water: 4, dangerOffset: 0.02,
  );
  static const gangwon = WorldProfile(
    id: 'gangwon', label: '강원 산간', shelter: '외딴 산장',
    biome: Biome.mountain,
    intro: '산 아래 도로는 끊겼다. 숲은 고요하지만 보급로가 멀다.',
    food: 4, water: 7, dangerOffset: -0.07,
  );
  static const jeju = WorldProfile(
    id: 'jeju', label: '제주', shelter: '해안가 민가',
    biome: Biome.island,
    intro: '바다로 떠날 배가 없다. 외부와의 연락은 완전히 끊겼다.',
    food: 5, water: 6, dangerOffset: -0.03,
  );

  static const List<WorldProfile> choices = [seoul, busan, gangwon, jeju];

  static WorldProfile random(Random random) =>
      choices[random.nextInt(choices.length)];

  static WorldProfile byId(String? id) {
    for (final place in choices) {
      if (place.id == id) return place;
    }
    return seoul; // Old saves have an implicit Seoul background.
  }
}
