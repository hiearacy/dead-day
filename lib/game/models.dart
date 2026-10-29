import 'dart:math';
import 'chat_message.dart';
import 'generated_world_element.dart';
import 'story_turn.dart';
import 'directed_event_choice.dart';
import 'event_record.dart';
import 'world_profile.dart';
import 'scenario_definition.dart';
import 'story_memory.dart';

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
    WorldProfile? world,
    ScenarioDefinition? scenario,
    List<StoryMemory>? storyMemories,
    List<StoryThread>? storyThreads,
    this.pendingStory,
    this.pendingDirectedEvent,
    this.pendingWorldTurn,
    this.interactiveMode = false,
    String? currentLocationId,
    List<GeneratedWorldElement>? generatedElements,
    List<StoryTurn>? recentWorldTurns,
    this.latestChoiceSummary = '',
    List<ChatMessage>? messages,
    this.messageSerial = 0,
    this.lastDirectedEventDay = -1,
    this.gameOver = false,
    this.npcMet = false,
    this.pendingRecruitment = false,
    this.encounter,
    this.companion,
    List<GameEventRecord>? journal,
    this.log = '생존 1일차. 바깥에는 좀비가 가득하다. 오늘 무엇을 할까?',
  }) : world = world ?? WorldProfile.seoul,
       currentLocationId = currentLocationId ??
           'start_${(world ?? WorldProfile.seoul).id}',
       generatedElements = generatedElements ?? <GeneratedWorldElement>[],
       recentWorldTurns = recentWorldTurns ?? <StoryTurn>[],
       scenario = scenario ?? ScenarioCatalog.openSurvival,
       storyMemories = storyMemories ?? <StoryMemory>[],
       storyThreads = storyThreads ?? <StoryThread>[],
       messages = messages ?? <ChatMessage>[],
       journal = journal ?? <GameEventRecord>[];

  static const int saveVersion = 6;
  static const int maxRecentWorldTurns = 4;
  static const int maxStoryMemories = 12;
  static const int maxChatMessages = 80;

  factory GameState.newRun({Random? random, int bestDays = 0,
      String scenarioId = 'open_survival'}) {
    final rng = random ?? Random();
    final scenario = ScenarioCatalog.byId(scenarioId);
    final place = scenario.pickWorld(rng);
    return GameState(
      world: place,
      scenario: scenario,
      interactiveMode: true,
      bestDays: bestDays,
      food: place.food,
      water: place.water,
      log: '${scenario.premise}\n${place.intro}',
      messageSerial: 1,
      messages: <ChatMessage>[
        ChatMessage(
          id: 'm1', day: 1, role: ChatRole.world,
          text: '${scenario.premise}\n${place.intro}',
        ),
      ],
    );
  }
  static const int maxJournalEntries = 24;

  int daysSurvived;
  int bestDays;
  int health;
  int food;
  int water;
  int medicine;
  int weaponLevel;
  int noise;
  final WorldProfile world;
  final ScenarioDefinition scenario;
  final List<StoryMemory> storyMemories;
  final List<StoryThread> storyThreads;
  StoryBeat? pendingStory;
  PendingDirectedEvent? pendingDirectedEvent;
  StoryTurn? pendingWorldTurn;
  bool interactiveMode;
  String currentLocationId;
  final List<GeneratedWorldElement> generatedElements;
  final List<StoryTurn> recentWorldTurns;
  String latestChoiceSummary;
  final List<ChatMessage> messages;
  int messageSerial;
  int lastDirectedEventDay;
  bool gameOver;
  bool npcMet;
  bool pendingRecruitment;
  Encounter? encounter;
  Companion? companion;
  final List<GameEventRecord> journal;
  String log;

  int get currentDay => daysSurvived + 1;
  bool get waitingForChoice =>
      encounter != null || pendingRecruitment || pendingStory != null ||
      pendingDirectedEvent != null || pendingWorldTurn != null;
  bool get canStartAction => !gameOver && !waitingForChoice;

  void addChat(ChatRole role, String text, {String? speaker, String? eventId}) {
    messageSerial++;
    messages.add(ChatMessage(
      id: 'm$messageSerial', day: currentDay,
      role: role, text: text, speaker: speaker, sourceEventId: eventId,
    ));
    while (messages.length > maxChatMessages) {
      messages.removeAt(0);
    }
  }

  void archiveWorldTurn(StoryTurn turn) {
    recentWorldTurns.add(turn);
    while (recentWorldTurns.length > maxRecentWorldTurns) {
      recentWorldTurns.removeAt(0);
    }
  }

  void rememberStory(StoryMemory memory) {
    storyMemories.add(memory);
    while (storyMemories.length > maxStoryMemories) {
      storyMemories.removeAt(0);
    }
  }

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
        'world': world.toJson(),
        'scenarioId': scenario.id,
        'storyMemories': storyMemories.map((m) => m.toJson()).toList(),
        'storyThreads': storyThreads.map((t) => t.toJson()).toList(),
        'pendingStory': pendingStory?.toJson(),
        'pendingDirectedEvent': pendingDirectedEvent?.toJson(),
        'interactiveMode': interactiveMode,
        'pendingWorldTurn': pendingWorldTurn?.toJson(),
        'currentLocationId': currentLocationId,
        'generatedElements': generatedElements.map((e) => e.toJson()).toList(),
        'recentWorldTurns': recentWorldTurns.map((t) => t.toJson()).toList(),
        'latestChoiceSummary': latestChoiceSummary,
        'messages': messages.map((message) => message.toJson()).toList(),
        'messageSerial': messageSerial,
        'lastDirectedEventDay': lastDirectedEventDay,
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
    if (version != 1 && version != 2 && version != 3 &&
        version != 4 && version != 5 && version != saveVersion) {
      throw const FormatException('지원하지 않는 저장 버전입니다.');
    }
    final encounterJson = json['encounter'];
    final companionJson = json['companion'];
    final rawJournal = json['journal'];
    final rawMessages = json['messages'];
    final rawWorld = json['world'];
    final rawMemories = json['storyMemories'];
    final rawThreads = json['storyThreads'];
    final rawPendingStory = json['pendingStory'];
    final rawDirectedEvent = json['pendingDirectedEvent'];
    final rawWorldTurn = json['pendingWorldTurn'];
    final rawGeneratedElements = json['generatedElements'];
    final rawRecentTurns = json['recentWorldTurns'];
    return GameState(
      daysSurvived: (json['daysSurvived'] as num?)?.toInt() ?? 0,
      bestDays: (json['bestDays'] as num?)?.toInt() ?? 0,
      health: (json['health'] as num?)?.toInt() ?? 100,
      food: (json['food'] as num?)?.toInt() ?? 5,
      water: (json['water'] as num?)?.toInt() ?? 5,
      medicine: (json['medicine'] as num?)?.toInt() ?? 1,
      weaponLevel: (json['weaponLevel'] as num?)?.toInt() ?? 0,
      noise: ((json['noise'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
      world: WorldProfile.byId(rawWorld is Map ? rawWorld['id'] as String? : null),
      scenario: ScenarioCatalog.byId(json['scenarioId'] as String?),
      interactiveMode: json['interactiveMode'] == true,
      currentLocationId: json['currentLocationId'] as String?,
      latestChoiceSummary: json['latestChoiceSummary'] as String? ?? '',
      pendingWorldTurn: rawWorldTurn is Map
          ? StoryTurn.fromJson(Map<String, dynamic>.from(rawWorldTurn))
          : null,
      generatedElements: rawGeneratedElements is List
          ? rawGeneratedElements.whereType<Map>().map((e) =>
              GeneratedWorldElement.fromJson(Map<String, dynamic>.from(e)))
              .take(50).toList()
          : <GeneratedWorldElement>[],
      recentWorldTurns: rawRecentTurns is List
          ? rawRecentTurns.whereType<Map>().map((e) =>
              StoryTurn.fromJson(Map<String, dynamic>.from(e)))
              .toList().reversed.take(maxRecentWorldTurns).toList()
              .reversed.toList()
          : <StoryTurn>[],
      storyMemories: rawMemories is List
          ? rawMemories.whereType<Map>()
              .map((value) => StoryMemory.fromJson(Map<String, dynamic>.from(value)))
              .toList().reversed.take(maxStoryMemories).toList().reversed.toList()
          : <StoryMemory>[],
      storyThreads: rawThreads is List
          ? rawThreads.whereType<Map>()
              .map((value) => StoryThread.fromJson(Map<String, dynamic>.from(value)))
              .toList()
          : <StoryThread>[],
      pendingStory: rawPendingStory is Map
          ? StoryBeat.fromJson(Map<String, dynamic>.from(rawPendingStory))
          : null,
      pendingDirectedEvent: rawDirectedEvent is Map
          ? PendingDirectedEvent.fromJson(
              Map<String, dynamic>.from(rawDirectedEvent))
          : null,
      messageSerial: (json['messageSerial'] as num?)?.toInt() ?? 0,
      lastDirectedEventDay: (json['lastDirectedEventDay'] as num?)?.toInt() ?? -1,
      messages: rawMessages is List
          ? rawMessages.whereType<Map>()
              .map((value) => ChatMessage.fromJson(Map<String, dynamic>.from(value)))
              .toList().reversed.take(maxChatMessages).toList().reversed.toList()
          : <ChatMessage>[],
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
