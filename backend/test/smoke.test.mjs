import { test } from "node:test";
import assert from "node:assert/strict";
import { runSmoke } from "../scripts/smoke.mjs";

const token = "private-smoke-token-longer-than-24";

test("smoke CLI authenticates, checks readiness and generates one scene", async () => {
  const records = [];
  const requests = [];
  const http = async (url, options) => {
    requests.push({ url: String(url), options });
    if (String(url).endsWith("/v1/health")) {
      return new Response(JSON.stringify({
        ready: true, model: "test-model", mode: "private-prototype",
        service: "dead-day-proxy",
      }), { status: 200 });
    }
    const body = JSON.parse(options.body);
    assert.equal(body.context.day, 1);
    assert.equal(body.context.scenario.id, "lost_signal");
    return new Response(JSON.stringify({
      turn: {
        id: "turn_1", story: "서울역의 지하 입구에서 낯선 불빛이 발견됐다. 문은 닫혀 있다.",
        choices: [
          { id: "choice_1", text: "조사한다" },
          { id: "choice_2", text: "지켜본다" },
          { id: "choice_3", text: "기다린다" },
        ],
        generated_elements: [],
      },
      diagnostics: {
        source: "gemini", latency_ms: 500,
        prompt_tokens: 150, output_tokens: 80, total_tokens: 230,
      },
    }), { status: 200 });
  };
  const result = await runSmoke({
    proxyUrl: "https://worker.example/v1/story",
    token, http, report: (record) => records.push(record),
  });
  assert.equal(requests.length, 2); // no-cost health + one billable call
  assert.ok(requests.every(({ options }) =>
    options.headers.authorization === "Bearer " + token));
  assert.equal(result.choice_count, 3);
  assert.equal(result.total_tokens, 230);
  assert.equal(records[0].phase, "health");
  assert.equal(records[1].phase, "story");
  assert.equal(JSON.stringify(records).includes(token), false);
});

test("health failures never attempt a paid API request", async () => {
  let calls = 0;
  await assert.rejects(runSmoke({
    proxyUrl: "https://worker.example/",
    token,
    http: async () => {
      calls++;
      return new Response("not ready", { status: 503 });
    },
  }), /health check failed/);
  assert.equal(calls, 1);
});

test("reject insecure URLs before any network request", async () => {
  let called = false;
  await assert.rejects(runSmoke({
    proxyUrl: "http://insecure.example",
    token,
    http: async () => {
      called = true;
      throw new Error("should not run");
    },
  }), /HTTPS/);
  assert.equal(called, false);
});
