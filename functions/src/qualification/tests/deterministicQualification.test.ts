import assert from 'node:assert/strict';
import test from 'node:test';

import { isQualifiedDeterministically } from '../deterministicQualification.js';

test('deterministic qualification requires both the target distance and time limit', () => {
  // UP Home Guard: 4.8 km within 28 minutes.
  assert.equal(isQualifiedDeterministically(4.8, 28 * 60, 4.8, 28), true);
  assert.equal(isQualifiedDeterministically(5.0, 27 * 60 + 59, 4.8, 28), true);
  assert.equal(isQualifiedDeterministically(4.79, 27 * 60, 4.8, 28), false);
  assert.equal(isQualifiedDeterministically(4.8, 28 * 60 + 1, 4.8, 28), false);
});
