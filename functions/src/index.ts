import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { createCoachFeedbackProvider } from './ai/index.js';
import { consumeDailyAiQuota, consumeDailyReadinessQuota, consumeDailyTrainingPlanQuota, consumeDailyDailyTargetQuota, consumeDailyInjuryRiskQuota, RateLimitStore } from './ai/rateLimiter.js';
import { parseCoachFeedback, buildCoachPrompt, buildQualificationReadinessPrompt, parseQualificationReadiness, buildTrainingPlanPrompt, parseTrainingPlan, buildDailyTargetPrompt, parseDailyTarget, buildInjuryRiskPrompt, parseInjuryRiskAssessment } from './ai/validation.js';
import { CoachFeedbackResult, DailyTargetResult, InjuryRiskAssessmentResult, QualificationReadinessResult, SessionSummary, TrainingPlanResult } from './ai/types.js';
import { geminiApiKey, openAiApiKey } from './config/env.js';
import { calculateRecovery, RecoverySegmentInput, RecoverySessionInput } from './recovery/recoveryCalculator.js';
import { isQualifiedDeterministically } from './qualification/deterministicQualification.js';

if (getApps().length === 0) initializeApp();

interface CoachFeedbackRequest {
  sessionId?: unknown;
  provider?: unknown;
}

interface ReadinessCache {
  readinessPercent?: unknown;
  trend?: unknown;
  predictedQualificationDate?: unknown;
  summary?: unknown;
  generatedAt?: unknown;
}

interface TrainingPlanCache {
  days?: unknown;
  generatedAt?: unknown;
}

interface DailyTargetCache {
  targetType?: unknown;
  distanceKm?: unknown;
  paceGuidance?: unknown;
  reasoning?: unknown;
}

interface InjuryRiskCache {
  riskLevel?: unknown;
  riskFactors?: unknown;
  recommendation?: unknown;
  generatedAt?: unknown;
}

export const generateCoachFeedback = onCall(
  {secrets: [openAiApiKey, geminiApiKey]},
  async (request) => {
    if (request.auth == null) throw new HttpsError('unauthenticated', 'Sign in to request AI coaching feedback.');
    const data = request.data as CoachFeedbackRequest;
    if (typeof data.sessionId !== 'string' || !data.sessionId) {
      throw new HttpsError('invalid-argument', 'A sessionId is required.');
    }

    const database = getFirestore();
    const sessionSnapshot = await database.collection('sessions').doc(data.sessionId).get();
    if (!sessionSnapshot.exists) throw new HttpsError('not-found', 'Session not found.');
    const session = sessionSnapshot.data()!;
    if (session.uid !== request.auth.uid) throw new HttpsError('permission-denied', 'You cannot request feedback for another user’s session.');

    const summary = await buildSessionSummary(database, session);
    validateSessionSummary(summary);
    // Ground-truth qualification is arithmetic against the configured PET
    // standard. It is intentionally independent from the coaching model.
    const qualifiedDeterministic = isQualifiedDeterministically(
      summary.distanceKm,
      summary.totalTimeSec,
      summary.targetDistanceKm,
      summary.targetTimeLimitMin,
    );
    await consumeDailyAiQuota(database as unknown as RateLimitStore, request.auth.uid);
    const recoverySummary = await buildRecoverySummary(
      database,
      sessionSnapshot.id,
      session,
      request.auth.uid,
    );

    const provider = createCoachFeedbackProvider(data.provider, {
      openai: openAiApiKey.value(),
      gemini: geminiApiKey.value(),
    });
    let result: CoachFeedbackResult;
    try {
      const response = await provider.generateFeedback(buildCoachPrompt(summary));
      result = parseCoachFeedback(response);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error('AI coach response validation failed:', error);
      throw new HttpsError('internal', 'AI response validation failed');
    }
    await sessionSnapshot.ref.update({
      aiSummary: result,
      qualifiedDeterministic,
      recoverySummary,
    });
    await updateLeaderboardEntry(
      database,
      session,
      request.auth.uid,
      qualifiedDeterministic,
    );
    return {...result, qualifiedDeterministic, recoverySummary};
  },
);

