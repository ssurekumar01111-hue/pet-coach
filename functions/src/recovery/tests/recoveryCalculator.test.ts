import assert from 'node:assert/strict';
import test from 'node:test';

import { calculateRecovery } from '../recoveryCalculator.js';

const previous = [
  {totalDistanceKm: 2, totalTimeSec: 1200, segments: []},
  {totalDistanceKm: 2, totalTimeSec: 1260, segments: []},
];

test('low-intensity walking session is ready for the next session', () => {
  const result = calculateRecovery({
    totalDistanceKm: 2,
    totalTimeSec: 1500,
    segments: [{type: 'walking', durationSec: 1500}],
  }, previous);
  assert.equal(result.score, 100);
  assert.equal(result.recommendation, 'Ready for next session');
});

test('faster, all-running session recommends additional recovery', () => {
  const result = calculateRecovery({
    totalDistanceKm: 2,
    totalTimeSec: 840,
    segments: [{type: 'running', durationSec: 840}],
  }, previous);
  assert.equal(result.score, 20);
  assert.equal(result.recommendation, 'Rest 2 days');
});

test('mixed-intensity session recommends one rest day', () => {
  const result = calculateRecovery({
    totalDistanceKm: 2,
    totalTimeSec: 1200,
    segments: [
      {type: 'running', durationSec: 900},
      {type: 'walking', durationSec: 300},
    ],
  }, previous);
  assert.equal(result.score, 63);
  assert.equal(result.recommendation, 'Rest 1 day');
});
