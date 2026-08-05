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
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  orderBy,
  runTransaction,
  Timestamp,
  arrayUnion,
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

function messageDoc(authorUid, text, mediaPaths = []) {
  return {
    authorUid,
    text,
    createdAt: Timestamp.fromMillis(1_700_000_000_200),
    schemaVersion: 1,
    mediaPaths,
  };
}

async function seedMessage(messageId, authorUid, text, mediaPaths = []) {
  const db = authorUid === ALICE ? aliceDb() : bobDb();
  await assertSucceeds(
    setDoc(doc(db, 'bases', BASE, 'messages', messageId), messageDoc(authorUid, text, mediaPaths)),
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

describe('list bases query (memberUids arrayContains)', () => {
  test('signed-in user can run list query when empty (returns [])', async () => {
    const db = aliceDb();
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'bases'),
          where('memberUids', 'array-contains', ALICE),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    expect(snap.empty).toBe(true);
  });

  test('member query returns owned bases', async () => {
    await seedOwnerBaseWithMemberRow();
    const db = aliceDb();
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'bases'),
          where('memberUids', 'array-contains', ALICE),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    expect(snap.size).toBe(1);
    expect(snap.docs[0].id).toBe(BASE);
  });

  test('non-member query does not return others bases', async () => {
    await seedOwnerBaseWithMemberRow();
    const db = bobDb();
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'bases'),
          where('memberUids', 'array-contains', BOB),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    expect(snap.empty).toBe(true);
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

  test('member cannot remove a different uid via leave', async () => {
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

    // −1 but not self: Bob drops Alice and keeps himself — leave branch requires
    // auth uid absent from the new memberUids list.
    await assertFails(
      updateDoc(doc(bobDb(), 'bases', BASE), {
        name: 'Family',
        ownerUid: ALICE,
        memberUids: [BOB],
        createdAt: Timestamp.fromMillis(1_700_000_000_000),
        schemaVersion: 1,
      }),
    );
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

describe('atomic redeem transaction (getAfter member create)', () => {
  // Non-members cannot read bases/{baseId} (allow read: isMember). Redeem
  // therefore reads only the invite (signed-in) and joins via arrayUnion —
  // no tx.get(base). Rules still see committed resource.data on the update.

  async function redeemTx(db, { useCountNext, memberUidsUpdate, memberUid }) {
    const inviteRef = doc(db, 'bases', BASE, 'invites', INVITE);
    const baseRef = doc(db, 'bases', BASE);
    const memberRef = doc(db, 'bases', BASE, 'members', memberUid);

    return runTransaction(db, async (tx) => {
      const inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists()) {
        throw new Error('invite missing');
      }
      tx.update(inviteRef, { useCount: useCountNext });
      tx.update(baseRef, memberUidsUpdate);
      tx.set(memberRef, memberDoc('member', 'Nick'));
    });
  }

  test('atomic redeem succeeds: useCount +1, append self, create members/{uid}', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 5, useCount: 0 });

    const db = bobDb();
    await assertSucceeds(
      redeemTx(db, {
        useCountNext: 1,
        memberUidsUpdate: { memberUids: arrayUnion(BOB) },
        memberUid: BOB,
      }),
    );

    const base = await adminGet(['bases', BASE]);
    const invite = await adminGet(['bases', BASE, 'invites', INVITE]);
    const member = await adminGet(['bases', BASE, 'members', BOB]);

    expect(base.data.memberUids).toEqual([ALICE, BOB]);
    expect(invite.data.useCount).toBe(1);
    expect(member.exists).toBe(true);
    expect(member.data.role).toBe('member');
  });

  test('atomic redeem fails when appending another uid (not self)', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 5, useCount: 0 });

    const db = bobDb();
    await assertFails(
      redeemTx(db, {
        useCountNext: 1,
        memberUidsUpdate: { memberUids: arrayUnion(CAROL) },
        memberUid: CAROL,
      }),
    );
  });

  test('atomic redeem fails on +2 memberUids growth', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 5, useCount: 0 });

    const db = bobDb();
    await assertFails(
      redeemTx(db, {
        useCountNext: 1,
        memberUidsUpdate: { memberUids: arrayUnion(BOB, CAROL) },
        memberUid: BOB,
      }),
    );
  });

  test('atomic redeem fails when mutating name (or other immutable fields)', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 5, useCount: 0 });

    const db = bobDb();
    await assertFails(
      redeemTx(db, {
        useCountNext: 1,
        memberUidsUpdate: {
          name: 'Hijacked',
          memberUids: arrayUnion(BOB),
        },
        memberUid: BOB,
      }),
    );
  });

  test('atomic redeem fails when member row uid ≠ appended self', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 5, useCount: 0 });

    const db = bobDb();
    await assertFails(
      redeemTx(db, {
        useCountNext: 1,
        memberUidsUpdate: { memberUids: arrayUnion(BOB) },
        memberUid: CAROL,
      }),
    );
  });

  test('atomic redeem fails past maxUses', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({ maxUses: 2, useCount: 2 });

    const db = bobDb();
    await assertFails(
      redeemTx(db, {
        useCountNext: 3,
        memberUidsUpdate: { memberUids: arrayUnion(BOB) },
        memberUid: BOB,
      }),
    );
  });

  test('atomic redeem fails past expiresAt', async () => {
    await seedOwnerBaseWithMemberRow();
    await seedInvite({
      maxUses: 5,
      useCount: 0,
      expiresAt: Timestamp.fromMillis(1_000_000_000_000),
    });

    const db = bobDb();
    await assertFails(
      redeemTx(db, {
        useCountNext: 1,
        memberUidsUpdate: { memberUids: arrayUnion(BOB) },
        memberUid: BOB,
      }),
    );
  });

  test('member create alone fails when uid not in memberUids', async () => {
    await seedOwnerBaseWithMemberRow();

    const payload = memberDoc('member', 'Bob');

    await assertFails(
      setDoc(doc(bobDb(), 'bases', BASE, 'members', BOB), payload),
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
    await assertSucceeds(
      setDoc(doc(bobDb(), 'bases', BASE, 'members', BOB), payload),
    );
  });
});

