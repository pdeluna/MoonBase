/**
 * Probe: do security rules see the in-batch base write when creating
 * bases/{id}/members/{ownerUid} in the same WriteBatch?
 */
const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  writeBatch,
  Timestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-moonbase';
const RULES_PATH = path.resolve(__dirname, '..', '..', 'firestore.rules');
const ALICE = 'alice';
const BASE = 'batch_probe_base';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function basePayload() {
  return {
    name: 'Batch Probe',
    ownerUid: ALICE,
    memberUids: [ALICE],
    createdAt: Timestamp.fromMillis(1_700_000_000_000),
    schemaVersion: 1,
  };
}

function ownerMemberPayload() {
  return {
    role: 'owner',
    nickname: 'Alice',
    joinedAt: Timestamp.fromMillis(1_700_000_000_100),
    schemaVersion: 1,
  };
}

describe('batch owner bootstrap (rules visibility probe)', () => {
  test('WriteBatch: base doc + owner members/{uid} in one commit', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    const baseRef = doc(db, 'bases', BASE);
    const memberRef = doc(db, 'bases', BASE, 'members', ALICE);

    const batch = writeBatch(db);
    batch.set(baseRef, basePayload());
    batch.set(memberRef, ownerMemberPayload());

    let batchSucceeded = false;
    let errorMessage = null;
    try {
      await batch.commit();
      batchSucceeded = true;
    } catch (e) {
      errorMessage = String(e && e.message ? e.message : e);
    }

    // eslint-disable-next-line no-console
    console.log(
      '\n=== BATCH VISIBILITY PROBE RESULT ===\n' +
        JSON.stringify({ batchSucceeded, errorMessage }, null, 2) +
        '\n=====================================\n',
    );

    if (batchSucceeded) {
      const baseSnap = await assertSucceeds(getDoc(baseRef));
      const memberSnap = await assertSucceeds(getDoc(memberRef));
      expect(baseSnap.exists()).toBe(true);
      expect(memberSnap.exists()).toBe(true);
      expect(memberSnap.data().role).toBe('owner');
    } else {
      // Document denial for the plan; do not treat as a suite failure —
      // this probe's job is to report the rules behavior.
      expect(batchSucceeded).toBe(false);
      expect(errorMessage).toMatch(/PERMISSION_DENIED|permission/i);
    }
  });

  test('control: sequential base then owner member is allowed', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    const baseRef = doc(db, 'bases', BASE);
    const memberRef = doc(db, 'bases', BASE, 'members', ALICE);

    await assertSucceeds(setDoc(baseRef, basePayload()));
    await assertSucceeds(setDoc(memberRef, ownerMemberPayload()));

    const memberSnap = await assertSucceeds(getDoc(memberRef));
    expect(memberSnap.exists()).toBe(true);
    expect(memberSnap.data().role).toBe('owner');
  });
});
