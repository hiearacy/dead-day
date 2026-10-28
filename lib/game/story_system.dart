import 'dart:math';
import 'models.dart';
import 'story_memory.dart';

/// Turns two authored story seeds into causal, two-beat arcs.
/// Text is replaceable by future AI, while options and consequences remain
/// deterministically validated by the engine.
class StorySystem {
  const StorySystem();

  StoryBeat? maybeOffer(GameState state) {
    if (state.gameOver || state.waitingForChoice || state.daysSurvived < 3) {
      return null;
    }
    if (state.daysSurvived % 3 != 0) return null;

    // Resolve existing thread before starting another unrelated story.
    for (final thread in state.storyThreads) {
      if (!thread.closed && thread.stage == 1 &&
          state.daysSurvived - thread.lastBeatDay >= 2) {
        final beat = _makeBeat(state, thread);
        state.pendingStory = beat;
        return beat;
      }
    }

    final active = state.storyThreads.any((thread) => !thread.closed);
    if (active) return null;
    for (final seed in state.scenario.storySeeds) {
      if (state.storyThreads.any((thread) => thread.seedId == seed)) continue;
      final thread = StoryThread(id: 'thread_$seed', seedId: seed);
      state.storyThreads.add(thread);
      final beat = _makeBeat(state, thread);
      state.pendingStory = beat;
      return beat;
    }
    return null;
  }

  StoryBeat _makeBeat(GameState state, StoryThread thread) {
    final area = state.world.label;
    final home = state.world.shelter;
    switch (thread.seedId) {
      case 'radio_signal':
        if (thread.stage == 0) {
          return StoryBeat(
            id: 'radio_signal_open',
            threadId: thread.id,
            createdDay: state.currentDay,
            premise: '$area의 거점에서 오래된 라디오가 켜졌다. '
                '잡음 사이로 현재 위치와 가까운 구조 지점이 반복된다. '
                '마지막에는 누군가 기침하는 소리가 들린다.',
            choices: const [
              StoryChoice(
                id: 'trace', label: '신호의 출처를 확인한다',
                outcome: '구조 방송의 일부가 일정하게 반복된다는 사실을 발견했다.',
                waterDelta: -1,
              ),
              StoryChoice(
                id: 'ignore', label: '위험하니 라디오를 꺼 둔다',
                outcome: '방송을 껐다. 하지만 주파수와 시각을 기억해 두었다.',
              ),
            ],
          );
        }
        final investigated = thread.decision == 'trace';
        return StoryBeat(
          id: 'radio_signal_followup',
          threadId: thread.id,
          createdDay: state.currentDay,
          premise: investigated
              ? '지난번 기록한 주파수에서 암호처럼 보이는 숫자가 들린다. '
                  '구조를 요청하는 소리인지 함정인지 아직 알 수 없다.'
              : '지난번 무시한 라디오 방송이 다시 들려온다. '
                  '이번에는 거점 주변의 지명을 정확히 말한다.',
          choices: investigated
              ? const [
                  StoryChoice(
                    id: 'share', label: '동료와 방송 내용을 공유한다',
                    outcome: '방송의 단서를 함께 검토했다. 혼자 감추지 않기로 했다.',
                    trustDelta: 7,
                  ),
                  StoryChoice(
                    id: 'hide', label: '정보를 숨기고 혼자 보관한다',
                    outcome: '방송 기록을 숨겼다. 당분간 비밀을 지키기로 했다.',
                    trustDelta: -5,
                  ),
                ]
              : const [
                  StoryChoice(
                    id: 'listen', label: '방송을 끝까지 듣는다',
                    outcome: '송신 위치의 실마리를 얻었지만 주변에 소음이 퍼졌다.',
                    healthDelta: -3,
                  ),
                  StoryChoice(
                    id: 'silence', label: '기기를 망가뜨려 소리를 막는다',
                    outcome: '방송은 멈췄지만 단서도 사라졌다.',
                  ),
                ],
        );
      default:
        if (thread.stage == 0) {
          return StoryBeat(
            id: 'visitor_open',
            threadId: thread.id,
            createdDay: state.currentDay,
            premise: '$home의 문 앞에 지친 생존자가 나타났다. '
                '며칠째 굶었다며 물자가 조금만 있으면 곧 떠나겠다고 한다.',
            choices: const [
              StoryChoice(
                id: 'help', label: '식량 한 개를 건넨다',
                outcome: '낯선 생존자는 조용히 인사하고 사라졌다.',
                foodDelta: -1,
              ),
              StoryChoice(
                id: 'refuse', label: '문을 열지 않고 돌려보낸다',
                outcome: '누군가 한동안 문을 두드리다 떠났다.',
              ),
            ],
          );
        }
        final helped = thread.decision == 'help';
        return StoryBeat(
          id: 'visitor_followup',
          threadId: thread.id,
          createdDay: state.currentDay,
          premise: helped
              ? '도움을 받았던 생존자가 돌아왔다. '
                  '폐쇄된 진료소의 위치를 적은 쪽지를 내민다.'
              : '문 앞에 낯선 발자국이 남아 있다. '
                  '며칠 전 돌려보낸 사람과 관련이 있을지 모른다.',
          choices: helped
              ? const [
                  StoryChoice(
                    id: 'accept_tip', label: '쪽지를 받아 확인한다',
                    outcome: '진료소에서 쓸 만한 의료 물품을 발견했다.',
                    medicineDelta: 1,
                  ),
                  StoryChoice(
                    id: 'decline_tip', label: '수상하니 쪽지를 거절한다',
                    outcome: '정체를 확인하지 못한 채 생존자를 돌려보냈다.',
                  ),
                ]
              : const [
                  StoryChoice(
                    id: 'follow_tracks', label: '발자국을 따라가 본다',
                    outcome: '허탕을 쳤고 돌아오는 길에 가벼운 상처를 입었다.',
                    healthDelta: -5,
                  ),
                  StoryChoice(
                    id: 'secure_door', label: '문을 보강하고 경계한다',
                    outcome: '거점의 문을 다시 잠갔다. 흔적은 더 나타나지 않았다.',
                  ),
                ],
        );
    }
  }

