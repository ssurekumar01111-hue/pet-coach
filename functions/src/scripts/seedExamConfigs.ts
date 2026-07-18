import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

// Use Application Default Credentials in CI. The local service-account file is
// a development convenience so `node lib/scripts/seedExamConfigs.js` works
// without separately configuring ADC.
const localServiceAccountPath = resolve(process.cwd(), '..', 'pet-coach-ai-firebase-service-account-key.json');
initializeApp({
  credential: existsSync(localServiceAccountPath)
      ? cert(localServiceAccountPath)
      : applicationDefault(),
});

const examConfigs = {
  up_home_guard: { distanceKm: 4.8, timeLimitMin: 28, name: 'UP Home Guard' },
  ssc_gd: { distanceKm: 1.6, timeLimitMin: 6.5, name: 'SSC GD (Male)' },
  up_police: { distanceKm: 4.8, timeLimitMin: 25, name: 'UP Police Constable' },
  delhi_police: { distanceKm: 1.6, timeLimitMin: 6.5, name: 'Delhi Police Constable' },
  army_agniveer: { distanceKm: 1.6, timeLimitMin: 5.5, name: 'Army Agniveer (GD)' },
  crpf_gd: { distanceKm: 1.6, timeLimitMin: 6.5, name: 'CRPF Constable (GD)', approximate: true },
  cisf_gd: { distanceKm: 1.6, timeLimitMin: 6.5, name: 'CISF Constable (GD)', approximate: true },
  bsf_gd: { distanceKm: 1.6, timeLimitMin: 6.5, name: 'BSF Constable (GD)', approximate: true },
};

async function seedExamConfigs(): Promise<void> {
  const database = getFirestore();
  const batch = database.batch();
  for (const [id, config] of Object.entries(examConfigs)) {
    batch.set(database.collection('exam_configs').doc(id), config);
  }
  await batch.commit();
  console.info('Seeded exam_configs documents:', examConfigs);
}

seedExamConfigs().catch((error: unknown) => {
  console.error('Failed to seed exam configs:', error);
  process.exitCode = 1;
});
