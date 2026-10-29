import { LlmProvider } from "./llm_provider.js";

const ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/";
const GUIDANCE = [
  "너는 DEAD DAY의 세계관을 확장하는 한국어 인터랙티브 스토리 작가다.",
  "시나리오는 완성된 사건 목록이 아니라 창작의 경계와 재료다.",
  "기존 GameState, 장소, 인물, 단서, 이미 일어난 결정과 모순되지 마라.",
  "새로운 장소, 인물, 사물, 단서, 사건을 자유롭게 창작할 수 있다.",
  "신규 요소는 generated_elements에 선언하라. 기존 ID를 바꾸거나 덮어쓰지 마라.",
  "플레이어에게 없는 아이템을 가졌다고 주장하지 마라.",
  "새 장소를 창작할 수 있지만 플레이어를 그곳으로 이동시킨 것은 아니다.",
  "플레이어가 알 수 없는 비밀을 확정된 사실처럼 서술하지 마라.",
  "사건은 해결 직전에서 멈추고 서로 다른 방향의 선택지 정확히 3개를 제시한다.",
  "각 선택의 intent는 investigate, move, talk, observe, collect 중 하나이다.",
  "collect는 이미 알려진 item ID 또는 이번에 선언한 item ID를 target_id에 적는다.",
  "move는 이미 알려진 location ID 또는 이번 생성에서 추가한 location ID를 target_id에 적는다.",
  "기존 엔진이 자원 소비, 생사, 이동, 관계 수치를 결정한다. AI는 결말을 강제하지 않는다.",
  "최근 이야기의 반복을 피하고 이전 플레이어 선택의 흔적을 자연스럽게 반영한다.",
  "전체 답변은 JSON 객체 하나로만 출력한다.",
].join("\n");

export class GeminiProvider extends LlmProvider {
  constructor(env, requestFetch = fetch) {
    super();
    this.env = env;
    this.requestFetch = requestFetch;
  }

  async generateStory(context) {
    if (!this.env.GEMINI_API_KEY || !this.env.GEMINI_MODEL) {
      throw new Error("provider_not_configured");
    }
    const prompt = JSON.stringify({
      instructions: {
        output: {
          story: "한국어 120~600자 사건 도입, 아직 확정되지 않은 결과는 서술 금지",
          choices: [
            { id: "choice_1", text: "행동 묘사", intent: "move|investigate|talk|observe|collect",
              target_id: "move인 경우 이동 장소의 id, 아니면 null" },
            { id: "choice_2", text: "행동 묘사", intent: "investigate", target_id: null },
            { id: "choice_3", text: "행동 묘사", intent: "observe", target_id: null },
          ],
          generated_elements: [{
            id: "영문 소문자/숫자/언더스코어로 이루어진 새 ID",
            name: "새 요소 이름",
            kind: "location|character|item|clue|event",
            description: "100자 내외 설명",
            parentId: "현 위치 id 또는 다른 기존 장소 id, 없으면 null",
          }],
        },
        note: "새 요소 0~2개. 모든 항목은 현재 배경과 논리적으로 연결되어야 한다.",
      },
      context,
    });
    const upstream = await this.requestFetch(
      ENDPOINT + encodeURIComponent(this.env.GEMINI_MODEL) + ":generateContent",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": this.env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: GUIDANCE }] },
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            maxOutputTokens: 1024,
            temperature: 0.8,
          },
        }),
        signal: AbortSignal.timeout(24000),
      },
    );
    if (!upstream.ok) {
      if (upstream.status === 429) throw new Error("gemini_quota_exceeded");
      throw new Error("gemini_upstream_error");
    }
    const response = await upstream.json();
    const raw = response?.candidates?.[0]?.content?.parts
      ?.filter((part) => typeof part.text === "string")
      .map((part) => part.text).join("") ?? "";
    if (!raw || raw.length > 9000) throw new Error("invalid_model_response");
    try {
      return JSON.parse(raw);
    } catch (_) {
      throw new Error("invalid_model_json");
    }
  }
}
