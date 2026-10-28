# Dead Day v0.6 — Gemini incidents with player agency

## What has changed
Previously `EventProposal` immediately changed a game stat. This created an
uninteresting experience: Gemini narrated an event but the player could not
decide how to react.

Now **AI proposes the situation, engine offers fixed meaningful choices,
player selects, engine resolves it, causal memory keeps the decision**.

```text
Every fourth completed day (when no other choice is pending)
                ↓
Gemini proxy or lightweight procedural fallback
                ↓
EventProposal(type, premise, locationId, npcName)
                ↓
DirectedEventSystem.rejection + rarity validation
                ↓
GameState.pendingDirectedEvent = PendingDirectedEvent(choices[])
                ↓
UI/UX team displays chat message + buttons
                ↓
GameAction.chooseDirectedEvent(choiceId)
                ↓
GameEngine.execute validates the ID, applies rule-bound effects
                ↓
StoryMemory, ChatMessage, GameEventRecord and save are updated
                ↓
The next Gemini request includes relevant player decisions
```

## Supported prototype event categories
| Event type | Example two-way choice | System-owned consequences |
| --- | --- | --- |
| hiddenSupplies | Inspect vs leave | Gain food with noise vs no risk |
| taintedWater | Discard vs keep; disinfect if medicine available | Water loss vs health risk vs medicine expense |
| strangeBroadcast | Record vs turn off | Noise risk vs silence |
| strangerAtDoor | Give food if available vs refuse | Food loss vs noise |
| companionConflict | Hear them out vs dismiss | Companion trust changes |
| unsettlingEncounter | Barricade vs investigate | Noise vs injury |

The premise is free-form within the scenario, but the model cannot invent a
new mechanical outcome. Unknown option IDs and duplicate decisions are
rejected by `GameEngine`. Each outcome records causal memory under the
`director` tag so future story generation knows what happened.

## Persistence and compatibility
- `GameState.pendingDirectedEvent` stores the complete event and two or
  more **typed choices**, including if the player closes the app.
- `GameState.waitingForChoice` now includes pending directed incidents.
  While pending, exploration, rest, healing and other incidents are blocked
  until resolved.
- The JSON schema is now v5. Saves from v1/v2/v3/v4 still migrate; no
  server save or web account is required.
- The saved message feed is still just presentation data. AI animations
  must never consume turns.

## UI/UX designer handoff
Current Flutter screen includes temporary functional buttons below the event
premise. **The UI/UX designer owns the eventual conversational layout,
blinking caret, streaming-like typewriter, button chips, scroll anchoring and
reduced-motion support.** The UI must call
`controller.chooseDirectedEvent(choice.id)` and render
`state.pendingDirectedEvent.choices`. The UI must never compute rewards.

## AI API and cost
- Gemini currently generates an event proposal *only* on eligible completed
  days. A story or combat decision does not trigger a new AI event.
- The game continues offline or when the API returns 429, using
  `ProceduralEventDirector`; it also avoids repeating recent event types.
- Do not embed a Gemini API key in Flutter. A secret-holding proxy is already
  in `backend/`, but still needs developer deployment and private test auth.
- Gemini free-tier project quotas can change. Use the platform's actual rate
  limits and production-grade authentication before public release.

## Next evaluation
Run a 10–15 minute demo play, then judge:
- Does the player hesitate between options?
- Do characters react to their previous decisions?
- Do recent event types and premises become repetitive?
- Does Gemini generate prompts aligned to the selected scenario?
- What is the API latency, free-tier usage and failure rate?

## Current limitations
This remains a **prototype with rule-owned consequences**. Gemini cannot yet
invent arbitrarily many new mechanical archetypes or multi-step NPC dialogue.
The active scenario threads remain authored (radio/visitor). These are
deliberate scope limits for a seven-week project. Flutter builds and
live Gemini calls still require environment-specific validation.