describe('inviteCodes mapping (global code → baseId)', () => {
  function mappingPayload(baseId = BASE) {
    return { baseId, schemaVersion: 1 };
  }

  test('owner can create mapping; signed-in user can get it', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'inviteCodes', INVITE), mappingPayload()),
    );
    const snap = await assertSucceeds(
      getDoc(doc(bobDb(), 'inviteCodes', INVITE)),
    );
    expect(snap.data().baseId).toBe(BASE);
  });

  test('non-owner cannot create mapping', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(doc(bobDb(), 'inviteCodes', INVITE), mappingPayload()),
    );
  });

  test('list / collection query on inviteCodes is denied', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'inviteCodes', INVITE), mappingPayload()),
    );
    await assertFails(getDocs(collection(bobDb(), 'inviteCodes')));
  });

  test('owner can delete mapping; non-owner cannot', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'inviteCodes', INVITE), mappingPayload()),
    );
    await assertFails(deleteDoc(doc(bobDb(), 'inviteCodes', INVITE)));
    await assertSucceeds(deleteDoc(doc(aliceDb(), 'inviteCodes', INVITE)));
  });

  test('mapping update is denied', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'inviteCodes', INVITE), mappingPayload()),
    );
    await assertFails(
      updateDoc(doc(aliceDb(), 'inviteCodes', INVITE), { baseId: 'other' }),
    );
  });
});

