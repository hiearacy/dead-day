# Gemini API setup — Dead Day v0.7 (PRIVATE PROTOTYPE)

## How it works

```text
Flutter (Android/iOS/Web)
     |  /v1/story, short StoryContext JSON, prototype bearer credential
     v
Cloudflare Worker (backend/src/index.js)
     |  server-owned Gemini key + rate-limit demo
     v
LlmProvider.generateStory(context)
     -> GeminiProvider (backend/src/gemini_provider.js)
     -> validated complete JSON: story + 3 choices + generated_elements
     v
Flutter WorldStoryValidator -> GameEngine -> local save -> next StoryContext
```

The old `/v1/director` API remains as a legacy experiment. Fresh game runs
use **`/v1/story`**, not fixed event categories. The frontend sends scenario
rules, current location, survival stats, owned items, relevant generated
world elements, important memories, unresolved threads, recent story excerpts
and the last choice. It never sends the entire chat history.

## Credentials, cost and privacy

**Never commit a Gemini API key to GitHub or place it in Flutter.**
The key belongs in Cloudflare Worker secret `GEMINI_API_KEY`.
The model ID is configured by `GEMINI_MODEL` in `backend/wrangler.toml`
(change it in settings, not in the game source).

Google AI Studio offers eligible free-tier API usage for certain Gemini
models, subject to account/project/model limits that can change. Check
current quota and any billing account before enabling paid usage:
- https://ai.google.dev/gemini-api/docs/pricing
- https://ai.google.dev/gemini-api/docs/rate-limits
- https://aistudio.google.com/apikey

The API sends scenario and game-state content to Google. Free-tier terms may
allow provider product improvement; verify current terms and disclose processing
before public release. Keep real personal information out of story context.

## Deploy a private test Worker

From `backend/` after installing Node.js:

```bash
npm install
npm test
npx wrangler login
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put DEMO_ACCESS_TOKEN
npm run deploy
```

Provide a long random 32+ character `DEMO_ACCESS_TOKEN` via the secret
prompt. Do **not** paste credentials into a GitHub issue, chat, source file,
README, or public CI artifact. This shared demo credential is recoverable
from client binaries and browser JavaScript. **It is only for local/private
developer testing, never for public releases**.

Copy your deployed Worker URL, such as
`https://YOUR_WORKER.workers.dev`.

For a private Android test build:

```bash
flutter run --dart-define=DEAD_DAY_AI_PROXY_URL=https://YOUR_WORKER.workers.dev/v1/story --dart-define=DEAD_DAY_PRIVATE_DEMO_TOKEN=YOUR_PRIVATE_TEST_TOKEN
```

For Web, set Worker `ALLOWED_WEB_ORIGIN` to the exact Flutter Web origin.
CORS is not authentication; the demo token is still unsafe for public sites.

When either configuration value is absent, or the API fails/quota runs out,
`ProceduralWorldStoryProvider` creates basic scenes and keeps the game
playable. No local LLM is downloaded.

## Provider contract

`backend/src/llm_provider.js` defines:

```js
class LlmProvider {
  async generateStory(context) { /* returns a StoryTurn proposal */ }
}
```

`GeminiProvider` uses the server-side `GEMINI_MODEL` variable. A future
provider can implement the same interface; GameEngine never depends on the
model vendor. Complete JSON is returned before the typewriter UI animates
it. There is no streaming-JSON requirement in the MVP.

Story generation asks for three choices with `intent` and optional
`target_id` fields. The backend checks JSON format, and Flutter validates
referential consistency and mechanical actions. **No AI output can directly
edit a resource or inventory value**.

## Required before external distribution

- Real server-verified user authentication (e.g. a verified Firebase token).
- Per-user rate limits and a **centralized daily Gemini budget**.
- Monitoring of input/output tokens, provider latency and request failures.
- Story and privacy safety policy, user notices and content handling.
- API credentials rotated and securely stored.
- Deployed Worker and authenticated client integration actually tested.

The repo includes fake-response tests but **no deployed Worker, live API
key or verified Gemini generation call** in this implementation turn.
