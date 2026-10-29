# Dead Day v0.7 — AI-generated world and interactive story MVP

## Product direction (authoritative)
Dead Day is an **AI interactive storytelling platform with survival rules**,
not a finite branch table or a chatbot where the LLM directly edits game data.

```text
Scenario bible (world / era / tone / rules / characters / locations / items)
        + local GameState (position, inventory, survival, decisions)
        + WorldState (generated elements already accepted)
        + StoryMemory / unresolved threads / last StoryTurn and choice
                          |
                          v
Flutter -> /v1/story backend -> LlmProvider -> GeminiProvider
                          |
                complete structured JSON
                          |
                          v
StoryTurn + 3 TurnChoices + generated_elements
                          |
              game-side WorldStoryValidator
                 /                   \
        rejected: local fallback    accepted: authoritative WorldState
                                         |
                               player chooses one action
                                         |
                                  GameEngine.execute
                                         |
                         validate target -> apply state effects
                         (move / investigate / talk / observe / collect)
                                         |
                           consume day + food/water, NPC rules
                           save StoryMemory, StoryTurn, inventory, position
                                         |
                                next StoryContext -> repeat
```

The old `EventDirector` (six mechanical event archetypes), zombie combat,
recruitment and the authored radio/visitor storylines are retained for **v1-v5
save compatibility and experiments**. Fresh runs use `interactiveMode=true`
and the new `StoryTurn` pipeline; the legacy authored story schedule and
random recruitments are disabled there.

## Code map
- `lib/game/scenario_definition.dart`: the **Scenario** bible, with era,
  tone, unbreakable rules, seed locations, characters, objects, story seeds.
- `lib/game/models.dart`: versioned **GameState**, world elements, position,
  inventory, recent world turns, pending turn, important memory and health.
- `lib/game/world_state.dart`: read-only **WorldState** projection.
- `lib/game/generated_world_element.dart`: location, character, item, clue
  or event, including ID, name, origin, parent, discovery state.
- `lib/game/location.dart`, `character.dart`, `item.dart`:
  dedicated typed views / owned item stacks.
- `lib/game/story_turn.dart`: generated story and exactly three choices.
  Each option includes a short engine-owned `intent` and optional
  `target_id`; these fields are added to the proposed user-facing JSON
  schema because the engine must know how to validate/execute a choice.
- `lib/game/world_story_validator.dart`: validate IDs, maximum sizes,
  duplicate locations, current-day origin, known targets and three choices.
- `lib/game/game_engine.dart`: only authority for movement, inventory,
  hunger, health, story choice effects and persistent event memory.
- `lib/ai/world_story_provider.dart`: bounded context and procedural
  fallback (works without internet or a Gemini key).
- `lib/ai/gemini_world_story_provider.dart`: HTTPS client for complete
  JSON story turns via a secret-holding backend.
- `backend/src/llm_provider.js`, `gemini_provider.js`, `story_route.js`:
  replaceable backend LLM provider and `POST /v1/story` handler.
- `lib/ui/typewriter_text.dart`: small, accessible animated reveal only;
  not actual Gemini token streaming.

## Story JSON contract
The backend accepts `{ "context": StoryContext }` and returns:
```json
{
  "turn": {
    "id": "world_turn_4_a1b2",
    "story": "서울역 통제실 문 아래로 불빛이 새어 나온다. 안에서 발소리가 들린다.",
    "choices": [
      {"id":"choice_1", "text":"B3 구역으로 간다", "intent":"move", "target_id":"location_b3"},
      {"id":"choice_2", "text":"문을 살펴본다", "intent":"investigate", "target_id":null},
      {"id":"choice_3", "text":"기다린다", "intent":"observe", "target_id":null}
    ],
    "generated_elements": [{
      "id":"location_b3", "name":"서울역 B3 구역", "kind":"location",
      "description":"잠겨 있던 구역", "parentId":"start_seoul",
      "createdDay":4, "discovered":true, "origin":"ai_generated"
    }]
  }
}
```
`kind`: location, character, item, clue, event.
`intent`: move, investigate, talk, observe, collect.
The LLM does **not** supply player health, item quantities, movement results,
damage or numeric effects. It can describe a locked door but opening it only
happens if the player chooses a validated movement action.

## Remembering the growing world
- New world elements are appended to the *authoritative* save on acceptance
  of a valid turn; IDs are unique and old names/IDs cannot be overwritten.
- World elements are kept locally (prototype cap: 500).
- The next AI request sends up to the 15 most recently generated elements
  plus the current location ID/name, important memories, scenario bible,
  unresolved story threads, recent three story excerpts and latest choice.
  This is intentionally **not** the entire chat; a future relevance retrieval
  layer should selectively include older elements near the player.
- Invented people become world facts, NOT instant companions; an invented
  item becomes a world fact, NOT an inventory item until `collect` is chosen.
- An accepted turn has exactly three choices, and engine actions each have
  bounded effects, including daily food/water use.

## Guardrails and known gaps
- Server is an **API relay**, never the authority for player resources.
  Flutter `GameEngine` validates world IDs, targets and all outcomes.
- This validates *structure and referential consistency*, not every natural
  language proposition. A model might still narrate a contradictory fact
  inside free text. This needs world-fact extraction / semantic consistency
  evaluation before production. Do not claim complete story coherence yet.
- The fallback story generator is deliberately simple and may become
  repetitive. Real Gemini quality, long-run memory, story fun and token cost
  are not yet proven.
- The old private-test `DEMO_ACCESS_TOKEN` approach is **not secure for a
  public app**. A released app must verify real user identity and enforce
  daily API budgets on the backend; no Gemini key is in Flutter.
- No real Gemini key or deployed Worker has been connected by the assistant.
- Flutter SDK is absent from the assistant runtime, so Flutter analyze/test
  and Android/iOS/Web builds require CI or a developer machine.

## MVP / UI handoff
The screen currently lists recent messages with the latest world message
revealed progressively; it provides three choice buttons and basic scenario
selection. It is a functional programmer UI, not final visual design.

The designer owns full chat UI/UX, smooth scrolling, cursor pacing, reduced
motion, icons and layout. Keep UI animations independent of GameState.

First playable target: one primary scenario ('마지막 송신'), 5–10 minutes of
story choices, 3 NPC/5–10 items as a later content target, not yet all
implemented as dynamic behaviors. Current scenario catalog still contains
two legacy companion scenarios for compatibility.

## Validate and iterate
1. `flutter create --project-name dead_day --platforms=android,web .`
2. `flutter pub get && flutter analyze && flutter test`
3. `cd backend && npm install && npm test`
4. Deploy backend only with a private Gemini key and private test auth;
   see `docs/GEMINI_API_SETUP.md`.
5. Play 5–10 minutes and inspect generated IDs, duplicate facts, movement,
   memory reuse, JSON rejection, API latency/quota, boredom and replayability.
6. Only then evaluate richer NPC rules and true token streaming.
