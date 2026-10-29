// Small, provider-neutral JSON Schema for complete story-turn replies.
// Keep this compatible with Gemini structured output; gameplay validity is
// checked separately in story_route.js and again by the Dart game engine.
export const STORY_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    story: { type: "string", description: "한국어 사건 도입 120~600자, 선택 결과 미확정" },
    choices: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: {
        type: "object",
        properties: {
          text: { type: "string", description: "플레이어 행동 선택지" },
          intent: { type: "string", enum: ["investigate", "move", "talk", "observe", "collect"] },
          target_id: { type: ["string", "null"], description: "대상 ID, 없으면 null" },
        },
        required: ["text", "intent", "target_id"],
      },
    },
    generated_elements: {
      type: "array",
      maxItems: 2,
      items: {
        type: "object",
        properties: {
          id: { type: "string", description: "영문 소문자로 시작하는 고유 식별자" },
          name: { type: "string", description: "한국어 요소 이름" },
          kind: { type: "string", enum: ["location", "character", "item", "clue", "event"] },
          description: { type: "string", description: "짧은 정체성과 위치/관계 설명" },
          parentId: { type: ["string", "null"], description: "현 위치, 알려진 상위 위치 또는 null" },
        },
        required: ["id", "name", "kind", "description", "parentId"],
      },
    },
  },
  required: ["story", "choices", "generated_elements"],
};
