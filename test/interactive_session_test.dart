import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/data/save_service.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/ai/world_story_provider.dart';
import 'package:dead_day/app/game_controller.dart';
import 'package:dead_day/game/generated_world_element.dart';
import 'package:dead_day/game/story_turn.dart';

/// A fake LLM that exercises the real GameController, GameEngine and save
/// service, without making API calls or needing Flutter widget animations.
class RepeatableStoryProvider implements WorldStoryProvider {
  int calls = 0;

  @override
  Future<StoryTurn> generate(StoryContext context) async {
    calls++;
    final day = (context.data['day'] as num).toInt();
    final currentLocation = context.data['location_id'] as String;
    final locationId = 'session_location_$day';
    return StoryTurn(
      id: 'session_story_$day',
      story: '무너진 복도의 반대편에서 희미한 불빛이 보인다. '
          '새로운 방으로 연결된 문이 반쯤 열려 있다. '
          '멀리서 정체를 알 수 없는 발소리가 들려온다.',
      choices: [
        TurnChoice(
          id: 'go', text: '새로운 방으로 이동한다',
          intent: StoryIntent.move, targetId: locationId,
        ),
        const TurnChoice(
          id: 'check', text: '주변의 위험을 먼저 조사한다',
          intent: StoryIntent.investigate,
        ),
        const TurnChoice(
          id: 'wait', text: '안전한 곳에서 상황을 지켜본다',
          intent: StoryIntent.observe,
        ),
      ],
      generatedElements: [
        GeneratedWorldElement(
          id: locationId, name: '생존 $day일차 비밀 통로',
          kind: WorldElementKind.location,
          description: '한 번 발견하면 저장되는 세계의 새로운 장소.',
          parentId: currentLocation, createdDay: day,
        ),
      ],
    );
  }
}

/// Snapshotting in-memory save adapter for deterministic controller tests.
class MemorySaveService extends SaveService {
  GameState? _saved;

  @override
  Future<GameState?> load() async =>
      _saved == null ? null : GameState.fromJson(_saved!.toJson());

  @override
  Future<void> save(GameState state) async {
    _saved = GameState.fromJson(state.toJson());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('six-turn scenario persists generated world and resumes after restart',
      () async {
    final saves = MemorySaveService();
    final provider = RepeatableStoryProvider();
    final controller = GameController(saves: saves, worldStoryProvider: provider);
    await controller.initialize();

    expect(provider.calls, 1);
    expect(controller.state.pendingWorldTurn?.choices.length, 3);
    expect(controller.state.generatedElements.length, 1);

    // Real UI would invoke this for each player choice.
    for (var turn = 1; turn <= 3; turn++) {
      await controller.chooseWorldTurn('go');
      expect(controller.state.daysSurvived, turn);
      expect(controller.state.currentLocationId, 'session_location_$turn');
      expect(controller.state.pendingWorldTurn, isNotNull);
      expect(controller.state.generatedElements.length, turn + 1);
    }
    expect(controller.state.storyMemories.length, 3);
    expect(provider.calls, 4);
    controller.dispose();

    // The existing pending turn must not be silently rerolled on app restart.
    final resumed = GameController(saves: saves, worldStoryProvider: provider);
    await resumed.initialize();
    expect(provider.calls, 4);
    expect(resumed.state.pendingWorldTurn?.id, 'session_story_4');
    expect(resumed.state.generatedElements.length, 4);
    expect(resumed.state.currentLocationId, 'session_location_3');
    expect(resumed.state.storyMemories.length, 3);

    for (var turn = 4; turn <= 6; turn++) {
      await resumed.chooseWorldTurn('go');
      expect(resumed.state.daysSurvived, turn);
      expect(resumed.state.generatedElements.length, turn + 1);
    }
    expect(provider.calls, 7);
    expect(resumed.state.pendingWorldTurn?.choices.length, 3);
    expect(resumed.state.recentWorldTurns, hasLength(4));
    expect(resumed.state.storyMemories.length, 6);
    expect(resumed.state.currentLocationId, 'session_location_6');
    resumed.dispose();
  });
}
