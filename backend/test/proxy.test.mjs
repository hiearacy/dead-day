import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";

const url = "https://dead-day.example.workers.dev/v1/director";
const secrets = {
  DEMO_ACCESS_TOKEN: "a-secret-that-is-at-least-32-characters",
  GEMINI_API_KEY: "mock-gemini-key",
  GEMINI_MODEL: "gemini-2.5-flash-lite",
  DEMO_RATE_LIMITER: { limit: async () => ({ success: true }) },
};

function request({ body, token = secrets.DEMO_ACCESS_TOKEN } = {}) {
  return new Request(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + token,
    },
    body: JSON.stringify(body ?? {
      prompt: "A scenario and a few recent memory facts.",
      maxOutputTokens: 128,
      temperature: 0.75,
    }),
  });
}

test("rejects unauthorized client before reaching Gemini", async () => {
  const response = await worker.fetch(request({ token: "wrong" }), secrets);
  assert.equal(response.status, 401);
});

test("rejects requests without server-side secret", async () => {
  const response = await worker.fetch(request(), {
    ...secrets, GEMINI_API_KEY: undefined,
  });
  assert.equal(response.status, 503);
});

test("rejects too-long prompts and unbounded tokens", async () => {
  const response = await worker.fetch(request({
    body: {
      prompt: "X".repeat(6100),
      maxOutputTokens: 900,
      temperature: 0.5,
    },
  }), secrets);
  assert.equal(response.status, 400);
});

test("rejects unknown web origins", async () => {
  const req = request();
  req.headers.set("origin", "https://random.example");
  const response = await worker.fetch(req, secrets);
  assert.equal(response.status, 403);
});

test("Gemini key stays only in upstream request", async () => {
  const originalFetch = globalThis.fetch;
  try {
    globalThis.fetch = async (url, init) => {
      assert.match(String(url), /gemini-2\.5-flash-lite:generateContent/);
      assert.equal(init.headers["x-goog-api-key"], "mock-gemini-key");
      const payload = JSON.parse(init.body);
      assert.equal(payload.generationConfig.responseMimeType, "application/json");
      assert.equal(payload.generationConfig.maxOutputTokens, 128);
      return new Response(JSON.stringify({
        candidates: [{
          content: {
            parts: [{ text: '{"type":"strangerAtDoor","premise":"문 밖에서 노크 소리가 들린다."}' }],
          },
        }],
      }), { status: 200 });
    };
    const response = await worker.fetch(request(), secrets);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.match(body.text, /strangerAtDoor/);
    assert.equal(JSON.stringify(body).includes("mock-gemini-key"), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("Gemini quota errors are safely surfaced as 429", async () => {
  const originalFetch = globalThis.fetch;
  try {
    globalThis.fetch = async () => new Response("quota", { status: 429 });
    const response = await worker.fetch(request(), secrets);
    assert.equal(response.status, 429);
    assert.deepEqual(await response.json(), { error: "gemini_quota_exceeded" });
  } finally {
    globalThis.fetch = originalFetch;
  }
});
