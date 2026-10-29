import 'dart:convert';
import 'dart:math';
import '../game/models.dart';
import '../game/story_turn.dart';
import '../game/generated_world_element.dart';

/// Compact, bounded view of the current world. Never send full chat history.
class StoryContext {
  const StoryContext(this.data);
  final Map<String, dynamic> data;

  factory StoryContext.fromGame(GameState state) => StoryContext({
        'scenario': {
          'id': state.scenario.id,
          'title': state.scenario.title,
          'premise': state.scenario.premise,
          'tone': state.scenario.tone,
          'rules': state.scenario.rules.take(6).toList(),
          'seeds': state.scenario.storySeeds.take(8).toList(),
        },
        'day': state.currentDay,
        'location_id': state.currentLocationId,
        'location_name': state.generatedElements
            .where((v) => v.id == state.currentLocationId)
            .map((v) => v.name)
            .firstOrNull ?? state.world.shelter,
        'region': state.world.label,
        'player': {
          'health': state.health,
          'food': state.food,
          'water': state.water,
          'medicine': state.medicine,
        },
        'characters': [
          if (state.companion != null)
            {
              'name': state.companion!.name,
              'trust': state.companion!.trust,
              'trait': state.companion!.trait.name,
            },
        ],
        'generated_element_count': state.generatedElements.length,
        'generated_elements': state.generatedElements.reversed
            .take(15).toList().reversed.map((v) => {
              'id': v.id, 'name': v.name, 'kind': v.kind.name,
              'description': v.description, 'parentId': v.parentId,
            }).toList(),
        'memories': state.storyMemories.reversed
            .take(8).map((v) => v.summary).toList(),
        'unresolved_threads': state.storyThreads
            .where((v) => !v.closed).take(4)
            .map((v) => {'id': v.id, 'decision': v.decision, 'stage': v.stage})
            .toList(),
        'recent_turns': state.recentWorldTurns.reversed.take(3).map((v) =>
          {'id': v.id, 'story': v.story.length > 220
              ? v.story.substring(0, 220) : v.story}).toList(),
        'latest_choice': state.latestChoiceSummary,
      });

  String toJson() => jsonEncode(data);
}

abstract class WorldStoryProvider {
  Future<StoryTurn> generate(StoryContext context);
}

/// Offline, no-secret fallback. It runs the SAME validator and rule engine
/// as Gemini; it is deliberately simple rather than pretending to be an LLM.
class ProceduralWorldStoryProvider implements WorldStoryProvider {
  ProceduralWorldStoryProvider({Random? random}) : _rng = random ?? Random();
  final Random _rng;

  @override
  Future<StoryTurn> generate(StoryContext context) async {
    final day = (context.data['day'] as num).toInt();
    final region = context.data['region'] as String;
    final location = context.data['location_name'] as String;
    final count = (context.data['generated_element_count'] as num).toInt();
    final latest = context.data['latest_choice'] as String? ?? '';
    final id = 'world_turn_${day}_${count}_fallback';
    final newId = 'discovery_${day}_${count}';
    final name = ['폐쇄된 통제실', '비상 계단', '봉쇄된 보급실']
        [_rng.nextInt(3)];
    final element = GeneratedWorldElement(
      id: newId, name: '$region $name',
      kind: WorldElementKind.location,
      description: '조사를 계속할 수 있는 폐쇄된 공간.',
      parentId: context.data['location_id'] as String,
      createdDay: day,
    );
    final canExpand = count < 480;
    return StoryTurn(
      id: id,
      story: '$location에서 ${latest.isEmpty ? '낯선 금속성 소음' : '이전 행동의 흔적'}이 '
          '느껴진다. 복도 끝에서 $name 표지판이 발견되었다. '
          '안쪽에서 약한 빛이 새어 나온다.',
      choices: [
        if (canExpand)
          TurnChoice(id: 'move', text: '$name 쪽으로 이동한다',
              intent: StoryIntent.move, targetId: newId)
        else
          const TurnChoice(id: 'talk', text: '주변에 사람이 있는지 확인한다',
              intent: StoryIntent.talk),
        const TurnChoice(id: 'investigate', text: '주변 흔적을 조사한다',
            intent: StoryIntent.investigate),
        const TurnChoice(id: 'observe', text: '안전한 곳에서 지켜본다',
            intent: StoryIntent.observe),
      ],
      generatedElements: canExpand ? [element] : [],
    );
  }
}

class FallbackWorldStoryProvider implements WorldStoryProvider {
  const FallbackWorldStoryProvider(this.primary, this.fallback);
  final WorldStoryProvider primary;
  final WorldStoryProvider fallback;

  @override
  Future<StoryTurn> generate(StoryContext context) async {
    try {
      return await primary.generate(context);
    } catch (_) {
      return fallback.generate(context);
    }
  }
}
