import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ai/world_context_selector.dart';
import 'package:dead_day/ai/world_story_provider.dart';
import 'package:dead_day/game/generated_world_element.dart';
import 'package:dead_day/game/models.dart';
import 'package:dead_day/game/story_memory.dart';

void main() {
  test('old B3 location stays in AI context after 35 newer discoveries', () {
    final state = GameState(interactiveMode: true);
    state.generatedElements.add(const GeneratedWorldElement(
      id: 'location_b3', name: '서울역 B3 구역',
      kind: WorldElementKind.location, description: '봉쇄된 통제실',
      parentId: 'start_seoul', createdDay: 1,
    ));
    for (var i = 0; i < 35; i++) {
      state.generatedElements.add(GeneratedWorldElement(
        id: 'location_new_$i', name: '새로 발견한 구역 $i',
        kind: WorldElementKind.location,
        description: '기타 외곽 지역', parentId: 'start_seoul',
        createdDay: i + 2,
      ));
    }
    state.currentLocationId = 'location_b3';
    final chosen = const WorldContextSelector().select(state);
    expect(chosen.length, lessThanOrEqualTo(12));
    expect(chosen.first.id, 'location_b3');
    final promptElements =
        StoryContext.fromGame(state).data['generated_elements'] as List;
    expect(promptElements.any((e) => (e as Map)['id'] == 'location_b3'), isTrue);
  });

  test('a location referenced by a past choice is kept when far away', () {
    final state = GameState(interactiveMode: true);
    state.generatedElements.add(const GeneratedWorldElement(
      id: 'station_control', name: '오래된 통제실',
      kind: WorldElementKind.location, description: '오래된 단서',
      parentId: 'start_seoul', createdDay: 1,
    ));
    for (var i = 0; i < 30; i++) {
      state.generatedElements.add(GeneratedWorldElement(
        id: 'recent_place_$i', name: '최근 장소 $i',
        kind: WorldElementKind.location, description: '배경',
        parentId: 'start_seoul', createdDay: i + 2,
      ));
    }
    state.rememberStory(const StoryMemory(
      key: 'decision', day: 2,
      summary: '통제실에서 찾은 주파수를 기록했다.',
      threadId: 'signal', tags: ['world', 'station_control'],
    ));
    final chosen = const WorldContextSelector().select(state);
    expect(chosen.any((item) => item.id == 'station_control'), isTrue);
  });

  test('long-run world save restores all 90 generated elements', () {
    final state = GameState(interactiveMode: true);
    for (var i = 0; i < 90; i++) {
      state.generatedElements.add(GeneratedWorldElement(
        id: 'location_$i', name: '지역 $i',
        kind: WorldElementKind.location, description: '기억에 남는 장소',
        parentId: 'start_seoul', createdDay: 1,
      ));
    }
    final restored = GameState.fromJson(state.toJson());
    expect(restored.generatedElements.length, 90);
    expect(restored.generatedElements.first.id, 'location_0');
    expect(restored.generatedElements.last.id, 'location_89');
    final context = StoryContext.fromGame(restored);
    expect((context.data['generated_elements'] as List).length,
        lessThanOrEqualTo(12));
  });
}