export const generateQualificationReadiness = onCall(
  {secrets: [openAiApiKey, geminiApiKey]},
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError('unauthenticated', 'Sign in to request qualification readiness.');
    }
    const uid = request.auth.uid;
    const database = getFirestore();
    const userReference = database.collection('users').doc(uid);
    const userSnapshot = await userReference.get();
    const cached = cachedReadiness(userSnapshot.data()?.readinessSummary);
    if (cached != null) return cached;

    const sessionDocuments = (await database.collection('sessions')
        .where('uid', '==', uid)
        .get()).docs
        .sort((left, right) => (timestampMillis(right.data().startTime) ?? 0) -
            (timestampMillis(left.data().startTime) ?? 0))
        .slice(0, 10);
    if (sessionDocuments.length < 3) {
      return {
        insufficientData: true,
        message: 'Complete a few more runs to unlock your readiness prediction.',
      };
    }

    const user = userSnapshot.data() ?? {};
    const examId = typeof user.examTarget === 'string' ? user.examTarget : null;
    const examSnapshot = examId == null
        ? null
        : await database.collection('exam_configs').doc(examId).get();
    const sessions = sessionDocuments
        .map((document) => readinessSession(document.data()))
        .reverse();
    await consumeDailyReadinessQuota(database as unknown as RateLimitStore, uid);

    const provider = createCoachFeedbackProvider(undefined, {
      openai: openAiApiKey.value(),
      gemini: geminiApiKey.value(),
    });
    let result: QualificationReadinessResult;
    try {
      const response = await provider.generateFeedback(buildQualificationReadinessPrompt({
        examTarget: {
          id: examId,
          name: examSnapshot?.data()?.name ?? examId ?? 'Not selected',
          distanceKm: numberOrZero(examSnapshot?.data()?.distanceKm),
          timeLimitMin: numberOrZero(examSnapshot?.data()?.timeLimitMin),
        },
        sessions,
      }));
      result = parseQualificationReadiness(response);
    } catch (error) {
      console.error('Qualification readiness response validation failed:', error);
      throw new HttpsError('internal', 'Qualification readiness response validation failed.');
    }
    await userReference.set({readinessSummary: {...result, generatedAt: Timestamp.now()}}, {merge: true});
    return result;
  },
);

export const generateTrainingPlan = onCall(
  {secrets: [openAiApiKey, geminiApiKey]},
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError('unauthenticated', 'Sign in to generate a training plan.');
    }
    const uid = request.auth.uid;
    const database = getFirestore();
    const userReference = database.collection('users').doc(uid);
    const userSnapshot = await userReference.get();
    const cached = cachedTrainingPlan(userSnapshot.data()?.trainingPlan);
    if (cached != null) return cached;

    const user = userSnapshot.data() ?? {};
    const examId = typeof user.examTarget === 'string' ? user.examTarget : null;
    if (examId == null || !examId) {
      throw new HttpsError('failed-precondition', 'Select an exam target before generating a training plan.');
    }
    const examSnapshot = await database.collection('exam_configs').doc(examId).get();
    const exam = examSnapshot.data();
    if (exam == null || !Number.isFinite(exam.distanceKm) || !Number.isFinite(exam.timeLimitMin) ||
        exam.distanceKm <= 0 || exam.timeLimitMin <= 0) {
      throw new HttpsError('failed-precondition', 'Exam target configuration is missing or invalid.');
    }
    const sessionDocuments = (await database.collection('sessions')
        .where('uid', '==', uid)
        .get()).docs
        .sort((left, right) => (timestampMillis(right.data().startTime) ?? 0) -
            (timestampMillis(left.data().startTime) ?? 0))
        .slice(0, 5);
    const sessions = sessionDocuments.map((document) => readinessSession(document.data())).reverse();
    await consumeDailyTrainingPlanQuota(database as unknown as RateLimitStore, uid);

    const provider = createCoachFeedbackProvider(undefined, {
      openai: openAiApiKey.value(),
      gemini: geminiApiKey.value(),
    });
    let result: TrainingPlanResult;
    try {
      const response = await provider.generateFeedback(buildTrainingPlanPrompt({
        examTarget: {
          id: examId,
          name: exam.name,
          distanceKm: exam.distanceKm,
          timeLimitMin: exam.timeLimitMin,
        },
        recentSessions: sessions,
      }));
      result = parseTrainingPlan(response);
    } catch (error) {
      console.error('Training plan response validation failed:', error);
      throw new HttpsError('internal', 'Training plan response validation failed.');
    }
    await userReference.set({trainingPlan: {...result, generatedAt: Timestamp.now()}}, {merge: true});
    return result;
  },
);

