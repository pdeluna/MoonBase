/**
 * MoonBase storage.rules — emulator unit tests.
 * Run via: npm test (from this folder; starts emulator via firebase emulators:exec).
 */
const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require('firebase/storage');

const PROJECT_ID = 'demo-moonbase';
const RULES_PATH = path.resolve(__dirname, '..', '..', 'storage.rules');

const ALICE = 'alice';
const BASE = 'base1';
const MEDIA_PATH = `bases/${BASE}/media/photo.jpg`;
const OUTSIDE_PATH = `bases/${BASE}/not-media/photo.jpg`;

/** Post-compression size ceiling mirrored from storage.rules (< 10 MB). */
const MAX_BYTES = 10 * 1024 * 1024;

let testEnv;

function rulesContent() {
  return fs.readFileSync(RULES_PATH, 'utf8');
}

function smallJpegBytes() {
  // Minimal payload; content-type is what the rules inspect, not magic bytes.
  return new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
}

function oversizedBytes() {
  return new Uint8Array(MAX_BYTES);
}

function aliceStorage() {
  return testEnv.authenticatedContext(ALICE).storage();
}

function anonStorage() {
  return testEnv.unauthenticatedContext().storage();
}

async function seedMediaObject(objectPath = MEDIA_PATH) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), objectPath), smallJpegBytes(), {
      contentType: 'image/jpeg',
    });
  });
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: rulesContent(),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

afterEach(async () => {
  await testEnv.clearStorage();
});

describe('storage.rules media path', () => {
  test('1 signed-in upload under media path (small image/jpeg) succeeds', async () => {
    await assertSucceeds(
      uploadBytes(ref(aliceStorage(), MEDIA_PATH), smallJpegBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('2 anonymous upload denied', async () => {
    await assertFails(
      uploadBytes(ref(anonStorage(), MEDIA_PATH), smallJpegBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('3 signed-in oversized upload (>= 10 MB) denied', async () => {
    await assertFails(
      uploadBytes(ref(aliceStorage(), MEDIA_PATH), oversizedBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('4 signed-in non-image content-type denied', async () => {
    await assertFails(
      uploadBytes(ref(aliceStorage(), MEDIA_PATH), smallJpegBytes(), {
        contentType: 'application/pdf',
      }),
    );
  });

  test('5 otherwise-valid write outside media path denied (path only)', async () => {
    // Signed-in, small, image/jpeg — only the path is wrong.
    await assertFails(
      uploadBytes(ref(aliceStorage(), OUTSIDE_PATH), smallJpegBytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('6 signed-in read of seeded media object succeeds', async () => {
    await seedMediaObject();
    await assertSucceeds(getBytes(ref(aliceStorage(), MEDIA_PATH)));
  });

  test('7 anonymous read of seeded media object denied', async () => {
    await seedMediaObject();
    await assertFails(getBytes(ref(anonStorage(), MEDIA_PATH)));
  });

  test('8 signed-in delete under media path denied (MVP)', async () => {
    await seedMediaObject();
    await assertFails(deleteObject(ref(aliceStorage(), MEDIA_PATH)));
  });
});
