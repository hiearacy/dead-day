import { GeminiProvider } from "./gemini_provider.js";

function reply(status, body, origin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...(origin ? { "access-control-allow-origin": origin, vary: "Origin" } : {}),
    },
  });
}

function validContext(context) {
  return context && typeof context === "object" &&
    typeof context.day === "number" &&
    context.day >= 1 && context.day <= 100000 &&
    typeof context.location_id === "string" &&
    context.location_id.length <= 90 &&
    typeof context.region === "string" && context.region.length <= 100 &&
    typeof context.scenario?.premise === "string" &&
    context.scenario.premise.length <= 1200 &&
    Array.isArray(context.scenario?.rules) &&
    Array.isArray(context.generated_elements) &&
    context.generated_elements.length <= 50 &&
    Array.isArray(context.memories) && context.memories.length <= 12 &&
    Array.isArray(context.recent_turns) && context.recent_turns.length <= 4;
}

// Validate cross-references here as a cheap early rejection, then recheck
// against *authoritative* full GameState in Flutter. The client never trusts
// that the server has seen every element in the saved world.
function validateAndNormalizeStory(raw, context) {
  if (!raw || typeof raw !== "object" ||
      typeof raw.story !== "string" || raw.story.trim().length < 20 ||
      raw.story.length > 1800 || /[\u0000-\u0009\u000b-\u001f]/.test(raw.story) ||
      !Array.isArray(raw.choices) || raw.choices.length !== 3 ||
      !Array.isArray(raw.generated_elements) ||
      raw.generated_elements.length > 2) {
    throw new Error("invalid_story_schema");
  }
  const known = new Map([[context.location_id, "location"]]);
  const knownNames = new Set();
  for (const old of context.generated_elements) {
    if (old && typeof old.id === "string" && typeof old.kind === "string") {
      known.set(old.id, old.kind);
      if (typeof old.name === "string") knownNames.add(old.name.trim().toLowerCase());
    }
  }
  const generated = raw.generated_elements.map((element) => {
    if (!element || typeof element.id !== "string" ||
        !/^[a-z][a-z0-9_]{2,63}$/.test(element.id) ||
        typeof element.name !== "string" ||
        !element.name.trim() || element.name.length > 70 ||
        typeof element.description !== "string" ||
        element.description.length > 300 ||
        !["location", "character", "item", "clue", "event"].includes(element.kind) ||
        known.has(element.id) || knownNames.has(element.name.trim().toLowerCase()) ||
        (element.parentId != null && typeof element.parentId !== "string") ||
        (element.parentId != null && !known.has(element.parentId))) {
      throw new Error("invalid_generated_element");
    }
    known.set(element.id, element.kind);
    knownNames.add(element.name.trim().toLowerCase());
    return {
      id: element.id, name: element.name.trim(), kind: element.kind,
      description: element.description,
      parentId: element.parentId ?? null,
      createdDay: context.day, discovered: true, origin: "ai_generated",
    };
  });
  const usedChoiceTexts = new Set();
  const choices = raw.choices.map((choice, index) => {
    if (!choice || typeof choice.text !== "string" ||
        choice.text.trim().length < 3 || choice.text.length > 120 ||
        /[\u0000-\u001f]/.test(choice.text) ||
        !["investigate", "move", "talk", "observe", "collect"].includes(choice.intent)) {
      throw new Error("invalid_choice_schema");
    }
    const text = choice.text.trim();
    if (usedChoiceTexts.has(text)) throw new Error("duplicate_choice");
    usedChoiceTexts.add(text);
    const target = choice.target_id ?? null;
    if (target !== null && typeof target !== "string") {
      throw new Error("invalid_choice_target");
    }
    if (choice.intent === "move" && (!target || known.get(target) !== "location")) {
      throw new Error("invalid_move_target");
    }
    if (choice.intent === "collect" && (!target || known.get(target) !== "item")) {
      throw new Error("invalid_collect_target");
    }
    if (target && !known.has(target)) throw new Error("unknown_choice_target");
    return {
      id: "choice_" + (index + 1),
      text,
      intent: choice.intent,
      target_id: target,
    };
  });
  return {
    id: "world_turn_" + context.day + "_" +
      Math.random().toString(36).slice(2, 10),
    story: raw.story,
    choices, generated_elements: generated,
  };
}

/// Called after origin, bearer, Gemini secret and rate limit checks by index.
export async function handleStory(body, env, origin, provider = new GeminiProvider(env)) {
  const context = body?.context;
  if (!validContext(context) || JSON.stringify(context).length > 8500) {
    return reply(400, { error: "invalid_story_context" }, origin);
  }
  try {
    const raw = await provider.generateStory(context);
    const turn = validateAndNormalizeStory(raw, context);
    return reply(200, { turn }, origin);
  } catch (error) {
    const code = error?.message === "gemini_quota_exceeded"
      ? "gemini_quota_exceeded" : "story_generation_unavailable";
    return reply(code === "gemini_quota_exceeded" ? 429 : 503,
      { error: code }, origin);
  }
}
