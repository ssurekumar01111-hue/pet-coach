import { HttpsError } from 'firebase-functions/v2/https';

export interface RateLimitDocument {
  readonly id: string;
}

export interface RateLimitTransaction {
  get(document: RateLimitDocument): Promise<{data(): {count?: unknown} | undefined}>;
  set(document: RateLimitDocument, data: Record<string, unknown>, options?: {merge?: boolean}): void;
}

export interface RateLimitStore {
  doc(path: string): RateLimitDocument;
  runTransaction<T>(updateFunction: (transaction: RateLimitTransaction) => Promise<T>): Promise<T>;
}

export async function consumeDailyAiQuota(store: RateLimitStore, uid: string, date = new Date().toISOString().slice(0, 10)): Promise<void> {
  return consumeDailyQuota(store, uid, {date, category: null, userLimit: 5, globalLimit: 100});
}

export async function consumeDailyReadinessQuota(store: RateLimitStore, uid: string, date = new Date().toISOString().slice(0, 10)): Promise<void> {
  return consumeDailyQuota(store, uid, {date, category: 'readiness', userLimit: 3, globalLimit: 100});
}

export async function consumeDailyTrainingPlanQuota(store: RateLimitStore, uid: string, date = new Date().toISOString().slice(0, 10)): Promise<void> {
  return consumeDailyQuota(store, uid, {date, category: 'training_plan', userLimit: 3, globalLimit: 100});
}

export async function consumeDailyDailyTargetQuota(store: RateLimitStore, uid: string, date = new Date().toISOString().slice(0, 10)): Promise<void> {
  return consumeDailyQuota(store, uid, {date, category: 'daily_target', userLimit: 1, globalLimit: 100});
}

export async function consumeDailyInjuryRiskQuota(store: RateLimitStore, uid: string, date = new Date().toISOString().slice(0, 10)): Promise<void> {
  return consumeDailyQuota(store, uid, {date, category: 'injury_risk', userLimit: 3, globalLimit: 100});
}

async function consumeDailyQuota(
  store: RateLimitStore,
  uid: string,
  options: {date: string; category: string | null; userLimit: number; globalLimit: number},
): Promise<void> {
  const {date, category, userLimit, globalLimit} = options;
  await store.runTransaction(async (transaction) => {
    const categoryPart = category == null ? '' : `_${category}`;
    const userDocument = store.doc(`rate_limits/${uid}${categoryPart}_${date}`);
    const globalDocument = store.doc(`rate_limits/global${categoryPart}_${date}`);
    const [userSnapshot, globalSnapshot] = await Promise.all([
      transaction.get(userDocument),
      transaction.get(globalDocument),
    ]);
    const userCount = readCount(userSnapshot.data()?.count);
    const globalCount = readCount(globalSnapshot.data()?.count);
    if (userCount >= userLimit || globalCount >= globalLimit) {
      throw new HttpsError('resource-exhausted', 'Daily AI limit reached. Please try again tomorrow.');
    }
    transaction.set(userDocument, {
      count: userCount + 1,
      date,
      uid,
      ...(category == null ? {} : {category}),
    }, {merge: true});
    transaction.set(globalDocument, {
      count: globalCount + 1,
      date,
      ...(category == null ? {} : {category}),
    }, {merge: true});
  });
}

function readCount(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : 0;
}
