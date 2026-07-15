import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });

const examConfigs = {
  up_home_guard: { distanceKm: 4.8, timeLimitMin: 28, name: 'UP Home Guard' },
  ssc_gd: { distanceKm: 1.6, timeLimitMin: 6.5, name: 'SSC GD (Male)' },
};

async function seedExamConfigs(): Promise<void> {
  const database = getFirestore();
  const batch = database.batch();
  for (const [id, config] of Object.entries(examConfigs)) {
    batch.set(database.collection('exam_configs').doc(id), config);
  }
  await batch.commit();
  console.info('Seeded exam_configs documents:', examConfigs);
  // TODO: Add remaining exam bodies (UP Police, Delhi Police, CRPF, CISF, BSF, Army Agniveer).
}

seedExamConfigs().catch((error: unknown) => {
  console.error('Failed to seed exam configs:', error);
  process.exitCode = 1;
});
