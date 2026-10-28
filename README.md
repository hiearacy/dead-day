# Dead Day

**Dead Day** is an offline-first zombie survival text game for Android, built with Flutter + Dart. Goal: survive as many days as possible while food and water run out, dangerous searches become necessary, and fellow survivors are not always trustworthy.

## First playable prototype (v0.1)
- Shelter: rest or take medicine.
- Three exploration zones: market, pharmacy, apartments.
- Encounter choices: fight, sneak, flee, with probabilistic consequences.
- Daily food and water drain, injury and death, best survival record.
- One recruitable companion who helps recovery but uses rations and can leave.
- Automatic local save via `shared_preferences`.
- AI narration interface only: **no LLM is bundled or running**.

## Run locally
1. Install Flutter SDK + Android SDK and run `flutter doctor`.
2. Clone this repository, then in its root run:
   ```bash
   flutter create --project-name dead_day --platforms android .
   flutter pub get
   flutter test
   flutter run
   ```
3. In VS Code choose an Android emulator or a USB-connected Android device.

The repo stores the reusable Dart source/config. The platform-specific Android runner is generated locally by `flutter create`, and may be committed later after verifying the Android application ID.

## Architecture
```
lib/
  main.dart
  ui/game_screen.dart           # mobile controls / text output
  app/game_controller.dart      # view state, save ordering, AI coordination
  game/models.dart              # serializable game state, zones and NPC
  game/game_engine.dart         # all authoritative mechanics
  data/save_service.dart        # local persistence
  ai/narrator.dart              # read-only optional AI interface
test/game_engine_test.dart
docs/GAME_DESIGN.md
```

The engine makes outcomes. AI may write *narrative text* from a limited, read-only context but may never rewrite inventory, RNG outcomes, or NPC status. The base game runs fully offline with no model download.

## Validation status
Repository source is committed, but Flutter/Dart SDK is unavailable in the assistant's working runtime. **Flutter analyze, test and on-device thermal/performance tests have not been run**. Use the commands above to validate locally before treating v0.1 as release-ready.

See [gameplay design](docs/GAME_DESIGN.md) for mechanics, scope and the seven-week roadmap.
