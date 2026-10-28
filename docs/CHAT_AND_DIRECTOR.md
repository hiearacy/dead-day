# Dead Day — chat flow / variable world / event director handoff (v0.4)

## Core experience
- **A conversation-style survival game**, not a messenger requiring unrestricted natural-language input.
- After launching: an empty/dim scene, blinking caret, then the opening lines appear letter by letter.
- Each **player choice** is a player-role message. Each **world event** is a world-role message; future individual NPC dialogue uses npc-role messages. Status changes can use system-role messages.
- New messages naturally append below the last one, just like ChatGPT/Zeta. Support auto-scroll only while the reader is near the bottom. If scrolling up, don't steal their position.
- The UI/UX designer owns pacing, bubble layout, scroll anchoring, reveal animation, font sizes and accessibility. The engine supplies messages in `state.messages`.

## Chat feed API
`GameState.messages` is a bounded, saved list of `ChatMessage` (max 80 latest messages):
```json
{
  "id": "m27",
  "day": 4,
  "role": "world",
  "text": "항구 물류 창고에서 소음이 들려온다.",
  "speaker": null,
  "sourceEventId": "zombie_encounter"
}
```
Roles: `player`, `world`, `npc`, `system`. Use `GameController.dispatch(GameAction)` for choices. Never infer mechanics from bubble text. A typing animation is UI-only; NO token-by-token inference, game ticks or saves during animation.

Suggested animation requirements (implementation delegated to UI designer): initial caret-only state; optional 300–600ms blink; typewriter text; tap to finish current message; choice buttons/chips under the latest decision; allow reduced-motion and screen-reader friendly instant text. Scroll only after layout, not every character for large histories. Keyboard/freeform input is **not** required.

## Starting world
`GameState.newRun()` randomly chooses a `WorldProfile`, stored in the save:
- **Seoul**: dense city / residential shelter, danger +0.08
- **Busan**: port / warehouse, danger +0.02
- **Gangwon mountains**: remote cabin, danger -0.07
- **Jeju**: coastal house, danger -0.03

Starting supplies and the names of all three loot categories differ. Example: Seoul pharmacy → downtown pharmacy; Busan pharmacy → harbor clinic; Gangwon pharmacy → local health center; Jeju pharmacy → coastal medical station. The *underlying mechanics* stay consistent and simple for a seven-week project. Starting scenario is selected once per run and persisted.

## Event generation: AI as director, engine as final authority
```text
Engine completes day
    ↓ (at most once every 3 complete days)
DirectorContext (region, biome, health, supplies, noise, NPC, recent events)
    ↓
ProceduralEventDirector (default lightweight fallback)
OR optional Gemini API EventDirector through a secret-holding proxy
    ↓
EventProposal(type, premise, locationId, npcName)
    ↓
DirectedEventSystem.rejection(...) + independent rarity check
    ↓ accepted
GameEngine.acceptDirectedEvent(...) applies bounded rule effect
    ↓
ChatMessage + GameEventRecord + saved GameState
```
The Gemini API director (or procedural fallback) proposes a **premise**, never hardcoded HP changes or unvalidated arbitrary actions. The engine alone determines effects. Proposals are rejected for impossible NPCs, wrong world, unsafe game phases, invalid premises or duplicate same-day calls.

Mechanical archetypes can be small even while narrative setups are combinatorial/free-form. At present: hidden supplies, tainted water, strange broadcast, stranger at door, companion conflict, unsettling encounter. Expand archetypes only when a new *mechanical* effect is needed, not for each story sentence.

A very rare unsettling-encounter branch receives an additional 0.2% engine gate; the default director only proposes that type rarely. Use adult NPCs for mature themes; sexual orientation is independent from threat, consent and violence. Situations involving coercion can be handled as non-graphic threat/refusal/escape/betrayal events; do not portray sexual violence explicitly. Respect story continuity and player agency.

## Added in v0.4
- Three scenario bibles determine the stable world rules, mood and story seeds.
- Player choices in `state.pendingStory` are typed `StoryChoice` objects; use `controller.chooseStory(choice.id)` rather than parsing the UI message.
- A decision is written to `StoryMemory`, and `StoryThread` later picks up that exact choice to generate a consequential follow-up.
- `StructuredAiEventDirector` accepts strictly bounded structured JSON from an optional Gemini API proxy. It is configured in private builds only; no API key is stored in the app.
- UI/UX: render story choices beneath the latest chat bubble and keep its state after returning to the app. The programmer fallback buttons are functional only, not final visual design.
- The procedural event director (or optional Gemini proxy) is checked on every fourth completed day if no other choice is pending; story beats have priority at eligible three-day intervals.

## Present limitations and roadmap
- **Implemented in code**: random world, locale-specific site descriptions, durable chat data, rule-based varied director, validation, saving and fallback.
- **Not implemented**: actual bubbles/typewriter animation, deployed/authenticated public Gemini backend, freeform NLP, full NPC dialogue/romance/complex story-branch choices.
- **Next**: expand choice-driven event chains, deploy Gemini proxy for private tests, and benchmark output quality / latency / quotas.
- iOS/Web/Android gameplay remains the same pure Dart engine; Web can continue with procedural director if no local model is available.
