import assert from 'node:assert/strict';
import test from 'node:test';

import { GeminiProvider } from '../geminiProvider.js';
import { OpenAiProvider } from '../openaiProvider.js';
import { consumeDailyAiQuota, consumeDailyReadinessQuota, consumeDailyTrainingPlanQuota, consumeDailyDailyTargetQuota, RateLimitDocument, RateLimitStore, RateLimitTransaction } from '../rateLimiter.js';
import { parseCoachFeedback, parseDailyTarget, parseQualificationReadiness, parseTrainingPlan } from '../validation.js';

const validFeedback = JSON.stringify({
  qualifies: true,
  predictedTime: '05:58',
  feedback: 'Maintain your steady opening pace.',
  nextTarget: 'Run 1.6 km under 6:10.',
});

test('OpenAI and Gemini adapters return parseable feedback using mocked APIs', async () => {
  let openAiRequest: RequestInit | undefined;
  let openAiUrl: string | URL | Request | undefined;
  const openAiFetch: typeof fetch = async (url, init) => {
    openAiUrl = url;
    openAiRequest = init;
    return new Response(JSON.stringify({output_text: validFeedback}), {status: 200});
  };
  let geminiUrl: string | URL | Request | undefined;
  let geminiRequest: RequestInit | undefined;
  const geminiFetch: typeof fetch = async (url, init) => {
    geminiUrl = url;
    geminiRequest = init;
    return new Response(JSON.stringify({candidates: [{content: {parts: [{text: validFeedback}]}}]}), {status: 200});
  };

  assert.deepEqual(parseCoachFeedback(await new OpenAiProvider('secret', openAiFetch).generateFeedback('prompt')), JSON.parse(validFeedback));
  assert.equal(String(openAiUrl), 'https://api.openai.com/v1/responses');
  assert.deepEqual(JSON.parse(openAiRequest?.body as string), {
    model: 'gpt-5.6-luna',
    input: 'prompt',
    max_output_tokens: 400,
  });
  assert.deepEqual(parseCoachFeedback(await new GeminiProvider('gemini-api-key', geminiFetch).generateFeedback('prompt')), JSON.parse(validFeedback));
  assert.equal(String(geminiUrl), 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent');
  assert.equal((geminiRequest?.headers as Record<string, string>)['x-goog-api-key'], 'gemini-api-key');
});

test('schema validation rejects malformed and incomplete model responses', () => {
  assert.throws(() => parseCoachFeedback('not json'));
  assert.throws(() => parseCoachFeedback(JSON.stringify({qualifies: true, predictedTime: '06:00'})));
  assert.throws(() => parseCoachFeedback({qualifies: 'yes', predictedTime: '06:00', feedback: 'x', nextTarget: 'y'}));
  assert.deepEqual(
    parseQualificationReadiness('{"readinessPercent":72,"trend":"improving","predictedQualificationDate":"in 2 weeks","summary":"Your pace is improving. Keep training steadily."}'),
    {readinessPercent: 72, trend: 'improving', predictedQualificationDate: 'in 2 weeks', summary: 'Your pace is improving. Keep training steadily.'},
  );
  assert.throws(() => parseQualificationReadiness('{"readinessPercent":120,"trend":"up","predictedQualificationDate":"soon","summary":"x"}'));
  const plan = {days: Array.from({length: 7}, (_, index) => ({
    day: index + 1,
    focus: 'Easy run',
    target: '20 minutes',
    notes: 'Keep it controlled.',
  }))};
  assert.deepEqual(parseTrainingPlan(JSON.stringify(plan)), plan);
  assert.throws(() => parseTrainingPlan(JSON.stringify({days: plan.days.slice(0, 6)})));
  assert.deepEqual(
    parseDailyTarget('{"targetType":"rest","distanceKm":null,"paceGuidance":"No run today","reasoning":"Recover well today."}'),
    {targetType: 'rest', distanceKm: null, paceGuidance: 'No run today', reasoning: 'Recover well today.'},
  );
  assert.throws(() => parseDailyTarget('{"targetType":"rest","distanceKm":2,"paceGuidance":"x","reasoning":"y"}'));
});

test('readiness limiter permits three calls per user per day', async () => {
  const store = new FakeRateLimitStore();
  for (let call = 0; call < 3; call++) {
    await consumeDailyReadinessQuota(store, 'user-a', '2026-07-16');
  }
  await assert.rejects(
    () => consumeDailyReadinessQuota(store, 'user-a', '2026-07-16'),
    (error: {code?: string}) => error.code === 'resource-exhausted',
  );
});

test('training plan limiter permits three calls per user per day', async () => {
  const store = new FakeRateLimitStore();
  for (let call = 0; call < 3; call++) {
    await consumeDailyTrainingPlanQuota(store, 'user-a', '2026-07-16');
  }
  await assert.rejects(
    () => consumeDailyTrainingPlanQuota(store, 'user-a', '2026-07-16'),
    (error: {code?: string}) => error.code === 'resource-exhausted',
  );
});

test('daily target limiter permits one generated target per user per day', async () => {
  const store = new FakeRateLimitStore();
  await consumeDailyDailyTargetQuota(store, 'user-a', '2026-07-16');
  await assert.rejects(
    () => consumeDailyDailyTargetQuota(store, 'user-a', '2026-07-16'),
    (error: {code?: string}) => error.code === 'resource-exhausted',
  );
});

test('rate limiter enforces user and global daily caps transactionally', async () => {
  const store = new FakeRateLimitStore();
  for (let call = 0; call < 5; call++) {
    await consumeDailyAiQuota(store, 'user-a', '2026-07-16');
  }
  await assert.rejects(
    () => consumeDailyAiQuota(store, 'user-a', '2026-07-16'),
    (error: {code?: string}) => error.code === 'resource-exhausted',
  );

  const globalStore = new FakeRateLimitStore({'rate_limits/global_2026-07-16': {count: 100}});
  await assert.rejects(
    () => consumeDailyAiQuota(globalStore, 'user-b', '2026-07-16'),
    (error: {code?: string}) => error.code === 'resource-exhausted',
  );
});

class FakeRateLimitStore implements RateLimitStore {
  constructor(private readonly records: Record<string, {count?: unknown}> = {}) {}

  doc(path: string): RateLimitDocument {
    return {id: path};
  }

  async runTransaction<T>(updateFunction: (transaction: RateLimitTransaction) => Promise<T>): Promise<T> {
    return updateFunction({
      get: async (document) => ({data: () => this.records[document.id]}),
      set: (document, data) => {
        this.records[document.id] = {...this.records[document.id], ...data};
      },
    });
  }
}
