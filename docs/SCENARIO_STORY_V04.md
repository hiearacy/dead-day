# Dead Day v0.4 — scenario and causality design (AI transport changed in v0.5)

## Goal
Prove that a **short, authored scenario bible + the player's consequential choices** can sustain a coherent text-survival story without asking a tiny mobile AI to invent a world from scratch.

## Current scope
Three bundled scenario definitions (`lib/game/scenario_definition.dart`):
- `open_survival` — **무너진 일상** (Seoul/Busan/Gangwon/Jeju).
- `lost_signal` — **마지막 송신** (Seoul/Busan).
- `silent_coast` — **바다의 끝** (Busan/Jeju).

Each bible specifies premise, tone, nonnegotiable world rules, allowed starting regions, and story seed IDs. A new game chooses a region *inside* its selected scenario and keeps it for the run.

### How the developer or designer selects a scenario
```dart
await controller.newGame(scenarioId: 'lost_signal');
```
Existing `controller.newGame()` remains the default open-survival scenario. No scenario-selector visual design is committed; that belongs to the UI/UX designer.

## Cause and effect, without huge context
1. `StorySystem.maybeOffer` selects a scripted 2-beat thread after a completed day (first eligible: day 3, later beats at eligible multiples of 3).
2. `GameState.pendingStory` stores the story text and **typed choices** until the player chooses. While pending, exploration/rest/medicine are blocked.
3. `GameAction.chooseStory(choiceId)` dispatches a validated choice to `GameEngine`. Unavailable choices, unknown IDs and accidental double taps cannot change the story.
4. `StorySystem.resolve` applies limited resource/trust changes and persists an explicit `StoryMemory` with tags, not a verbatim transcript.
5. `StoryThread` stores the seed, stage and previous decision. A subsequent beat references that decision and changes its situation and available choices.
6. Saving mid-story resumes the *same* unresolved choice; memories and threads survive restarts.

Example: choose to trace a radio signal (consumes a water ration); several days later, the follow-up contains new information about the frequency. If the player ignored the broadcast, the subsequent scene instead involves a broadcast naming a nearby location. The player gets a different set of choices.

Prototype stories are 2-beat arcs: `radio_signal` and `unknown_visitor`. Once closed, the same thread is not endlessly recycled in the same run. This is **a bounded proof of causality**, not yet unlimited stories.

## AI integration boundary
`DirectorContext` and `AiScene` now include the scenario bible, short key memories and recent event summaries. Avoid sending chat history wholesale.

`StructuredAiEventDirector` translates a local-model **JSON** reply into an untrusted `EventProposal`:
```json
{
  "type": "strangerAtDoor",
  "premise": "누군가 창고 문 앞에서 낮게 도움을 청한다.",
  "locationId": "busan"
}
```
It rejects malformed JSON, unknown event types and long output. `DirectedEventSystem` is still the final authority for context consistency, rarity, state mutation and other rules. `FallbackEventDirector` can switch to scripted events if the API fails. **As of v0.5, an optional remote Gemini API proxy replaces the on-device model plan.** See `docs/GEMINI_API_SETUP.md`.

## Cross-platform design handoff
Use `state.messages` for chat bubbles and `state.pendingStory` to render a choice group below the latest world message. The programmer UI includes *minimal* functional buttons so the game cannot soft-lock. The designer owns chat scroll behavior, visual styling, blinking caret, text-reveal pace and accessibility. Never make a rendering animation advance a day.

## Performance and fun validation
Technical test: Android/Web `flutter test` and builds, and iOS on macOS/Xcode when available.

Manual 10–15-minute playtest: can players recall a previous choice when its consequence reappears? Do they hesitate before selecting? Does the second run differ? Are event cooldowns and causal memories coherent? Record 5–10 sessions before tuning event frequency.

Gemini API evaluation (future): test Korean storytelling, consistency with scenario rules, failed JSON rates, network latency, and quota exhaustion. Limit output to approximately 128 tokens in the first prototype, measure calls per play session, and confirm the gameplay fallback works with no network. Do not embed your API key in the app.