  bool canChoose(GameState state, StoryChoice choice) =>
      state.food + choice.foodDelta >= 0 &&
      state.water + choice.waterDelta >= 0 &&
      state.medicine + choice.medicineDelta >= 0;

  /// Returns null if this choice is invalid. Invalid choices never mutate.
  StoryMemory? resolve(GameState state, String choiceId) {
    final pending = state.pendingStory;
    if (pending == null) return null;
    StoryChoice? selected;
    for (final choice in pending.choices) {
      if (choice.id == choiceId) selected = choice;
    }
    if (selected == null || !canChoose(state, selected)) return null;

    final thread = state.storyThreads.firstWhere(
      (thread) => thread.id == pending.threadId,
    );
    state.food = max(0, state.food + selected.foodDelta);
    state.water = max(0, state.water + selected.waterDelta);
    state.medicine = max(0, state.medicine + selected.medicineDelta);
    state.health = min(100, max(0, state.health + selected.healthDelta));
    if (state.companion != null) {
      state.companion!.trust =
          min(100, max(0, state.companion!.trust + selected.trustDelta));
      state.companion!.remember(selected.outcome);
    }

    final memory = StoryMemory(
      key: '${pending.id}_${selected.id}',
      day: state.currentDay,
      summary: '${selected.label}: ${selected.outcome}',
      threadId: pending.threadId,
      tags: [thread.seedId, selected.id],
    );
    state.rememberStory(memory);
    thread.stage++;
    thread.lastBeatDay = state.daysSurvived;
    thread.decision = selected.id;
    if (thread.stage >= 2) thread.closed = true;
    state.pendingStory = null;
    return memory;
  }
}
