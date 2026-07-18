import { RecoverySummary } from '../ai/types.js';

export interface RecoverySegmentInput {
  type: string;
  durationSec: number;
}

export interface RecoverySessionInput {
  totalDistanceKm: number;
  totalTimeSec: number;
  segments: RecoverySegmentInput[];
}

/**
 * Rule-based recovery estimate; it does not use an LLM, wearable, or heart-rate
 * data. It makes the rationale clear for candidates and judging: a workout is
 * considered more demanding when it contains a higher proportion of running and
 * when its pace is faster than the candidate's recent average.
 *
 * Formula (bounded to 0..100):
 * - start at 100 recovery points;
 * - subtract up to 45 points for the running-time ratio;
 * - subtract up to 35 points when this run is up to 30% faster than the average
 *   pace of the two or three previous valid sessions;
 * - no historical pace penalty is applied for a first recorded run.
 */
export function calculateRecovery(
  current: RecoverySessionInput,
  previousSessions: RecoverySessionInput[],
): RecoverySummary {
  const runningSeconds = current.segments
      .filter((segment) => segment.type === 'running')
      .reduce((sum, segment) => sum + validSeconds(segment.durationSec), 0);
  const segmentSeconds = current.segments
      .reduce((sum, segment) => sum + validSeconds(segment.durationSec), 0);
  const durationForRatio = segmentSeconds > 0 ? segmentSeconds : validSeconds(current.totalTimeSec);
  const runningRatio = durationForRatio > 0 ? clamp(runningSeconds / durationForRatio, 0, 1) : 0;

  const currentPace = paceOf(current);
  const historicalPaces = previousSessions.map(paceOf).filter((pace): pace is number => pace != null);
  const historicalAverage = historicalPaces.length === 0
      ? null
      : historicalPaces.reduce((sum, pace) => sum + pace, 0) / historicalPaces.length;
  // A lower seconds-per-km value is faster. Only faster-than-average pace adds load.
  const fasterFraction = currentPace != null && historicalAverage != null
      ? clamp((historicalAverage - currentPace) / historicalAverage, 0, .30) / .30
      : 0;

  const score = Math.round(clamp(100 - (runningRatio * 45) - (fasterFraction * 35), 0, 100));
  return {
    score,
    recommendation: score >= 70
        ? 'Ready for next session'
        : score >= 45
            ? 'Rest 1 day'
            : 'Rest 2 days',
  };
}

function validSeconds(value: number): number {
  return Number.isFinite(value) && value > 0 ? value : 0;
}

function paceOf(session: RecoverySessionInput): number | null {
  if (!Number.isFinite(session.totalDistanceKm) || !Number.isFinite(session.totalTimeSec) ||
      session.totalDistanceKm <= 0 || session.totalTimeSec <= 0) {
    return null;
  }
  return session.totalTimeSec / session.totalDistanceKm;
}

function clamp(value: number, lower: number, upper: number): number {
  return Math.min(Math.max(value, lower), upper);
}
