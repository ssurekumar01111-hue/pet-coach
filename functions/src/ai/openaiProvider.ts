import { CoachFeedbackProvider, FetchImplementation } from './types.js';

export class OpenAiProvider implements CoachFeedbackProvider {
  constructor(
    private readonly apiKey: string,
    private readonly fetchImplementation: FetchImplementation = fetch,
  ) {}

  async generateFeedback(prompt: string): Promise<unknown> {
    const response = await this.fetchImplementation('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-5.6-luna',
        input: prompt,
        max_output_tokens: 400,
      }),
    });
    if (!response.ok) throw new Error(`OpenAI request failed (${response.status})`);
    const payload = await response.json() as {
      output_text?: unknown;
      output?: Array<{ content?: Array<{ text?: unknown }> }>;
    };
    const text = payload.output_text ?? payload.output?.flatMap((item) => item.content ?? []).find((content) => typeof content.text === 'string')?.text;
    if (typeof text !== 'string') throw new Error('OpenAI response did not contain text');
    return text;
  }
}
