# Dead Day v0.8 — Structured Gemini output and world consistency

## Why this exists
The first Android APK and Web release build were verified in GitHub Actions
[run 40882421268](https://github.com/hiearacy/dead-day/actions/runs/40882421268).
This version hardens the first actual Gemini story integration, **without**
claiming a deployed Worker or successful live-model test.

## Generation contract
- Backend `LlmProvider.generateStory(context)` remains provider-independent.
- `GeminiProvider` requests one **complete JSON** response via
  `generationConfig.responseMimeType=application/json` and
  `generationConfig.responseJsonSchema`, defined in
  `backend/src/story_schema.js`.
- Output: Korean `story`, **exactly three** different `choices` with engine
  intent/target IDs, and **0–2** new `generated_elements`.
- Backend validates structure, unique generated IDs/names, parent references,
  choice target types (move -> location, collect -> item), and rejects unknown
  targets or duplicate choice text.
- The full local `GameState` is the final authority: the Dart
  `WorldStoryValidator` checks existing and new elements and further ensures
  movement follows parent/child location connections, and collection can only
  pick up a currently reachable unowned item.
- AI-generated text cannot change inventory, move player or change resource
  values without a valid player choice and engine action.

## Context memory
`WorldContextSelector` selects up to twelve relevant established world
facts, prioritizing current location/ancestors, owned items and referenced
important past decisions before nearby and recent discoveries.
Old world elements are **not deleted** merely because they are omitted from
the short Gemini context: the save retains up to 500 established elements.

## Failure behavior
Malformed/unavailable API: `GeminiWorldStoryProvider` fails and
`FallbackWorldStoryProvider` offers an offline procedural turn. When Gemini
JSON parses but fails full Dart world validation, `GameController` also
retries the procedural fallback. There is no automatic paid API retry loop.

## QA baseline
- Android/Web GitHub Actions build, static analysis, Dart tests, Node tests,
  and build uploads for each successful CI run.
- The 6-turn controller save/reload test checks that world elements and
  unresolved turns survive restarts.
- Added tests for invented items in other rooms, non-adjacent destination
  rejection, broken story choices, duplicate elements and Gemini schema.
- Real Gemini output quality, API response timings, account quotas and
  behavior on physical devices remain **unverified** without the developer's
  private Gemini/Cloudflare configuration.

## Developer playtest
1. Open repository Actions -> successful run -> Artifacts.
2. Download `dead-day-android-debug-apk` or `dead-day-web`. Artifacts
   are retained for seven days and require appropriate repository access.
3. The APK is an unsigned-for-store debug build (not a store release).
   Install only on a dedicated trusted test device.
4. The Web artifact contains static build files, not a hosted game; serve
   the extracted directory through a local HTTP server.
5. Without private Gemini configuration, playtests use the procedural
   fallback, not live cloud AI.
6. Run three 5–10 minute sessions, noting scenario consistency, newly
   discovered world elements, context recall, UI legibility and repetition.

Public deployment needs real user authentication, per-user quotas and a
server-side global Gemini budget; a shared demo token compiled into the
app is **not secure** for public use.
