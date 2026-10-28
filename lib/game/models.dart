import 'event_record.dart';

/// Pure Dart game data, independent of Flutter widgets and AI runtimes.
enum Zone { market, pharmacy, apartments }
enum EncounterAction { fight, flee, sneak }
enum NpcTrait { compassionate, pragmatic, cautious }

extension ZoneDetails on Zone {
  String get label => switch (this) {
        Zone.market => '버려진 마트',
        Zone.pharmacy => '폐허가 된 약국',
        Zone.apartments => '텅 빈 아파트',
      };

  String get description => switch (this) {
        Zone.market => '식량·식수 / 낮은 위험',
        Zone.pharmacy => '의약품 / 중간 위험',
        Zone.apartments => '여러 물자 / 높은 위험',
      };

  double get encounterChance => switch (this) {
        Zone.market => 0.40,
        Zone.pharmacy => 0.55,
        Zone.apartments => 0.70,
      };
}

class Encounter {
  const Encounter({required this.zone, required this.zombies});
  final Zone zone;
  final int zombies;

  Map<String, dynamic> toJson() => {
        'zone': zone.name,
        'zombies': zombies,
      };

  factory Encounter.fromJson(Map<String, dynamic> json) => Encounter(
        zone: Zone.values.firstWhere(
          (value) => value.name == json['zone'],
          orElse: () => Zone.market,
        ),
        zombies: (json['zombies'] as num?)?.toInt() ?? 1,
      );
}

class Companion {
  Companion({
    required this.name,
    this.trust = 55,
    this.affection = 20,
    this.trait = NpcTrait.compassionate,
    List<String>? memories,
  }) : memories = memories ?? <String>[];

  final String name;
  int trust;
  int affection;
  final NpcTrait trait;
  final List<String> memories;

  void remember(String event) {
    memories.add(event);
    if (memories.length > 6) memories.removeAt(0);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'trust': trust,
        'affection': affection,
        'trait': trait.name,
        'memories': memories,
      };

  factory Companion.fromJson(Map<String, dynamic> json) => Companion(
        name: json['name'] as String? ?? '생존자',
        trust: (json['trust'] as num?)?.toInt() ?? 55,
        affection: (json['affection'] as num?)?.toInt() ?? 20,
        trait: NpcTrait.values.firstWhere(
          (trait) => trait.name == json['trait'],
          orElse: () => NpcTrait.compassionate,
        ),
        memories: (json['memories'] as List<dynamic>?)
                ?.whereType<String>()
                .take(6)
                .toList() ??
            <String>[],
      );
}

class GameState {
  GameState({
    this.daysSurvived = 0,
    this.bestDays = 0,
    this.health = 100,
    this.food = 5,
    this.water = 5,
    this.medicine = 1,
    this.weaponLevel = 0,
    this.noise = 0,
    this.gameOver = false,
    this.npcMet = false,
    this.pendingRecruitment = false,
    this.encounter,
    this.companion,
    List<GameEventRecord>? journal,
    this.log = '생존 1일차. 바깥에는 좀비가 가득하다. 오늘 무엇을 할까?',
  }) : journal = journal ?? <GameEventRecord>[];

  static const int saveVersion = 2;
  static const int maxJournalEntries = 24;

  int daysSurvived;
  int bestDays;
  int health;
  int food;
  int water;
  int medicine;
  int weaponLevel;
  int noise;
  bool gameOver;
  bool npcMet;
  bool pendingRecruitment;
  Encounter? encounter;
  Companion? companion;
  final List<GameEventRecord> journal;
  String log;

  int get currentDay => daysSurvived + 1;
  bool get waitingForChoice => encounter != null || pendingRecruitment;
  bool get canStartAction => !gameOver && !waitingForChoice;

  void record(GameEventRecord entry) {
    journal.add(entry);
    while (journal.length > maxJournalEntries) {
      journal.removeAt(0);
    }
  }

  Map<String, dynamic> toJson() => {
        'saveVersion': saveVersion,
        'daysSurvived': daysSurvived,
        'bestDays': bestDays,
        'health': health,
        'food': food,
        'water': water,
        'medicine': medicine,
        'weaponLevel': weaponLevel,
        'noise': noise,
        'gameOver': gameOver,
        'npcMet': npcMet,
        'pendingRecruitment': pendingRecruitment,
        'encounter': encounter?.toJson(),
        'companion': companion?.toJson(),
        'journal': journal.map((event) => event.toJson()).toList(),
        'log': log,
      };

  /// v1 saves migrate automatically to v2. Keep this migration path when
  /// extending the schema; do not silently discard player progress.
  factory GameState.fromJson(Map<String, dynamic> json) {
    final version = (json['saveVersion'] as num?)?.toInt();
    if (version != 1 && version != saveVersion) {
      throw const FormatException('지원하지 않는 저장 버전입니다.');
    }
    final encounterJson = json['encounter'];
    final companionJson = json['companion'];
    final rawJournal = json['journal'];
    return GameState(
      daysSurvived: (json['daysSurvived'] as num?)?.toInt() ?? 0,
      bestDays: (json['bestDays'] as num?)?.toInt() ?? 0,
      health: (json['health'] as num?)?.toInt() ?? 100,
      food: (json['food'] as num?)?.toInt() ?? 5,
      water: (json['water'] as num?)?.toInt() ?? 5,
      medicine: (json['medicine'] as num?)?.toInt() ?? 1,
      weaponLevel: (json['weaponLevel'] as num?)?.toInt() ?? 0,
      noise: ((json['noise'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
      gameOver: json['gameOver'] == true,
      npcMet: json['npcMet'] == true,
      pendingRecruitment: json['pendingRecruitment'] == true,
      encounter: encounterJson is Map
          ? Encounter.fromJson(Map<String, dynamic>.from(encounterJson))
          : null,
      companion: companionJson is Map
          ? Companion.fromJson(Map<String, dynamic>.from(companionJson))
          : null,
      journal: rawJournal is List
          ? rawJournal
              .whereType<Map>()
              .map((value) =>
                  GameEventRecord.fromJson(Map<String, dynamic>.from(value)))
              .toList()
              .reversed
              .take(maxJournalEntries)
              .toList()
              .reversed
              .toList()
          : <GameEventRecord>[],
      log: json['log'] as String? ?? '생존을 시작합니다.',
    );
  }
}