export const generateDailyTarget = onCall(
  {secrets: [openAiApiKey, geminiApiKey]},
  async (request) => {
    if (request.auth == null) {
      throw new HttpsError('unauthenticated', 'Sign in to generate today\'s target.');
    }
    const uid = request.auth.uid;
    const database = getFirestore();
    const today = new Date().toISOString().slice(0, 10);
    const userReference = database.collection('users').doc(uid);
    const targetReference = userReference.collection('dailyTargets').doc(today);
    const cachedSnapshot = await targetReference.get();
    const cached = parseCachedDailyTarget(cachedSnapshot.data());
    if (cached != null) return cached;

    const [userSnapshot, latestSessionSnapshot] = await Promise.all([
      userReference.get(),
      database.collection('sessions').where('uid', '==', uid).get(),
    ]);
    const user = userSnapshot.data() ?? {};
    const latestSession = latestSessionSnapshot.docs
        .sort((left, right) => (timestampMillis(right.data().startTime) ?? 0) -
            (timestampMillis(left.data().startTime) ?? 0))[0]
        ?.data();
    const deterministicRest = recoveryRestTarget(latestSession);
    if (deterministicRest != null) {
      await targetReference.set({...deterministicRest, generatedAt: Timestamp.now(), deterministic: true});
      return deterministicRest;
    }

    const trainingPlan = parseStoredTrainingPlan(user.trainingPlan);
    const readiness = parseStoredReadiness(user.readinessSummary);
    const planDay = trainingPlan == null ? null : currentPlanDay(user.trainingPlan, trainingPlan);
    await consumeDailyDailyTargetQuota(database as unknown as RateLimitStore, uid, today);
    const provider = createCoachFeedbackProvider(undefined, {
      openai: openAiApiKey.value(),
      gemini: geminiApiKey.value(),
    });
    let result: DailyTargetResult;
    try {
      const response = await provider.generateFeedback(buildDailyTargetPrompt({
        latestRecovery: latestSession?.recoverySummary ?? null,
        readiness,
        planDay,
      }));
      result = parseDailyTarget(response);
    } catch (error) {
      console.error('Daily target response validation failed:', error);
      throw new HttpsError('internal', 'Daily target response validation failed.');
    }
    await targetReference.set({...result, generatedAt: Timestamp.now(), deterministic: false});
    return result;
  },
);

export const generateInjuryRiskAssessment = onCall(
  {secrets: [openAiApiKey, geminiApiKey]},
  async (request) => {
    if (request.auth == null) throw new HttpsError('unauthenticated', 'Sign in to assess training load.');
    const uid = request.auth.uid;
    const database = getFirestore();
    const userReference = database.collection('users').doc(uid);
    const userSnapshot = await userReference.get();
    const cached = cachedInjuryRisk(userSnapshot.data()?.injuryRiskSummary);
    if (cached != null) return cached;

    const sessionDocuments = (await database.collection('sessions').where('uid', '==', uid).get()).docs
        .sort((left, right) => (timestampMillis(right.data().startTime) ?? 0) - (timestampMillis(left.data().startTime) ?? 0))
        .slice(0, 10);
    if (sessionDocuments.length < 4) {
      return {insufficientData: true, message: 'Complete a few more runs to unlock your training-load estimate.'};
    }
    const sessions = sessionDocuments.reverse().map((document) => injuryRiskSession(document.data()));
    await consumeDailyInjuryRiskQuota(database as unknown as RateLimitStore, uid);
    const provider = createCoachFeedbackProvider(undefined, {openai: openAiApiKey.value(), gemini: geminiApiKey.value()});
    let result: InjuryRiskAssessmentResult;
    try {
      result = parseInjuryRiskAssessment(await provider.generateFeedback(buildInjuryRiskPrompt({
        sessions,
        restDayCompliance: restDayCompliance(sessionDocuments.map((document) => document.data())),
      })));
    } catch (error) {
      console.error('Injury-risk response validation failed:', error);
      throw new HttpsError('internal', 'Injury-risk response validation failed.');
    }
    await userReference.set({injuryRiskSummary: {...result, generatedAt: Timestamp.now()}}, {merge: true});
    return result;
  },
);

