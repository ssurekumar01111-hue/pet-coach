import { defineSecret } from 'firebase-functions/params';

// Configure provider credentials with `firebase functions:secrets:set` before deployment.
export const openAiApiKey = defineSecret('OPENAI_API_KEY');
export const geminiApiKey = defineSecret('GEMINI_API_KEY');
