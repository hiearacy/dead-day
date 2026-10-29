# Dead Day v0.7 — UI/UX handoff and engine contract

**The UI/UX team owns presentation. The engine team owns state, game rules,
AI response validation and persistence.** No screen animation may mutate
GameState.

## Fresh-run flow

1. `controller.newGame(scenarioId: 'lost_signal')` selects the Scenario.
   An unsaved first launch uses the default scenario.
2. `GameController.requestWorldStory()` calls the selected
   `WorldStoryProvider` (Gemini API or procedural fallback).
3. On valid output, `GameEngine.acceptWorldTurn(turn)` records any new
   world elements and sets `state.pendingWorldTurn`.
4. UI renders `pendingWorldTurn.story` and
   `pendingWorldTurn.choices` (exactly three).
5. UI calls `controller.chooseWorldTurn(choice.id)`. The controller calls
   `GameEngine.execute(GameAction.chooseWorldTurn(...))`.
6. The engine validates the target, processes movement/inventory/noise,
   advances day/consumption, writes memories and archive, and saves.
7. The controller requests the next story automatically.

**Do not** call Gemini directly from UI, interpret story text as instructions,
or mutate `state.inventory`, `state.currentLocationId`,
`state.generatedElements` or player stats from widgets.

## Fields for screen rendering

| Read from controller/state | Use |
| --- | --- |
| `state.scenario.title` | Scenario label |
| `state.messages` | Chronological chat bubbles: player/world/NPC/system |
| `state.pendingWorldTurn?.story` | Current AI-generated story |
| `state.pendingWorldTurn?.choices` | Three action chips/buttons |
| `state.currentLocationId` | Active world location |
| `state.worldState.locations` | Discovered AI-created locations |
| `state.worldState.characters` | Generated NPC facts, not companions yet |
| `state.inventory` | Owned item IDs and quantities |
| `state.health / food / water / daysSurvived` | Survival UI |
| `controller.generatingWorldStory` | Pending backend response spinner |
| `controller.error` | Error/fallback notice |

The current `lib/ui/game_screen.dart` is a deliberately disposable
developer prototype. It shows the latest eight chat messages, three buttons,
a minimal scenario selector and status values.

## Typewriter

`lib/ui/typewriter_text.dart` reveals the latest world message one
grapheme at a time with a blinking cursor. It honors reduced-motion settings
by showing text instantly. This is **client-only animation after a complete
JSON response**, not streamed Gemini tokens. The final designer may replace
speed, typography, scrolling, cursor and skip-to-end behavior without
changing the engine.

## Older saves

The v6 save schema can load v1–v5 saves. Those legacy saved runs keep their
earlier mechanics (`interactiveMode=false`). A newly started game enables
the world-generating AI loop.

## Boundaries / known gaps

The JSON validator checks exact ID references, action target types, duplicates
and allowed choices. It does not fully prove that creative prose is logically
consistent. New characters do not automatically become recruited NPCs;
discovered items do not enter inventory until a validated `collect`
choice. AI quality and live Gemini deployment are pending verification.

Full technical contract: [AI world loop](AI_WORLD_LOOP_V07.md).
