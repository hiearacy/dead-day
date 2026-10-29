import { test } from "node:test";
import assert from "node:assert/strict";
import { handleStory } from "../src/story_route.js";
import { GeminiProvider } from "../src/gemini_provider.js";
import worker from "../src/index.js";

const context = {
  scenario: {
    title: "마지막 송신", premise: "서울역에서 생존한다.",
    rules: ["좀비는 소리를 따라온다."],
  },
  day: 4, location_id: "start_seoul", region: "서울",
  generated_elements: [], memories: [], recent_turns: [],
  player: { health: 100, food: 4, water: 4 },
};
const proposed = {
  story: "서울역 구석에서 B3 구역으로 내려가는 문을 발견했다. "
    + "통제실 내부에는 오래된 지도와 작동 중인 전등이 보인다.",
  choices: [
    { text: "B3 구역으로 이동한다", intent: "move", target_id: "location_b3" },
    { text: "통제실 입구를 조사한다", intent: "investigate" },
    { text: "안전한 곳에서 기다린다", intent: "observe" },
  ],
  generated_elements: [
    {
      id: "location_b3", name: "서울역 B3 구역", kind: "location",
      description: "폐쇄된 통제 구역", parentId: "start_seoul",
    },
  ],
};

test("provider-neutral route returns a complete structured StoryTurn", async () => {
  const provider = { generateStory: async () => proposed };
  const response = await handleStory({ context }, {}, null, provider);
  assert.equal(response.status, 200);
  const { turn } = await response.json();
  assert.match(turn.story, /B3/);
  assert.equal(turn.choices.length, 3);
  assert.equal(turn.choices[0].id, "choice_1");
  assert.equal(turn.generated_elements[0].origin, "ai_generated");
  assert.equal(turn.generated_elements[0].createdDay, 4);
  assert.equal(turn.generated_elements[0].id, "location_b3");
});

test("story route rejects malformed contexts and model outputs", async () => {
  const provider = { generateStory: async () => proposed };
  const invalid = await handleStory({ context: { ...context, day: -2 } },
    {}, null, provider);
  assert.equal(invalid.status, 400);
  const bad = await handleStory({ context }, {}, null, {
    generateStory: async () => ({ ...proposed, choices: [] }),
  });
  assert.equal(bad.status, 503);
});

test("GeminiProvider uses configured model and holds the key server-side", async () => {
  const env = { GEMINI_API_KEY: "secret-mock", GEMINI_MODEL: "test-gemini-model" };
  const provider = new GeminiProvider(env, async (url, options) => {
    assert.match(url, /test-gemini-model:generateContent/);
    assert.equal(options.headers["x-goog-api-key"], "secret-mock");
    const body = JSON.parse(options.body);
    assert.match(body.contents[0].parts[0].text, /서울역/);
    assert.equal(body.generationConfig.responseMimeType, "application/json");
    assert.equal(body.generationConfig.responseJsonSchema.properties.choices.minItems, 3);
    assert.equal(body.generationConfig.responseJsonSchema.properties.choices.maxItems, 3);
    assert.deepEqual(
      body.generationConfig.responseJsonSchema.properties.choices.items.properties.intent.enum,
      ["investigate", "move", "talk", "observe", "collect"],
    );
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: JSON.stringify(proposed) }] } }],
    }), { status: 200 });
  });
  const response = await provider.generateStory(context);
  assert.equal(response.generated_elements[0].id, "location_b3");
});

test("full Worker route authenticates and rate-limits the story endpoint", async () => {
  const url = "https://dead-day.example.workers.dev/v1/story";
  const env = {
    DEMO_ACCESS_TOKEN: "a-secret-that-is-at-least-32-characters",
    GEMINI_API_KEY: "mock-api-key",
    GEMINI_MODEL: "test-model",
    DEMO_RATE_LIMITER: { limit: async () => ({ success: false }) },
  };
  const req = new Request(url, {
    method: "POST",
    headers: {
      authorization: "Bearer " + env.DEMO_ACCESS_TOKEN,
      "content-type": "application/json",
    },
    body: JSON.stringify({ context }),
  });
  const result = await worker.fetch(req, env);
  assert.equal(result.status, 429);
  const body = await result.json();
  assert.equal(body.error, "prototype_rate_limit");
});

test("unauthenticated story requests are rejected before provider calls", async () => {
  const response = await worker.fetch(
    new Request("https://dead-day.example.workers.dev/v1/story", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ context }),
    }),
    { GEMINI_API_KEY: "key", GEMINI_MODEL: "test" },
  );
  assert.equal(response.status, 401);
});

test("server rejects invalid AI targets before returning player choices", async () => {
  for (const modified of [
    { ...proposed, choices: proposed.choices.map((c, i) =>
        i === 0 ? { ...c, target_id: "invented_fake_exit" } : c) },
    { ...proposed, choices: proposed.choices.map((c, i) =>
        i === 0 ? { ...c, intent: "collect", target_id: "location_b3" } : c) },
    { ...proposed, choices: [proposed.choices[0], proposed.choices[0], proposed.choices[2]] },
    { ...proposed, generated_elements: [
        proposed.generated_elements[0], proposed.generated_elements[0],
      ] },
    { ...proposed, generated_elements: [{
        ...proposed.generated_elements[0], parentId: "nonexistent_parent",
      }] },
  ]) {
    const result = await handleStory({ context }, {}, null, {
      generateStory: async () => modified,
    });
    assert.equal(result.status, 503);
    assert.equal((await result.json()).error, "story_generation_unavailable");
  }
});

test("server accepts coherent item pickup proposal", async () => {
  const value = {
    ...proposed,
    generated_elements: [{
      id: "item_radio", name: "고장 난 무전기",
      kind: "item", description: "응급 호출에 쓰던 구형 무전기",
      parentId: "start_seoul",
    }],
    choices: [
      { text: "무전기를 챙긴다", intent: "collect", target_id: "item_radio" },
      { text: "흔적을 조사한다", intent: "investigate", target_id: null },
      { text: "숨어 기다린다", intent: "observe", target_id: null },
    ],
  };
  const response = await handleStory({ context }, {}, null, {
    generateStory: async () => value,
  });
  assert.equal(response.status, 200);
  const { turn } = await response.json();
  assert.equal(turn.choices[0].target_id, "item_radio");
  assert.equal(turn.generated_elements[0].kind, "item");
});
