/**
 * MoonBase firestore.rules — emulator unit tests.
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
  doc,
  getDoc,
  setDoc,
  updateDoc,
  Timestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-moonbase';
const RULES_PATH = path.resolve(__dirname, '..', '..', 'firestore.rules');

const ALICE = 'alice';
const BOB = 'bob';
const CAROL = 'carol';
const BASE = 'base1';
const INVITE = 'INVITE1';

let testEnv;

function rulesContent() {
  return fs.readFileSync(RULES_PATH, 'utf8');
}

function aliceAuth() {
  return testEnv.authenticatedContext(ALICE);
}

function bobAuth() {
  return testEnv.authenticatedContext(BOB);
}

function carolAuth() {
  return testEnv.authenticatedContext(CAROL);
}

function aliceDb() {
  return aliceAuth().firestore();
}

function bobDb() {
  return bobAuth().firestore();
}

function carolDb() {
  return carolAuth().firestore();
}

function profile(uid, nickname) {
  return {
    nickname,
    themeMode: 'light',
    createdAt: Timestamp.fromMillis(1_700_000_000_000),
    schemaVersion: 1,
  };
}

function baseDoc(ownerUid, memberUids, name = 'Family') {
  return {
    name,
    ownerUid,
    memberUids,
    createdAt: Timestamp.fromMillis(1_700_000_000_000),
    schemaVersion: 1,
  };
}

function memberDoc(role, nickname) {
  return {
    role,
    nickname,
    joinedAt: Timestamp.fromMillis(1_700_000_000_100),
    schemaVersion: 1,
  };
}

function inviteDoc(overrides = {}) {
  const merged = {
    createdBy: ALICE,
    createdAt: Timestamp.fromMillis(1_700_000_000_000),
    maxUses: 5,
    useCount: 0,
    schemaVersion: 1,
    ...overrides,
  };
  // Omit null expiresAt so rules never compare request.time to null.
  if (merged.expiresAt == null) {
    delete merged.expiresAt;
  }
  return merged;
}

async function seedOwnerBaseWithMemberRow() {
  await assertSucceeds(
    setDoc(doc(aliceDb(), 'bases', BASE), baseDoc(ALICE, [ALICE])),
  );
  await assertSucceeds(
    setDoc(doc(aliceDb(), 'bases', BASE, 'members', ALICE), memberDoc('owner', 'Alice')),
  );
}

async function seedInvite(overrides = {}) {
  const data = inviteDoc(overrides);
  // Create rules require useCount == 0; non-zero fixtures need Admin write.
  if (data.useCount === 0) {
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'bases', BASE, 'invites', INVITE), data),
    );
  } else {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'bases', BASE, 'invites', INVITE), data);
    });
  }
}

async function adminGet(pathSegments) {
  let data;
  let exists = false;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDoc(doc(ctx.firestore(), ...pathSegments));
    exists = snap.exists();
    data = snap.data();
  });
  return { exists, data };
}

async function seedMessage(messageId, authorUid, text) {
  const db = authorUid === ALICE ? aliceDb() : bobDb();
  await assertSucceeds(
    setDoc(doc(db, 'bases', BASE, 'messages', messageId), {
      authorUid,
      text,
      createdAt: Timestamp.fromMillis(1_700_000_000_200),
      schemaVersion: 1,
    }),
  );
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: rulesContent(),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('owner create', () => {
  test('owner can create base then owner member row', async () => {
    await seedOwnerBaseWithMemberRow();
    const snap = await assertSucceeds(getDoc(doc(aliceDb(), 'bases', BASE)));
    expect(snap.data().ownerUid).toBe(ALICE);
  });
});

describe('join (+1 self only)', () => {
  test('non-member can add only self to memberUids then create members/{uid}', async () => {
    await seedOwnerBaseWithMemberRow();

    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );

    await assertSucceeds(
      setDoc(doc(bobDb(), 'bases', BASE, 'members', BOB), memberDoc('member', 'Bob')),
    );

    const base = await getDoc(doc(bobDb(), 'bases', BASE));
    expect(base.data().memberUids).toEqual([ALICE, BOB]);
  });
});

describe('leave (−1 self only)', () => {
  test('member can remove only self from memberUids', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
    await assertSucceeds(
      setDoc(doc(bobDb(), 'bases', BASE, 'members', BOB), memberDoc('member', 'Bob')),
    );

    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );

    const base = await getDoc(doc(aliceDb(), 'bases', BASE));
    expect(base.data().memberUids).toEqual([ALICE]);
  });
});

describe('deny matrix', () => {
  test('non-owner rename is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );

    await assertFails(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Hijacked',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
  });

  test('joiner adding another uid is rejected', async () => {
    await seedOwnerBaseWithMemberRow();

    await assertFails(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB, CAROL],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
  });

  test('redeem past maxUses is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 2, useCount: 2 });

    await assertFails(
      updateDoc(doc(bobDb(), 'bases', BASE, 'invites', INVITE), {
        useCount: 3,
      }),
    );
  });

  test('redeem past expiresAt is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({
      maxUses: 5,
      useCount: 0,
      expiresAt: Timestamp.fromMillis(1_000_000_000_000),
    });

    await assertFails(
      updateDoc(doc(bobDb(), 'bases', BASE, 'invites', INVITE), {
        useCount: 1,
      }),
    );
  });

  test('non-member read base is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(getDoc(doc(bobDb(), 'bases', BASE)));
  });

  test('non-member read messages is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedMessage('m1', ALICE, 'hello');
    await assertFails(getDoc(doc(bobDb(), 'bases', BASE, 'messages', 'm1')));
  });

  test('profile A writing B is rejected', async () => {
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'users', ALICE), profile(ALICE, 'Alice')),
    );
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', BOB), profile(BOB, 'Bob'));
    });

    await assertFails(
      setDoc(doc(aliceDb(), 'users', BOB), profile(BOB, 'Hijacked')),
    );

    await assertFails(
      updateDoc(doc(aliceDb(), 'users', BOB), {
        nickname: 'Hijacked',
        themeMode: 'dark',
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
  });
});

describe('invite contention / non-transactional orphan (justifies runTransaction)', () => {
  test('two joiners can both append memberUids while only one useCount bump succeeds (over-admit vs maxUses)', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 1, useCount: 0 });

    // Simulate two clients that already decided the invite is valid, then race
    // membership updates without a single transaction tying invite + base.
    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(carolDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB, CAROL],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );

    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE, 'invites', INVITE), {
        useCount: 1,
      }),
    );
    // Second bump denied by rules — but two members already joined.
    await assertFails(
      updateDoc(doc(carolDb(), 'bases', BASE, 'invites', INVITE), {
        useCount: 2,
      }),
    );

    const base = await adminGet(['bases', BASE]);
    const invite = await adminGet(['bases', BASE, 'invites', INVITE]);

    expect(base.data.memberUids).toEqual([ALICE, BOB, CAROL]);
    expect(invite.data.useCount).toBe(1);
    expect(invite.data.maxUses).toBe(1);
    // rules authorized membership growth beyond maxUses because join does not
    // check the invite doc — only a client transaction can couple them.
  });

  test('non-transactional join can orphan: memberUids updated without members/{uid}', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 5, useCount: 0 });

    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE, 'invites', INVITE), {
        useCount: 1,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [ALICE, BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
    // Intentionally skip create members/{BOB} — partial non-transactional redeem.

    const member = await adminGet(['bases', BASE, 'members', BOB]);
    const base = await adminGet(['bases', BASE]);

    expect(base.data.memberUids).toContain(BOB);
    expect(member.exists).toBe(false);
  });
});

describe('messages text cap', () => {
  test('empty text create is rejected; oversized text create is rejected', async () => {
    await seedOwnerBaseWithMemberRow();

    await assertFails(
      setDoc(doc(aliceDb(), 'bases', BASE, 'messages', 'empty'), {
        authorUid: ALICE,
        text: '',
        createdAt: Timestamp.fromMillis(1_700_000_000_200),
        schemaVersion: 1,
      }),
    );

    await assertFails(
      setDoc(doc(aliceDb(), 'bases', BASE, 'messages', 'huge'), {
        authorUid: ALICE,
        text: 'x'.repeat(4001),
        createdAt: Timestamp.fromMillis(1_700_000_000_200),
        schemaVersion: 1,
      }),
    );

    await assertSucceeds(
      setDoc(doc(aliceDb(), 'bases', BASE, 'messages', 'ok'), {
        authorUid: ALICE,
        text: 'x'.repeat(4000),
        createdAt: Timestamp.fromMillis(1_700_000_000_200),
        schemaVersion: 1,
      }),
    );
  });
});
