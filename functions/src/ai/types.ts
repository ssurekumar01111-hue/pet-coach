export interface CoachFeedbackResult {
  qualifies: boolean;
  predictedTime: string;
  feedback: string;
  nextTarget: string;
}

export interface RecoverySummary {
  score: number;
  recommendation: string;
}

export interface CoachFeedbackResponse extends CoachFeedbackResult {
  recoverySummary: RecoverySummary;
  qualifiedDeterministic: boolean;
}

export interface QualificationReadinessResult {
  readinessPercent: number;
  trend: 'improving' | 'steady' | 'declining';
  predictedQualificationDate: string;
  summary: string;
}

export interface TrainingPlanDay {
  day: number;
  focus: string;
  target: string;
  notes: string;
}

export interface TrainingPlanResult {
  days: TrainingPlanDay[];
}

export interface DailyTargetResult {
  targetType: 'run' | 'rest' | 'cross-train';
  distanceKm: number | null;
  paceGuidance: string;
  reasoning: string;
}

export interface InjuryRiskAssessmentResult {
  riskLevel: 'low' | 'moderate' | 'elevated';
  riskFactors: string[];
  recommendation: string;
}

export interface SessionSummary {
  examName: string;
  targetDistanceKm: number;
  targetTimeLimitMin: number;
  distanceKm: number;
  totalTimeSec: number;
  runningSegmentCount: number;
  walkingSegmentCount: number;
}

export interface CoachFeedbackProvider {
  generateFeedback(prompt: string): Promise<unknown>;
}

export type FetchImplementation = typeof fetch;
