import { onCall } from 'firebase-functions/v2/https';

export interface CoachFeedbackRequest {
  sessionId?: string;
  examId: string;
  totalDistanceKm: number;
  totalTimeSec: number;
}

export interface CoachFeedbackResponse {
  qualifies: boolean;
  predictedTime: string;
  feedback: string;
  nextTarget: string;
}

/**
 * AI provider (OpenAI/Gemini) selection logic will be added in the next step.
 * This callable currently returns deterministic placeholder coaching feedback.
 */
export const generateCoachFeedback = onCall<CoachFeedbackRequest>(async (request): Promise<CoachFeedbackResponse> => {
  const { totalTimeSec } = request.data;
  const minutes = Math.floor(totalTimeSec / 60).toString().padStart(2, '0');
  const seconds = (totalTimeSec % 60).toString().padStart(2, '0');
  return {
    qualifies: false,
    predictedTime: `${minutes}:${seconds}`,
    feedback: 'Coach feedback is being prepared. Complete another session to build your baseline.',
    nextTarget: 'Maintain a steady pace for your next practice run.',
  };
});
