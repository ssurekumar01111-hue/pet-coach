import { CoachFeedbackProvider, FetchImplementation } from './types.js';

export class GeminiProvider implements CoachFeedbackProvider {
  constructor(
    private readonly apiKey: string,
    private readonly fetchImplementation: FetchImplementation = fetch,
  ) {}

  async generateFeedback(prompt: string): Promise<unknown> {
    const endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent';
    console.info('Gemini request configuration', {
      apiKeyLength: this.apiKey.length,
      endpoint,
    });
    const response = await this.fetchImplementation(
      endpoint,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': this.apiKey,
        },
        body: JSON.stringify({
          contents: [{parts: [{text: prompt}]}],
          generationConfig: {maxOutputTokens: 400, responseMimeType: 'application/json'},
        }),
      },
    );
    if (!response.ok) throw new Error(`Gemini request failed (${response.status})`);
    const payload = await response.json() as { candidates?: Array<{ content?: { parts?: Array<{ text?: unknown }> } }> };
    const text = payload.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== 'string') throw new Error('Gemini response did not contain text');
    return text;
  }
}
