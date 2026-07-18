import { GeminiProvider } from './geminiProvider.js';
import { OpenAiProvider } from './openaiProvider.js';
import { CoachFeedbackProvider, FetchImplementation } from './types.js';

export type AiProviderName = 'openai' | 'gemini';

export function selectedProviderName(value: unknown): AiProviderName {
  return value === 'openai' ? 'openai' : 'gemini';
}

export function createCoachFeedbackProvider(
  requestedProvider: unknown,
  apiKeys: {openai: string; gemini: string},
  fetchImplementation?: FetchImplementation,
): CoachFeedbackProvider {
  if (selectedProviderName(requestedProvider) === 'gemini') {
    return new GeminiProvider(apiKeys.gemini, fetchImplementation);
  }
  return new OpenAiProvider(apiKeys.openai, fetchImplementation);
}
