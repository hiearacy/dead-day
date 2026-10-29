/// Provider contract. A future OpenAI/Anthropic/local server adapter can
/// implement generateStory without changing Flutter or the game engine.
export class LlmProvider {
  async generateStory(_context) {
    throw new Error("not_implemented");
  }
}
