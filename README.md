# Dead Day — AI Interactive Story Platform

**Dead Day** is a scenario-grounded, AI-extended zombie survival story game
built with Flutter and Dart for **Android, iOS and Web**.

The central loop is **Scenario + authoritative GameState + player's last
choice → AI-generated story and new world elements → engine validation →
three player choices → engine-owned consequences → saved WorldState →
next AI story**.

A scenario is a world bible, **not a completed plot or finite branch table**.
The Gemini backend may introduce new locations, people, clues, items or
events that fit its rules. The game engine alone decides time, resources,
movement, inventory and death.

## v0.7 — first end-to-end vertical slice

- Authored scenario bibles with setting, era, tone, rules, initial places,
  characters, items and story seeds. Existing three scenarios remain.
- Complete structured `StoryTurn` with `story`, exactly three choices,
  and optional `generated_elements`.
- Dynamic `WorldState` (AI-created locations, characters, items, clues and
  events) with persistent IDs, known locations, current position and item
  ownership separated from discovery.
- The engine validates new elements and actions before changing any state.
  Invalid AI JSON, nonexistent targets, duplicate names/IDs or unavailable
  choices cannot grant resources or teleport the player.
- Player decisions advance the survival day, consume food/water, and add
  causal StoryMemory. Old story threads and recent StoryTurns are preserved.
- Model-independent server `LlmProvider.generateStory(context)`; currently
  `GeminiProvider` behind a secret-holding Cloudflare Worker.
- Provider/connection failures fall back to a basic offline procedural
  story generator (not a local LLM).
- Basic three-choice Flutter interface with saved chat transcript and
  typewriter reveal for the latest world message. Final visuals remain with
  the UI/UX designer.
- Versioned local save, v1–v5 migration to v6.
- Old combat, scripted story and event systems remain in the repository for
  legacy saved games; **fresh games use the dynamic story loop**.

## Project modules

```text
lib/
  game/scenario_definition.dart     # world bible and seed content
  game/models.dart                  # GameState; v6 save schema
  game/world_state.dart             # read-only world projection
  game/generated_world_element.dart # invented world entities
  game/location.dart, character.dart, item.dart
  game/story_turn.dart              # three meaningful player choices
  game/world_story_validator.dart   # untrusted scene validation
  game/game_engine.dart             # authoritative mechanics
  game/story_memory.dart            # causal memories and legacy threads
  ai/world_story_provider.dart      # bounded context and offline fallback
  ai/gemini_world_story_provider.dart
  ai/ai_configuration.dart          # private-test API selection
  app/game_controller.dart          # async generation and autosave
  data/save_service.dart
  ui/game_screen.dart               # temporary functional view
  ui/typewriter_text.dart
backend/
  src/llm_provider.js               # provider contract
  src/gemini_provider.js            # Google Gemini implementation
  src/story_route.js                # structured JSON handling
  src/index.js                      # private-test HTTP authentication/proxy
test/
  world_story_loop_test.dart        # growing world and save cycle
  world_item_inventory_test.dart    # discovery vs possession
  typewriter_text_test.dart
  ... legacy and proxy regression tests
```

## Run locally

Install Flutter and Android tooling (`flutter doctor`). From the repository
root:

```bash
flutter create --project-name dead_day --platforms=android,web .
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

On macOS with Xcode you can also generate an iOS runner with
`flutter create --project-name dead_day --platforms=android,ios,web .`.

Without private API configuration, the **procedural story fallback works**
and the game can still be played. For actual Gemini stories, deploy the
backend and configure private test credentials as explained in
[Gemini setup](docs/GEMINI_API_SETUP.md). **Never ship a Gemini API key
or a shared demo bearer token in a public app.**

## Specifications

- [v0.7 world/story loop and JSON contract](docs/AI_WORLD_LOOP_V07.md)
- [Gemini deployment and private testing](docs/GEMINI_API_SETUP.md)
- [UI/UX developer handoff](docs/ENGINE_API.md)

## Status / limitations

The first architecture and tests have been **committed**. The assistant's
execution environment does not have Flutter/Dart and cannot reach the GitHub
host from its shell, so **Flutter test/analyze, mobile builds, live Gemini
API calls and multi-session playtests are not confirmed**. The Gemini Worker
has not been deployed with a real key. The current validator checks structure
and references, not all possible semantic contradictions in creative prose.
AI-authored NPC behavior and user-made scenarios remain future steps.