function cachedReadiness(value: unknown): QualificationReadinessResult | null {
  if (value == null || typeof value !== 'object') return null;
  const cache = value as ReadinessCache;
  const generatedAt = timestampMillis(cache.generatedAt);
  if (generatedAt == null || Date.now() - generatedAt > 24 * 60 * 60 * 1000) return null;
  try {
    return parseQualificationReadiness(cache);
  } catch {
    return null;
  }
}

function cachedInjuryRisk(value: unknown): InjuryRiskAssessmentResult | null {
  if (value == null || typeof value !== 'object') return null;
  const cache = value as InjuryRiskCache;
  const generatedAt = timestampMillis(cache.generatedAt);
  if (generatedAt == null || Date.now() - generatedAt > 24 * 60 * 60 * 1000) return null;
  try {
    return parseInjuryRiskAssessment(cache);
  } catch {
    return null;
  }
}

function cachedTrainingPlan(value: unknown): TrainingPlanResult | null {
  if (value == null || typeof value !== 'object') return null;
  const cache = value as TrainingPlanCache;
  const generatedAt = timestampMillis(cache.generatedAt);
  if (generatedAt == null || Date.now() - generatedAt > 24 * 60 * 60 * 1000) return null;
  try {
    return parseTrainingPlan(cache);
  } catch {
    return null;
  }
}

function parseCachedDailyTarget(value: unknown): DailyTargetResult | null {
  if (value == null || typeof value !== 'object') return null;
  try {
    return parseDailyTarget(value as DailyTargetCache);
  } catch {
    return null;
  }
}

function recoveryRestTarget(session: FirebaseFirestore.DocumentData | undefined): DailyTargetResult | null {
  const recovery = session?.recoverySummary;
  const recommendation = typeof recovery?.recommendation === 'string' ? recovery.recommendation : null;
  const restDays = recommendation === 'Rest 1 day' ? 1 : recommendation === 'Rest 2 days' ? 2 : 0;
  const sessionTime = timestampMillis(session?.endTime) ?? timestampMillis(session?.startTime);
  if (restDays === 0 || sessionTime == null || Date.now() - sessionTime >= restDays * 24 * 60 * 60 * 1000) {
    return null;
  }
  return {
    targetType: 'rest',
    distanceKm: null,
    paceGuidance: 'No run today',
    reasoning: 'Recovery day — light stretching only, no run. Your most recent session still calls for recovery.',
  };
}

function parseStoredTrainingPlan(value: unknown): TrainingPlanResult | null {
  if (value == null || typeof value !== 'object') return null;
  try {
    return parseTrainingPlan(value);
  } catch {
    return null;
  }
}

function parseStoredReadiness(value: unknown): QualificationReadinessResult | null {
  if (value == null || typeof value !== 'object') return null;
  try {
    return parseQualificationReadiness(value);
  } catch {
    return null;
  }
}

function currentPlanDay(value: unknown, plan: TrainingPlanResult): Record<string, unknown> | null {
  if (value == null || typeof value !== 'object') return null;
  const generatedAt = timestampMillis((value as TrainingPlanCache).generatedAt);
  if (generatedAt == null) return null;
  const dayIndex = Math.min(Math.max(Math.floor((Date.now() - generatedAt) / (24 * 60 * 60 * 1000)), 0), 6);
  const day = plan.days[dayIndex];
  return day == null
      ? null
      : {day: day.day, focus: day.focus, target: day.target, notes: day.notes};
}

