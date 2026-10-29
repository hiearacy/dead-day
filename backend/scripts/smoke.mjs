import { pathToFileURL } from "node:url";

const TOKEN_ENV = "DEAD_DAY_DEMO_TOKEN";
const URL_ENV = "DEAD_DAY_PROXY_URL";

function checkBaseUrl(value) {
  const url = new URL(value);
  if (url.protocol !== "https:" &&
      !(url.protocol === "http:" && ["localhost", "127.0.0.1"].includes(url.hostname))) {
    throw new Error("Proxy URL must use HTTPS (except localhost testing)");
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new Error("No credentials, query or fragment allowed in proxy URL");
  }
  url.pathname = "/";
  return url;
}

const privateScenario = {
  scenario: {
    id: "lost_signal", title: "마지막 송신",
    premise: "좀비 사태 이후 서울역 지하에서 구조 신호가 들린다.",
    era: "사태 발발 30일 후",
    tone: "생존 미스터리",
    rules: ["좀비는 소리에 민감하다.", "플레이어의 위치는 엔진이 확정한다."],
    locations: ["서울역 승강장", "통제실"],
    characters: ["구조 신호 발신자"],
    items: ["휴대용 라디오"],
  },
  day: 1,
  location_id: "start_seoul",
  location_name: "서울역 근처 임시 거점",
  region: "서울",
  adjacent_location_ids: [],
  player: { health: 100, food: 5, water: 5, medicine: 1 },
  characters: [], generated_element_count: 0,
  inventory_count: 0, inventory: [],
  generated_elements: [], memories: [], unresolved_threads: [],
  recent_turns: [], latest_choice: "",
};

/// Calls exactly one Gemini story route after a no-cost health probe.
/// Does not print the bearer token, raw context, or actual story contents.
export async function runSmoke({
  proxyUrl, token, http = fetch, report = () => {},
}) {
  if (typeof token !== "string" || token.length < 24) {
    throw new Error("Set a 24+ character private DEMO token in the environment");
  }
  const url = checkBaseUrl(proxyUrl);
  const headers = { authorization: "Bearer " + token };
  const healthUrl = new URL("v1/health", url);
  const healthResponse = await http(healthUrl, {
    method: "GET", headers,
    signal: AbortSignal.timeout(10000),
  });
  if (!healthResponse.ok) {
    throw new Error("Private health check failed (HTTP " +
        healthResponse.status + ")");
  }
  const health = await healthResponse.json();
  if (!health.ready || health.service !== "dead-day-proxy") {
    throw new Error("Backend is not ready for Gemini");
  }
  report({
    phase: "health", ready: true,
    model: health.model, mode: health.mode,
  });

  // One real request: do not use this command for bulk load testing.
  const started = Date.now();
  const storyResponse = await http(new URL("v1/story", url), {
    method: "POST",
    headers: { ...headers, "content-type": "application/json" },
    body: JSON.stringify({ context: privateScenario }),
    signal: AbortSignal.timeout(35000),
  });
  if (!storyResponse.ok) {
    throw new Error("Gemini story request failed (HTTP " +
        storyResponse.status + ")");
  }
  const payload = await storyResponse.json();
  const turn = payload?.turn;
  if (!turn || typeof turn.story !== "string" ||
      turn.story.trim().length < 20 || !Array.isArray(turn.choices) ||
      turn.choices.length !== 3 || !Array.isArray(turn.generated_elements)) {
    throw new Error("Backend returned an invalid StoryTurn");
  }
  const diagnostics = payload.diagnostics ?? {};
  const summary = {
    phase: "story", valid: true,
    source: diagnostics.source ?? "unreported",
    elapsed_ms: Date.now() - started,
    backend_latency_ms: diagnostics.latency_ms ?? null,
    prompt_tokens: diagnostics.prompt_tokens ?? null,
    output_tokens: diagnostics.output_tokens ?? null,
    total_tokens: diagnostics.total_tokens ?? null,
    choice_count: turn.choices.length,
    generated_element_count: turn.generated_elements.length,
  };
  report(summary);
  return summary;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runSmoke({
    proxyUrl: process.env[URL_ENV] || "",
    token: process.env[TOKEN_ENV] || "",
    report: (value) => process.stdout.write(JSON.stringify(value) + "\n"),
  }).catch((error) => {
    // Intentionally no stack trace: credentials may appear in thrown URLs.
    process.stderr.write("Smoke test failed: " + error.message + "\n");
    process.exitCode = 1;
  });
}