describe('messages text cap', () => {
  test('empty text create is rejected; oversized text create is rejected', async () => {
    await seedOwnerBaseWithMemberRow();

    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'empty'),
        messageDoc(ALICE, ''),
      ),
    );

    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'huge'),
        messageDoc(ALICE, 'x'.repeat(4001)),
      ),
    );

    await assertSucceeds(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'ok'),
        messageDoc(ALICE, 'x'.repeat(4000)),
      ),
    );
  });

  test('empty text with mediaPaths is still rejected (media-only deferred)', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'mediaOnly'),
        messageDoc(ALICE, '', [`bases/${BASE}/media/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`]),
      ),
    );
  });
});

describe('messages mediaPaths', () => {
  const pathA = `bases/${BASE}/media/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`;
  const pathB = `bases/${BASE}/media/ffffffff-1111-2222-3333-444444444444.jpg`;
  const crossBase = 'bases/otherBase/media/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg';

  test('text-only with mediaPaths [] succeeds', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'bases', BASE, 'messages', 'textOnly'), messageDoc(ALICE, 'hi')),
    );
  });

  test('valid mediaPaths (1–4, this-base prefix) succeed', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertSucceeds(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'one'),
        messageDoc(ALICE, 'one', [pathA]),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'two'),
        messageDoc(ALICE, 'two', [pathA, pathB]),
      ),
    );
  });

  test('missing mediaPaths key is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(doc(aliceDb(), 'bases', BASE, 'messages', 'noPaths'), {
        authorUid: ALICE,
        text: 'hi',
        createdAt: Timestamp.fromMillis(1_700_000_000_200),
        schemaVersion: 1,
      }),
    );
  });

  test('more than 4 mediaPaths is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    const five = [0, 1, 2, 3, 4].map(
      (i) => `bases/${BASE}/media/00000000-0000-0000-0000-00000000000${i}.jpg`,
    );
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'five'),
        messageDoc(ALICE, 'too many', five),
      ),
    );
  });

  test('cross-base mediaPaths prefix is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'cross'),
        messageDoc(ALICE, 'cross', [crossBase]),
      ),
    );
  });

  test('non-string mediaPaths entry is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'badType'),
        messageDoc(ALICE, 'bad', [123]),
      ),
    );
  });

  test('empty-string mediaPaths entry is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'emptyPath'),
        messageDoc(ALICE, 'bad', ['']),
      ),
    );
  });

  test('non-bases/ path (local-style key) is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'localKey'),
        messageDoc(ALICE, 'bad', [`${BASE}/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`]),
      ),
    );
  });

  test('path that only contains the prefix (junk before bases/) is rejected', async () => {
    // Proves matches() is whole-string: containing the prefix is not enough.
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'junkPrefix'),
        messageDoc(ALICE, 'bad', [`x/bases/${BASE}/media/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`]),
      ),
    );
  });

  test('baseId in wrong path segment (not after bases/) is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'wrongSeg'),
        messageDoc(ALICE, 'bad', [
          `media/${BASE}/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`,
        ]),
      ),
    );
  });

  test('wrong folder under base (not-media) is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'wrongFolder'),
        messageDoc(ALICE, 'bad', [
          `bases/${BASE}/not-media/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`,
        ]),
      ),
    );
  });

  test('empty leaf under media/ is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'emptyLeaf'),
        messageDoc(ALICE, 'bad', [`bases/${BASE}/media/`]),
      ),
    );
  });

  test('nested path under media/ is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'nested'),
        messageDoc(ALICE, 'bad', [
          `bases/${BASE}/media/foo/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg`,
        ]),
      ),
    );
  });

  test('non-jpg leaf is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'png'),
        messageDoc(ALICE, 'bad', [
          `bases/${BASE}/media/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png`,
        ]),
      ),
    );
  });

  test('non-uuid leaf (even with .jpg) is rejected', async () => {
    await seedOwnerBaseWithMemberRow();
    await assertFails(
      setDoc(
        doc(aliceDb(), 'bases', BASE, 'messages', 'notUuid'),
        messageDoc(ALICE, 'bad', [`bases/${BASE}/media/not-a-uuid.jpg`]),
      ),
    );
  });
});
