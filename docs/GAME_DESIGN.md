# Dead Day — gameplay contract (v0.1)

## Goal and boundaries
Survive as many full days as possible during a zombie apocalypse. This is an offline-first **mobile text game**, not a world simulator. The playable v0.1 has one shelter, three exploration zones, one recruitable survivor, a combat choice encounter, basic resources and autosave.

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

## Companion prototype
Seyoon is a single proof-of-concept NPC, not a final cast. Recruiting has benefits (rest recovery +5) and costs (food +1 and water +1 daily). Her trust responds to rationing and can trigger departure. Affection is stored but romance is **not yet implemented**.

## System / Local AI boundary
- **GameEngine** is authoritative for probabilities, inventory, death, daily consumption and NPC mechanical outcomes.
- **GameState** is serialized and saved locally with a schema version. An unresolved encounter can be saved and resumed.
- **AiScene** is a deliberately small read-only projection of the already resolved event.
- **AiNarrator** may later run an on-device Korean language model but can only return 1–2 flavor sentences. No model is shipped in v0.1.
- Model failures, overheating concerns, missing RAM, or unsupported devices must never prevent gameplay. Local AI must be opt-in and disabled by default; inference requires separate on-device benchmarking.

## Next systems (outside v0.1)
1. Structured action/result data and event templates rather than only strings.
2. NPC personality / motivation / memory, then constrained autonomous actions.
3. Conditional betrayal, trust, affinity and relationship storylets.
4. Actual low-end-device benchmark, then local AI model selection and safe fallback.
5. More varied loot, injuries, event chains, difficulty balancing.

## Seven-week plan
Week 1: Flutter source + baseline engine + tests. Week 2: balance/resources/encounter content. Week 3: inventory and event data. Week 4: NPC and relationship rules. Week 5: local AI feasibility (only if mobile testing passes). Week 6: event variety, UI polish and storylets. Week 7: stability, device thermals, release candidate.
