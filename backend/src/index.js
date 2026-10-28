// Dead Day Gemini API proxy (Cloudflare Worker).
// Gemini keys NEVER belong in Flutter, public git, URLs, or browser code.
// This endpoint is for a PRIVATE TEST BUILD ONLY: the demonstration bearer
// credential is extractable from a distributed binary.
// Before public release replace demo auth with verified user identity,
// per-user quotas, abuse controls, and centralized daily Gemini budgets.

const GEMINI_HOST = "https://generativelanguage.googleapis.com";
const DEFAULT_MODEL = "gemini-2.5-flash-lite";
const MAX_PROMPT_CHARS = 6000;
const MAX_BODY_CHARS = 7500;

const SYSTEM_INSTRUCTION = [
  "당신은 DEAD DAY라는 한국어 좀비 생존 게임의 사건 디렉터다.",
  "전달된 시나리오의 규칙과 과거 선택을 존중한다.",
  "짧고 구체적인 사건 도입부 하나만 생성한다.",
  "결말, 자원 변화, 사망, 전투 결과를 결정하지 않는다.",
  "인물 관계는 인과적으로 일관되어야 한다.",
  "타입은 허용 목록에서만 선택하고 JSON 객체 한 개로 대답한다.",
].join("\n");

function json(status, body, origin) {
  const headers = {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  };
  if (origin) {
    headers["access-control-allow-origin"] = origin;
    headers["vary"] = "Origin";
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function isAuthorized(request, env) {
  // No unauthenticated mode, even when a secret was forgotten.
  return typeof env.DEMO_ACCESS_TOKEN === "string" &&
    env.DEMO_ACCESS_TOKEN.length >= 24 &&
    request.headers.get("authorization") === "Bearer " + env.DEMO_ACCESS_TOKEN;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const requestOrigin = request.headers.get("origin");
    const origin = requestOrigin && requestOrigin === env.ALLOWED_WEB_ORIGIN
      ? requestOrigin : null;

    if (request.method === "OPTIONS") {
      if (!origin) return new Response(null, { status: 403 });
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": origin,
          "access-control-allow-methods": "POST, OPTIONS",
          "access-control-allow-headers": "authorization, content-type",
          "access-control-max-age": "600",
          vary: "Origin",
        },
      });
    }

    if (url.pathname !== "/v1/director" || request.method !== "POST") {
      return json(404, { error: "not_found" }, origin);
    }
    if (requestOrigin && !origin) {
      return json(403, { error: "origin_not_allowed" }, null);
    }
    if (!isAuthorized(request, env)) {
      return json(401, { error: "unauthorized" }, origin);
    }
    if (!env.GEMINI_API_KEY) {
      return json(503, { error: "not_configured" }, origin);
    }
    if (!request.headers.get("content-type")?.startsWith("application/json")) {
      return json(415, { error: "json_required" }, origin);
    }
    const advertisedLength = Number(request.headers.get("content-length") || 0);
    if (advertisedLength > MAX_BODY_CHARS) {
      return json(413, { error: "body_too_large" }, origin);
    }
    const raw = await request.text();
    if (raw.length > MAX_BODY_CHARS) {
      return json(413, { error: "body_too_large" }, origin);
    }
    let body;
    try {
      body = JSON.parse(raw);
    } catch (_) {
      return json(400, { error: "invalid_json" }, origin);
    }
    const prompt = body?.prompt;
    const maxOutputTokens = body?.maxOutputTokens;
    const temperature = body?.temperature;
    if (typeof prompt !== "string" || prompt.length < 10 ||
        prompt.length > MAX_PROMPT_CHARS ||
        !Number.isInteger(maxOutputTokens) ||
        maxOutputTokens < 32 || maxOutputTokens > 256 ||
        typeof temperature !== "number" ||
        temperature < 0 || temperature > 1.2) {
      return json(400, { error: "invalid_parameters" }, origin);
    }

    // Bound prototype abuse without pretending this is a global daily quota.
    const limiter = env.DEMO_RATE_LIMITER;
    if (!limiter) return json(503, { error: "rate_limiter_missing" }, origin);
    const limitResult = await limiter.limit({ key: "private-prototype" });
    if (!limitResult.success) {
      return json(429, { error: "prototype_rate_limit" }, origin);
    }

    const model = env.GEMINI_MODEL || DEFAULT_MODEL;
    const payload = {
      systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        maxOutputTokens,
        temperature,
      },
    };
    let upstream;
    try {
      upstream = await fetch(
        GEMINI_HOST + "/v1beta/models/" + encodeURIComponent(model) +
          ":generateContent",
        {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": env.GEMINI_API_KEY,
          },
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(20000),
        },
      );
    } catch (_) {
      return json(503, { error: "upstream_unavailable" }, origin);
    }

    if (!upstream.ok) {
      // Never echo upstream error bodies, which may contain sensitive info.
      const status = upstream.status === 429 ? 429 : 503;
      return json(status, {
        error: upstream.status === 429
          ? "gemini_quota_exceeded" : "gemini_upstream_error",
      }, origin);
    }

    try {
      const response = await upstream.json();
      const text = response?.candidates?.[0]?.content?.parts
        ?.filter((part) => typeof part.text === "string")
        .map((part) => part.text).join("") ?? "";
      if (!text || text.length > 1500) {
        return json(503, { error: "invalid_model_response" }, origin);
      }
      return json(200, { text }, origin);
    } catch (_) {
      return json(503, { error: "invalid_model_response" }, origin);
    }
  },
};