function readinessSession(session: FirebaseFirestore.DocumentData): Record<string, unknown> {
  const distanceKm = numberOrZero(session.totalDistanceKm);
  const totalTimeSec = numberOrZero(session.totalTimeSec);
  return {
    date: timestampMillis(session.startTime) == null
        ? 'Unknown date'
        : new Date(timestampMillis(session.startTime)!).toISOString().slice(0, 10),
    distanceKm,
    totalTimeSec,
    paceSecPerKm: distanceKm > 0 ? totalTimeSec / distanceKm : null,
    qualifies: typeof session.qualifiedDeterministic === 'boolean'
        ? session.qualifiedDeterministic
        : typeof session.aiSummary?.qualifies === 'boolean'
          ? session.aiSummary.qualifies
          : null,
  };
}

function injuryRiskSession(session: FirebaseFirestore.DocumentData): Record<string, unknown> {
  const distanceKm = numberOrZero(session.totalDistanceKm);
  const totalTimeSec = numberOrZero(session.totalTimeSec);
  const segments = Array.isArray(session.segments) ? session.segments : [];
  const recovery = session.recoverySummary;
  return {
    date: timestampMillis(session.startTime) == null ? 'Unknown date' : new Date(timestampMillis(session.startTime)!).toISOString().slice(0, 10),
    distanceKm,
    totalTimeSec,
    paceSecPerKm: distanceKm > 0 ? totalTimeSec / distanceKm : null,
    runningSegments: segments.filter((segment) => segment?.type === 'running').length,
    walkingSegments: segments.filter((segment) => segment?.type === 'walking').length,
    recoveryScore: typeof recovery?.score === 'number' ? recovery.score : null,
    restRecommendation: typeof recovery?.recommendation === 'string' ? recovery.recommendation : null,
  };
}

function restDayCompliance(sessions: FirebaseFirestore.DocumentData[]): Record<string, number> {
  var recommendationsTracked = 0;
  var followed = 0;
  for (let index = 0; index < sessions.length - 1; index++) {
    const recommendation = sessions[index].recoverySummary?.recommendation;
    const requiredDays = recommendation === 'Rest 1 day' ? 1 : recommendation === 'Rest 2 days' ? 2 : 0;
    const currentTime = timestampMillis(sessions[index].endTime) ?? timestampMillis(sessions[index].startTime);
    const nextTime = timestampMillis(sessions[index + 1].startTime);
    if (requiredDays === 0 || currentTime == null || nextTime == null) continue;
    recommendationsTracked++;
    if (nextTime - currentTime >= requiredDays * 24 * 60 * 60 * 1000) followed++;
  }
  return {recommendationsTracked, followed, ranTooSoon: recommendationsTracked - followed};
}

async function buildSessionSummary(database: FirebaseFirestore.Firestore, session: FirebaseFirestore.DocumentData): Promise<SessionSummary> {
  const examSnapshot = await database.collection('exam_configs').doc(session.examId as string).get();
  const exam = examSnapshot.data();
  const segments = Array.isArray(session.segments) ? session.segments : [];
  return {
    examName: typeof exam?.name === 'string' ? exam.name : String(session.examId ?? 'PET exam'),
    targetDistanceKm: numberOrZero(exam?.distanceKm),
    targetTimeLimitMin: numberOrZero(exam?.timeLimitMin),
    distanceKm: numberOrZero(session.totalDistanceKm),
    totalTimeSec: numberOrZero(session.totalTimeSec),
    runningSegmentCount: segments.filter((segment) => segment?.type === 'running').length,
    walkingSegmentCount: segments.filter((segment) => segment?.type === 'walking').length,
  };
}

