# Dead Day v0.9 — Live Gemini private smoke test

## What this stage adds
A verified base Android and Web build already exists in GitHub Actions.
v0.9 adds the deployment *readiness* tools needed to safely test a real
Gemini-backed story turn without putting the API key inside Flutter.

- Authenticated **GET /v1/health** returns model and configuration readiness
  (no Gemini call; no API key or secret values).
- **POST /v1/story** returns a complete validated scene and optional
  `diagnostics` with numeric Gemini latency/token counts.
- Flutter displays whether a scene came from **Gemini** or the **offline rule
  fallback**, rather than claiming every scene is AI-authored.
- `npm run smoke` calls health then sends **exactly ONE** sample story
  request; this does consume one real Gemini request if the server is ready.
- Fake-response Node/Dart tests never use a paid service.

## Private developer setup
**Required developer-owned settings** — not stored in GitHub:
1. Create the Gemini key in the Google AI Studio account you control.
2. Configure Cloudflare Worker secrets (from `backend/`):
   ```bash
   npm install
   npx wrangler login
   npx wrangler secret put GEMINI_API_KEY
   npx wrangler secret put DEMO_ACCESS_TOKEN
   npm run deploy
   ```
3. Ensure `GEMINI_MODEL` is configured in `backend/wrangler.toml`.
   The free-tier eligible model and per-project quota must be checked in
   Google AI Studio, not assumed. Do not enable paid billing inadvertently.
4. Export your private Worker URL and the *test* bearer credential to your
   **local shell environment**, not source files or CI logs.

**PowerShell private test example**:
```powershell
cd backend
$env:DEAD_DAY_PROXY_URL = "https://YOUR_WORKER.workers.dev"
$env:DEAD_DAY_DEMO_TOKEN = Read-Host "Enter the private test token"
npm run smoke
Remove-Item Env:DEAD_DAY_DEMO_TOKEN
```

**Bash private test example**:
```bash
cd backend
export DEAD_DAY_PROXY_URL="https://YOUR_WORKER.workers.dev"
read -r -s -p "Private test token: " DEAD_DAY_DEMO_TOKEN
echo
export DEAD_DAY_DEMO_TOKEN
npm run smoke
unset DEAD_DAY_DEMO_TOKEN
```

Run `npm test` before `npm run smoke`. The smoke utility uses a synthetic
scenario, not any user's saved game or private messages.

## Expected smoke output
Two compact JSON lines:
```json
{"phase":"health","ready":true,"model":"...","mode":"private-prototype"}
{"phase":"story","valid":true,"source":"gemini","elapsed_ms":1500,"backend_latency_ms":1200,"prompt_tokens":400,"output_tokens":120,"total_tokens":520,"choice_count":3,"generated_element_count":1}
```
These metrics are **illustrative**, not measured output. If the request is
rejected (401, 429, 503 or invalid JSON), the script fails and does not claim
that the Gemini connection works. An actual response is required.

The game itself falls back to a local procedural scene on API errors and
displays the source label. This is a rule-based fallback **without a local AI
model**.

## In-app private test
The Worker has `/v1/story`. Flutter's private test configuration:
```bash
flutter run --dart-define=DEAD_DAY_AI_PROXY_URL=https://YOUR_WORKER.workers.dev/v1/story --dart-define=DEAD_DAY_PRIVATE_DEMO_TOKEN=YOUR_PRIVATE_TEST_TOKEN
```
**This shared test token can be extracted from compiled Flutter builds.**
Do not upload this build to a store, distribute it to others, or publish a
Web client containing the token. A public game needs server-verified user
sessions, per-user quotas, abuse monitoring and centralized daily budgets.

On screen, the scene footer should show Gemini API generation only on
successful remote generation accepted by the game engine. If the API fails,
or the generated turn is inconsistent with the world, it should visibly show
the procedural fallback.

## Compare story quality (manual testing)
For a first 5–10 minute session, record:
- 3 or more consecutive choices and consequences
- Do newly created locations reappear consistently?
- Are NPC motives and clues consistent with past decisions?
- Are there repeated similar scenes?
- Median/slowest Gemini latency and usage tokens
- Does a forced offline or 429 response keep progress playable?
- Does a save/load cycle preserve the same unresolved turn?

Nothing in this commit deploys the Worker or invokes a real Gemini request
without developer-provided secrets and explicit local execution.
