import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

initializeApp({credential: applicationDefault()});

const examId = 'up_home_guard';
// Matches the 6,371 km Earth radius used by the Flutter pace analyzer.
const metresPerLongitudeDegreeAtEquator = 2 * Math.PI * 6371000 / 360;

interface SessionSeed {
  daysAgo: number;
  distanceKm: number;
  totalTimeSec: number;
  runningShare: number;
}

// Progression is intentional: early attempts are below the 4.8 km / 28 min
// standard, while later attempts become consistently qualifying.
const sessionSeeds: SessionSeed[] = [
  {daysAgo: 20, distanceKm: 4.2, totalTimeSec: 2100, runningShare: .55},
  {daysAgo: 18, distanceKm: 4.5, totalTimeSec: 2050, runningShare: .60},
  {daysAgo: 16, distanceKm: 4.8, totalTimeSec: 1920, runningShare: .66},
  {daysAgo: 13, distanceKm: 4.8, totalTimeSec: 1830, runningShare: .72},
  {daysAgo: 10, distanceKm: 4.8, totalTimeSec: 1740, runningShare: .78},
  {daysAgo: 7, distanceKm: 4.8, totalTimeSec: 1668, runningShare: .84},
  {daysAgo: 4, distanceKm: 4.8, totalTimeSec: 1620, runningShare: .88},
  {daysAgo: 1, distanceKm: 4.8, totalTimeSec: 1572, runningShare: .91},
];

async function seedTestSessions(uid: string): Promise<void> {
  const database = getFirestore();
  const batch = database.batch();
  const now = new Date();

  for (let index = 0; index < sessionSeeds.length; index++) {
    const seed = sessionSeeds[index];
    const startTime = new Date(now.getTime() - seed.daysAgo * 24 * 60 * 60 * 1000);
    startTime.setHours(6, 30, 0, 0);
    const endTime = new Date(startTime.getTime() + seed.totalTimeSec * 1000);
    const documentId = `seed_test_${safeDocumentPart(uid)}_${index + 1}`;
    batch.set(database.collection('sessions').doc(documentId), {
      uid,
      examId,
      startTime: Timestamp.fromDate(startTime),
      endTime: Timestamp.fromDate(endTime),
      gpsTrack: buildGpsTrack(seed, startTime),
      segments: buildSegments(seed, startTime),
      totalDistanceKm: seed.distanceKm,
      totalTimeSec: seed.totalTimeSec,
      // Intentionally omit aiSummary and recoverySummary so the app exercises
      // the deployed feedback/recovery flow against these real test sessions.
    });
  }

  await batch.commit();
  console.info(`Seeded ${sessionSeeds.length} UP Home Guard test sessions for ${uid}.`);
  console.info('Trend: early sessions are slower/non-qualifying; the final three are under 28 minutes.');
}

function buildGpsTrack(seed: SessionSeed, startTime: Date): Array<Record<string, unknown>> {
  const pointCount = Math.max(13, Math.ceil(seed.distanceKm * 3) + 1);
  const totalMetres = seed.distanceKm * 1000;
  return Array.from({length: pointCount}, (_, index) => {
    const progress = index / (pointCount - 1);
    const metres = totalMetres * progress;
    return {
      latitude: 0,
      longitude: metres / metresPerLongitudeDegreeAtEquator,
      timestamp: Timestamp.fromDate(new Date(startTime.getTime() + seed.totalTimeSec * 1000 * progress)),
      accuracy: 4.5,
    };
  });
}

function buildSegments(seed: SessionSeed, startTime: Date): Array<Record<string, unknown>> {
  const runningTimeSec = Math.round(seed.totalTimeSec * seed.runningShare);
  const walkingTimeSec = seed.totalTimeSec - runningTimeSec;
  // Running covers a larger share of distance than time; this produces a
  // credible faster run pace and slower recovery-walk pace in every session.
  const runningDistanceKm = seed.distanceKm * Math.min(.95, .45 + seed.runningShare * .5);
  const walkingDistanceKm = seed.distanceKm - runningDistanceKm;
  const runEnd = new Date(startTime.getTime() + runningTimeSec * 1000);
  const end = new Date(startTime.getTime() + seed.totalTimeSec * 1000);
  return [
    {
      type: 'running',
      startTime: Timestamp.fromDate(startTime),
      endTime: Timestamp.fromDate(runEnd),
      distanceKm: runningDistanceKm,
      avgPaceSecPerKm: runningTimeSec / runningDistanceKm,
    },
    {
      type: 'walking',
      startTime: Timestamp.fromDate(runEnd),
      endTime: Timestamp.fromDate(end),
      distanceKm: walkingDistanceKm,
      avgPaceSecPerKm: walkingTimeSec / walkingDistanceKm,
    },
  ];
}

function safeDocumentPart(value: string): string {
  return value.replace(/[^A-Za-z0-9_-]/g, '_');
}

const uid = process.argv[2];
if (typeof uid !== 'string' || !uid.trim()) {
  console.error('Usage: node lib/scripts/seedTestSessions.js <uid>');
  process.exitCode = 1;
} else {
  seedTestSessions(uid).catch((error: unknown) => {
    console.error('Failed to seed test sessions:', error);
    process.exitCode = 1;
  });
}
