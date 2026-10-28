# Dead Day — system / designer integration contract (v0.3)

## Responsibility split
- **Developer (Flutter + Dart engine)**: authoritative rules, persistence, event catalogue, companion decision logic, AI boundary and automated tests.
- **UI/UX designer**: screens, transitions, typography, icons, visual effects, button placement, pacing and presentation. Current `lib/ui/game_screen.dart` is only a disposable programmer prototype.
- Changes to visual presentation must never become dependencies inside `lib/game/`.

## Data flow
```text
User tap or validated NPC intent
          |
          v
GameController.dispatch(GameAction)
          |
          v
GameEngine.execute(GameAction)   [sync, authoritative]
          |
          +--> GameResult (accepted, code, dayBefore/dayAfter, events[])
          +--> GameState (updated stats, pending choices, journal)
          |
          +--> SaveService -> versioned JSON, independent of UI
          +--> Optional AiNarrator for important events only
                              |
                              +--> short read-only Korean flavor text
```

### GameAction
- `GameAction.explore(Zone.market | Zone.pharmacy | Zone.apartments)`
- `const GameAction.rest()`
- `const GameAction.useMedicine()`
- `GameAction.resolve(EncounterAction.fight | flee | sneak)`
- `GameAction.recruit(bool accept)`

Always send actions through `GameController.dispatch(...)`; do **not** mutate `GameState` from UI code. The old controller methods (`rest()`, etc.) remain as convenience wrappers.

### GameResult
- `accepted`: false on illegal actions such as attempting to rest during an unresolved zombie encounter.
- `code`: `ok`, `game_over`, `pending_decision`, `no_encounter`, `no_recruitment`, or `medicine_unavailable`.
- `dayBefore/dayAfter`: complete days survived.
- `events`: event IDs and categories created by this action, not a UI script.

### GameState (persistent)
- Health, food, water, medicine, weapon level and noise (0-100).
- `daysSurvived`, `bestDays`, `gameOver`.
- `encounter`, `pendingRecruitment`, companion info.
- `journal`: most recent 24 structured `GameEventRecord` entries (`id`, `day`, `kind`, `text`). UI can display or animate these but must not infer gameplay rules by parsing Korean text.
- `log`: a temporary fallback text field for the existing programmer UI.
- `world`: immutable-by-run `WorldProfile` (region, biome, starting shelter, dynamic exploration site labels, initial supplies, danger offset).
- `messages`: up to 80 saved `ChatMessage` instances, with `role`, `speaker`, `day`, `text`, and `sourceEventId`. A UI should render these in conversational order.
- The engine can accept `EventProposal` after `DirectedEventSystem` validates region, NPC, date, and rarity. The fallback `ProceduralEventDirector` works with no LLM.

**Pending decisions**: `state.encounter != null` means fight/sneak/flee must be chosen; `state.pendingRecruitment` means accept/decline must be chosen. A single event cannot be resolved twice.

## Chat interface and opening typewriter direction — handed to UI/UX designer
See `docs/CHAT_AND_DIRECTOR.md` for message stream rules, auto-scroll behavior and exact designer handoff.
On first run: dark/empty screen, **blinking text caret** before any letters appear, then the opening text is typed one glyph at a time ("다다다닥" rhythm). This is a **presentation-only effect**, not a game tick, and must not trigger AI inference per character.

Implementation notes for the designer's team (not implemented by the engine):
- Use a prewritten intro script, no model call during intro.
- Allow tap-to-complete and skip, including replay after reopening.
- Support user/device reduced-motion preference: show text immediately when animation is disabled.
- Avoid per-character sound or haptic by default. Dispose animation timers when navigating.
- Keep the script separate from the game rules; animation finishing should not increment survival days.

## On-device AI boundary
- `AiScene.fromGame(state)` provides capped outcome, three recent event excerpts, three NPC memory excerpts and small stats.
- `NoAiNarrator` is the default on Android, iOS and Web. **No local model is integrated yet**.
- A future on-device model may return decorative text, never an inventory change, death result, arbitrary game action or trust update. A separate validator will be required before allowing AI-proposed NPC intents.
- Only notable companion, combat or horde events request narration; model failure must never block play.

## Cross-platform/testing
- No platform code or plugin imports under `lib/game/`.
- Old v1/v2 saves automatically migrate to v3; preserve this in future releases.
- Android, iOS and Web share the same deterministic game rules.
- Run `flutter analyze`, `flutter test`, Android and Web builds. Physical device thermal checks and iOS builds are later validation steps.
