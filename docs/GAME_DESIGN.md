# Dead Day — gameplay contract (v0.4)

## Goal and boundaries
Survive as many full days as possible during a zombie apocalypse. This is an offline-first **cross-platform text game**, not a world simulator. The playable v0.2 prototype has one shelter, three exploration zones, one recruitable survivor, a combat choice encounter, basic resources and autosave.

## Cross-platform contract (Android / iOS / Web)
- Keep ALL gameplay, RNG, character states and event results in plain Dart code independent of platform plugins.
- Use one Flutter UI with a narrow, readable content width on large web/desktop viewports, adaptive scrolling and tap-friendly controls on phones.
- Keep save data platform-independent: the same versioned JSON schema is serialized locally via shared_preferences; saves are **per-device/per-browser**, not automatically synced between devices.
- All platforms must work fully offline after installation/loading; browser offline availability depends on how the web app is deployed/cached, so do not claim guaranteed offline browser startup.
- The optional Gemini API event director is cross-platform via an HTTPS backend proxy. No Gemini secret is shipped in the Flutter client. Offline play uses a rule-based procedural fallback.
- Android and Web have automated build checks on GitHub Actions; iOS builds require macOS/Xcode and remain unverified until run there.
- Native platform runner folders are created with `flutter create --project-name dead_day --platforms=android,ios,web .` when setting up locally. Do not include platform-specific imports in `GameEngine`.

## Daily loop
1. At the shelter, pick **explore** (one zone) or **rest**.
2. Exploration either yields loot or a zombie encounter. When encountered choose fight, sneak or flee. Results are probabilistic and use health, weapon level, zone danger, and zombie count.
3. The action consumes the day. Deduct one food and one water **per survivor**. Missing rations reduce the player's health.
4. Companion trust responds to sufficient/insufficient rations; under severe scarcity a low-trust companion may leave with medicine.
5. Record a full day only when the character survives end-of-day processing. Death ends the run; best score persists across new runs.

Medicine is a free shelter action, healing 30 HP. A zone encounter decision must be resolved before any new day action. Repeated event-button taps cannot resolve the same encounter twice.

## Zones (initial balance, not final)
| Zone | Zombies encountered | Main reward |
| --- | ---: | --- |
| Market | 40% | Food OR water |
| Pharmacy | 55% | Medicine |
| Apartments | 70% | Food + water OR weapon level |

## New v0.2 systems
- Every legal player command passes through `GameEngine.execute(GameAction)` and returns an immutable `GameResult` with machine-readable event records; rejected inputs do not advance days.
- GameState saves a bounded journal (latest 24 events), noise (0-100), and companion memories (latest six strings). Previous v1 save files migrate to v2.
- Combat and failed stealth add noise, which slightly increases future zombie encounter chances; noise fades after each completed day. Later days also raise exploration danger within a cap.
- A small weighted nighttime event catalogue can grant or remove supplies or alter noise. Events have explicit conditions and are resolved in ordinary Dart.
- Companion trust reacts to ration shortfall and long-term scarcity may trigger departure. Current disposition and memory fields prepare for future richer relationships, but autonomous NPC planning and romance are NOT implemented yet.
- AI narration is requested only for notable combat, companion or horde events. Model use remains disabled until validated on Android/iOS.

## New v0.3 world, chat and director foundations
- Fresh runs choose one of four locations (Seoul, Busan, Gangwon, Jeju), with environment-specific supply levels, combat danger offset and named exploration sites. The region is persisted for the whole run.
- All legal actions create saved chat transcript messages separately from the event journal. Roles include player/world/NPC/system, allowing a messaging-platform UI without interpreting Korean strings.
- The default lightweight `ProceduralEventDirector` proposes a situation after every third completed day when no decision is pending, and the `DirectedEventSystem` checks setting, NPC validity, duplicates, premise length and a separate very-rare event gate. Only the engine changes resources or trust.
- `EventDirector` is a replaceable optional on-device AI provider. No model is currently bundled. Model failure must not prevent gameplay.
- Full UI animation, continuous NPC conversation, and a broad player-choice story event graph remain future work.
- See `docs/CHAT_AND_DIRECTOR.md` for visual design handoff and backend data contracts.

## New v0.4 authored scenario + story system
- A stable `ScenarioDefinition` selects the world and supplies world rules, tone, premise and story seeds.
- Typed `StoryBeat` with two or more `StoryChoice` alternatives pauses further daily actions until the player decides.
- `StoryMemory` records important choice outcomes and `StoryThread` links follow-ups to earlier choices. Initial radio/visitor arcs contain two beats each.
- `StructuredAiEventDirector` offers strict JSON-only adaptation for future on-device inference; model runtime and thermal benchmarks remain future work.
- Saved games migrate v1/v2/v3 -> v4. Existing UI is only a programmer prototype; design team owns visuals.
- See `docs/SCENARIO_STORY_V04.md` for game flow, testing and handoff.

## Companion prototype
Seyoon is a single proof-of-concept NPC, not a final cast. Recruiting has benefits (rest recovery +5) and costs (food +1 and water +1 daily). Her trust responds to rationing and can trigger departure. Affection is stored but romance is **not yet implemented**.

## System / Local AI boundary
- **GameEngine** is authoritative for probabilities, inventory, death, daily consumption and NPC mechanical outcomes.
- **GameState** is serialized and saved locally with a schema version. An unresolved encounter can be saved and resumed.
- **AiScene** is a deliberately small read-only projection of the already resolved event.
- **AiNarrator** may later run an on-device Korean language model but can only return 1–2 flavor sentences. No model is shipped in v0.1.
- Model failures, overheating concerns, missing RAM, or unsupported devices must never prevent gameplay. Local AI must be opt-in and disabled by default; inference requires separate on-device benchmarking.

## Next systems (outside v0.1)
1. More structured exploration/event choices and condition-based storylets.
2. Real NPC personality differences, needs, autonomous intentions and romance (currently only a single companion prototype).
3. Safe NPC intent validator before any AI-proposed action is allowed.
4. Low-end-device benchmark, then optional local AI model selection and fallback.
5. More varied loot, injuries, event chains, difficulty balancing.

## Seven-week plan
Week 1: Flutter source + baseline engine + tests. Week 2: balance/resources/encounter content. Week 3: inventory and event data. Week 4: NPC and relationship rules. Week 5: local AI feasibility (only if mobile testing passes). Week 6: event variety, UI polish and storylets. Week 7: stability, device thermals, release candidate.
