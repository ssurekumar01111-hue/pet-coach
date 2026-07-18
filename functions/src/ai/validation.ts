import { CoachFeedbackResult, DailyTargetResult, InjuryRiskAssessmentResult, QualificationReadinessResult, SessionSummary, TrainingPlanResult } from './types.js';

const requiredKeys = ['qualifies', 'predictedTime', 'feedback', 'nextTarget'];

export function buildCoachPrompt(summary: SessionSummary): string {
  return `You are a concise physical-efficiency-test running coach. Analyze only this summarized session data; it contains no raw GPS track.\n\nSession: ${JSON.stringify(summary)}\n\nReturn ONLY valid JSON with this exact schema and no markdown or extra prose:\n{"qualifies":boolean,"predictedTime":string,"feedback":string,"nextTarget":string}\n\nUse supportive, specific feedback. predictedTime must be a human-readable time estimate.`;
}

export function parseCoachFeedback(value: unknown): CoachFeedbackResult {
  let parsed: unknown = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new Error('Response was not valid JSON');
    }
  }
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Response was not a JSON object');
  }
  const record = parsed as Record<string, unknown>;
  if (requiredKeys.some((key) => !(key in record))) {
    throw new Error('Response did not include all required fields');
  }
  if (
    typeof record.qualifies !== 'boolean' ||
    typeof record.predictedTime !== 'string' ||
    typeof record.feedback !== 'string' ||
    typeof record.nextTarget !== 'string' ||
    !record.predictedTime.trim() ||
    !record.feedback.trim() ||
    !record.nextTarget.trim()
  ) {
    throw new Error('Response fields did not match the required schema');
  }
  return {
    qualifies: record.qualifies,
    predictedTime: record.predictedTime,
    feedback: record.feedback,
    nextTarget: record.nextTarget,
  };
}

export function buildQualificationReadinessPrompt(input: Record<string, unknown>): string {
  return `You are a concise PET readiness coach. Analyze only the summarized training history below; it contains no raw GPS tracks. Give a cautious trend-based estimate, never a guarantee.\n\nTraining history: ${JSON.stringify(input)}\n\nReturn ONLY valid JSON with this exact schema and no markdown or extra prose:\n{"readinessPercent":number,"trend":"improving"|"steady"|"declining","predictedQualificationDate":string,"summary":string}\n\nreadinessPercent must be an integer from 0 to 100. summary must be two or three supportive sentences.`;
}

export function parseQualificationReadiness(value: unknown): QualificationReadinessResult {
  let parsed: unknown = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new Error('Response was not valid JSON');
    }
  }
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Response was not a JSON object');
  }
  const record = parsed as Record<string, unknown>;
  if (
    typeof record.readinessPercent !== 'number' ||
    !Number.isFinite(record.readinessPercent) ||
    record.readinessPercent < 0 ||
    record.readinessPercent > 100 ||
    (record.trend !== 'improving' && record.trend !== 'steady' && record.trend !== 'declining') ||
    typeof record.predictedQualificationDate !== 'string' ||
    !record.predictedQualificationDate.trim() ||
    typeof record.summary !== 'string' ||
    !record.summary.trim()
  ) {
    throw new Error('Response fields did not match the readiness schema');
  }
  return {
    readinessPercent: Math.round(record.readinessPercent),
    trend: record.trend,
    predictedQualificationDate: record.predictedQualificationDate,
    summary: record.summary,
  };
}

export function buildTrainingPlanPrompt(input: Record<string, unknown>): string {
  return `You are a concise PET training coach. Create a safe, progressive seven-day plan from the selected exam target and summarized recent sessions below. The data contains no raw GPS tracks. Include recovery-oriented days; do not give medical advice.\n\nPlan input: ${JSON.stringify(input)}\n\nReturn ONLY valid JSON with this exact schema and no markdown or extra prose:\n{"days":[{"day":1,"focus":string,"target":string,"notes":string}]}\n\nReturn exactly seven entries, with day numbers 1 through 7 in order. Keep each field brief and actionable.`;
}