async function buildRecoverySummary(
  database: FirebaseFirestore.Firestore,
  sessionId: string,
  session: FirebaseFirestore.DocumentData,
  uid: string,
) {
  const recentSessions = (await database.collection('sessions')
      .where('uid', '==', uid)
      .get()).docs
      .sort((left, right) => (timestampMillis(right.data().startTime) ?? 0) -
          (timestampMillis(left.data().startTime) ?? 0))
      .slice(0, 4);
  const previousSessions = recentSessions
      .filter((document) => document.id !== sessionId)
      .slice(0, 3)
      .map((document) => toRecoverySession(document.data()));
  return calculateRecovery(toRecoverySession(session), previousSessions);
}

/**
 * Maintains a minimal public ranking projection. Raw sessions remain private;
 * only a user's best qualifying result and chosen display name are exposed.
 */
async function updateLeaderboardEntry(
  database: FirebaseFirestore.Firestore,
  session: FirebaseFirestore.DocumentData,
  uid: string,
  qualifiedDeterministic: boolean,
): Promise<void> {
  if (!qualifiedDeterministic || typeof session.examId !== 'string') return;
  const bestTime = numberOrZero(session.totalTimeSec);
  const bestDistance = numberOrZero(session.totalDistanceKm);
  if (bestTime <= 0 || bestDistance <= 0) return;

  const userSnapshot = await database.collection('users').doc(uid).get();
  const chosenName = userSnapshot.data()?.displayName;
  const displayName = typeof chosenName === 'string' && chosenName.trim().length > 0
      ? chosenName.trim().slice(0, 24)
      : `Runner_${uid.slice(-5)}`;
  const entryReference = database
      .collection('leaderboards')
      .doc(session.examId)
      .collection('entries')
      .doc(uid);

  await database.runTransaction(async (transaction) => {
    const existing = await transaction.get(entryReference);
    const previousTime = numberOrZero(existing.data()?.bestTime);
    if (previousTime > 0 && previousTime <= bestTime) return;
    transaction.set(entryReference, {
      displayName,
      bestTime,
      bestDistance,
      lastUpdated: Timestamp.now(),
    });
  });
}

function toRecoverySession(session: FirebaseFirestore.DocumentData): RecoverySessionInput {
  const rawSegments = Array.isArray(session.segments) ? session.segments : [];
  return {
    totalDistanceKm: numberOrZero(session.totalDistanceKm),
    totalTimeSec: numberOrZero(session.totalTimeSec),
    segments: rawSegments.map(toRecoverySegment).filter((segment): segment is RecoverySegmentInput => segment != null),
  };
}

function toRecoverySegment(value: unknown): RecoverySegmentInput | null {
  if (value == null || typeof value !== 'object') return null;
  const segment = value as {
    type?: unknown;
    startTime?: unknown;
    endTime?: unknown;
    activeDurationSec?: unknown;
  };
  if (typeof segment.type !== 'string') return null;
  const start = timestampMillis(segment.startTime);
  const end = timestampMillis(segment.endTime);
  if (start == null || end == null) return null;
  const activeDurationSec = numberOrZero(segment.activeDurationSec);
  return {
    type: segment.type,
    durationSec: Number.isFinite(activeDurationSec)
        ? Math.max(0, activeDurationSec)
        : Math.max(0, (end - start) / 1000),
  };
}

function timestampMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (value != null && typeof value === 'object' && 'toMillis' in value &&
      typeof (value as {toMillis?: unknown}).toMillis === 'function') {
    return (value as {toMillis: () => number}).toMillis();
  }
  return null;
}

function validateSessionSummary(summary: SessionSummary): void {
  if (!Number.isFinite(summary.distanceKm) || !Number.isFinite(summary.totalTimeSec) || summary.distanceKm < 0 || summary.distanceKm > 100 || summary.totalTimeSec < 0 || summary.totalTimeSec > 36000) {
    throw new HttpsError('invalid-argument', 'Session distance or time is missing or physically implausible.');
  }
  if (summary.targetDistanceKm <= 0 || summary.targetTimeLimitMin <= 0) {
    throw new HttpsError('invalid-argument', 'Exam target configuration is missing.');
  }
}

function numberOrZero(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : Number.NaN;
}
