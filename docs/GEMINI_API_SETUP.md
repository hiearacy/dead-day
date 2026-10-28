# Dead Day v0.5 — Gemini API switch (PRIVATE TESTING)

The game is now **Flutter (Android/iOS/Web) -> authenticated proxy -> Gemini API**.
No local inference runtime or model downloads are used. Survival, inventory,
choices, NPC mechanics, and story consequences are still local Dart code.

## Why a proxy?
Google explicitly warns not to embed Gemini API keys inside a mobile or web
client. Keys embedded in apps can be extracted and can exhaust your free quota
or create charges if you later turn on billing. The repository contains **no**
Gemini API key. `GEMINI_API_KEY` lives only in the Cloudflare Worker secret.

## Model and free tier
The Worker defaults to `gemini-2.5-flash-lite`, which Google currently lists
with free-tier input/output usage for eligible projects. The **actual**
requests-per-minute, tokens-per-minute, and requests-per-day limits are
project/model-specific: open Google AI Studio's rate limits page and verify
your own values. Google can change these limits. Exceeding the quota typically
causes a 429 and **automatically falls back** to the local *rule-based*
event generator (not a local AI model).

Important privacy limitation: Google's Gemini Developer API **free tier**
may use submitted content to improve Google products. The prototype sends
small scenario/game-state/memory summaries to Gemini; do not send personal
secrets. Review Google's terms and disclose AI processing before public launch.

References:
- https://ai.google.dev/gemini-api/docs/pricing
- https://ai.google.dev/gemini-api/docs/rate-limits
- https://ai.google.dev/gemini-api/docs/api-key
- https://developers.cloudflare.com/workers/platform/pricing/

## Setup (developer action required)
1. At https://aistudio.google.com/apikey create a Gemini API key in a free-tier
   eligible project; **do not paste it in chat or commit it to GitHub**.
2. Create/log in to a Cloudflare account (Workers has a free plan) and on
   your machine run, in `backend/`:
   ```bash
   npm install
   npx wrangler login
   npx wrangler secret put GEMINI_API_KEY
   npx wrangler secret put DEMO_ACCESS_TOKEN
   npm run deploy
   ```
   Generate a random **32+ character** `DEMO_ACCESS_TOKEN` and type it
   into the secret prompt, not into source. This is a **private-prototype
   shared token**, NOT production-grade authentication.
3. Note your deployed `https://...workers.dev` hostname.
4. For a local Android/iOS **private test build only**, configure:
   ```bash
   flutter run \
     --dart-define=DEAD_DAY_AI_PROXY_URL=https://YOUR_WORKER.workers.dev/v1/director \
     --dart-define=DEAD_DAY_PRIVATE_DEMO_TOKEN=YOUR_PRIVATE_TEST_TOKEN
   ```
   Windows PowerShell may need a single line instead. Do not put the token
   in a public screenshot, issue, repository, CI build artifact, or released app.
5. For Flutter Web browser testing, configure the Worker secret or variable
   `ALLOWED_WEB_ORIGIN` to the exact trusted web origin (scheme + host + port).
   An app from any other browser origin is rejected; mobile normally has no
   browser Origin header. Browser CORS is **not** authentication.

If either Dart build setting is omitted, the game uses
`ProceduralEventDirector` and continues without Gemini.

## Security caveat: do not ship the demo token to users
A bearer token in a compiled mobile/browser app is recoverable. The Worker
has approximate 6-request/minute rate limiting for internal testing, but this
is NOT a strict global daily Gemini quota; Cloudflare's rate limit counters
are edge-local. **Before a public release**:
- Replace shared-token auth with server-verified user identity (e.g. Firebase
  Auth ID token verification) and per-user quotas.
- Enforce a strict global daily budget and allowlisting/rate limiting.
- Apply abuse prevention and usage monitoring.
- Review data retention, privacy notices, app terms and API safety filtering.

## Runtime behavior
`AiConfiguration.createDirector()` uses the proxy **only when test config
is supplied**. Otherwise the procedural director remains the default.
On eligible story days:
1. `DirectorContext` builds a short Korean scenario + memory prompt.
2. `GeminiProxyTextGenerator` sends the prompt over HTTPS to your Worker.
3. Worker adds server-owned constraints and calls Gemini generateContent,
   requesting a JSON object (max 128 output tokens by default).
4. `StructuredAiEventDirector` parses and checks the proposed event.
5. `GameEngine` validates world/NPC, checks rarity and applies fixed rule
   effects; the AI never changes stats itself.
6. If network fails, Gemini returns 429, response format breaks or config
   is absent, fall back to deterministic/procedural events. Nothing pauses
   the core survival game.

## Validate
```bash
cd backend
npm install
npm test
```
```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

No remote Worker deployment or real-key API calls are executed from ChatGPT.
Backend tests use fake responses. User must configure secrets and deploy.