export function parseTrainingPlan(value: unknown): TrainingPlanResult {
  let parsed: unknown = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new Error('Response was not valid JSON');
    }
  }
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Response was not a JSON object');
  }
  const days = (parsed as Record<string, unknown>).days;
  if (!Array.isArray(days) || days.length !== 7) {
    throw new Error('Training plan did not contain seven days');
  }
  const validDays = days.map((value, index) => {
    if (value == null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('Training plan day was invalid');
    }
    const day = value as Record<string, unknown>;
    if (
      day.day !== index + 1 ||
      typeof day.focus !== 'string' || !day.focus.trim() ||
      typeof day.target !== 'string' || !day.target.trim() ||
      typeof day.notes !== 'string' || !day.notes.trim()
    ) {
      throw new Error('Training plan day fields were invalid');
    }
    return {day: day.day, focus: day.focus, target: day.target, notes: day.notes};
  });
  return {days: validDays};
}

export function buildDailyTargetPrompt(input: Record<string, unknown>): string {
  return `You are a concise PET training coach. Recommend only today's activity from the summarized recovery, readiness, and current plan-day context below. Do not give medical advice and do not claim certainty.\n\nDaily context: ${JSON.stringify(input)}\n\nReturn ONLY valid JSON with this exact schema and no markdown or extra prose:\n{"targetType":"run"|"rest"|"cross-train","distanceKm":number|null,"paceGuidance":string,"reasoning":string}\n\nreasoning must be one or two concise sentences. Use null distanceKm for a rest day.`;
}

export function parseDailyTarget(value: unknown): DailyTargetResult {
  let parsed: unknown = value;
  if (typeof value === 'string') {
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new Error('Response was not valid JSON');
    }
  }
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Response was not a JSON object');
  }
  const record = parsed as Record<string, unknown>;
  const validType = record.targetType === 'run' || record.targetType === 'rest' || record.targetType === 'cross-train';
  const validDistance = record.distanceKm === null ||
      (typeof record.distanceKm === 'number' && Number.isFinite(record.distanceKm) && record.distanceKm > 0 && record.distanceKm <= 100);
  if (!validType || !validDistance || typeof record.paceGuidance !== 'string' || !record.paceGuidance.trim() ||
      typeof record.reasoning !== 'string' || !record.reasoning.trim()) {
    throw new Error('Response fields did not match the daily target schema');
  }
  if (record.targetType === 'rest' && record.distanceKm !== null) {
    throw new Error('Rest target must not include a running distance');
  }
  return {
    targetType: record.targetType as DailyTargetResult['targetType'],
    distanceKm: record.distanceKm as number | null,
    paceGuidance: record.paceGuidance,
    reasoning: record.reasoning,
  };
}

export function buildInjuryRiskPrompt(input: Record<string, unknown>): string {
  return `You assess only training-load patterns for a PET runner using the summarized history below. This is NOT a medical diagnosis or injury prediction. Never claim certainty that an injury will occur, do not use alarming language, and do not assume pain or symptoms because none were provided. If riskLevel is elevated, recommend a doctor or physiotherapist only as a cautious option if pain or discomfort is present.\n\nTraining-load context: ${JSON.stringify(input)}\n\nReturn ONLY valid JSON with this exact schema and no markdown or extra prose:\n{"riskLevel":"low"|"moderate"|"elevated","riskFactors":string[],"recommendation":string}\n\nKeep factors grounded only in the provided load, pace, recovery, and rest-compliance data.`;
}

export function parseInjuryRiskAssessment(value: unknown): InjuryRiskAssessmentResult {
  let parsed: unknown = value;
  if (typeof value === 'string') {
    try { parsed = JSON.parse(value); } catch { throw new Error('Response was not valid JSON'); }
  }
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Response was not a JSON object');
  }
  const record = parsed as Record<string, unknown>;
  const validRisk = record.riskLevel === 'low' || record.riskLevel === 'moderate' || record.riskLevel === 'elevated';
  if (!validRisk || !Array.isArray(record.riskFactors) || !record.riskFactors.every((factor) => typeof factor === 'string' && factor.trim()) ||
      typeof record.recommendation !== 'string' || !record.recommendation.trim()) {
    throw new Error('Response fields did not match the injury-risk schema');
  }
  return {
    riskLevel: record.riskLevel as InjuryRiskAssessmentResult['riskLevel'],
    riskFactors: record.riskFactors as string[],
    recommendation: record.recommendation,
  };
}
