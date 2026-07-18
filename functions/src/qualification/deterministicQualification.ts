/// Determines qualification using only the recorded session totals and the
/// configured exam standard. This deliberately contains no LLM input or
/// judgment: meeting both threshold comparisons is the ground truth.
export function isQualifiedDeterministically(
  totalDistanceKm: number,
  totalTimeSec: number,
  examDistanceKm: number,
  examTimeLimitMin: number,
): boolean {
  return totalDistanceKm >= examDistanceKm &&
      totalTimeSec <= examTimeLimitMin * 60;
}
