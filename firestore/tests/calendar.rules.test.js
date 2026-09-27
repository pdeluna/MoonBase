/**
 * MoonBase firestore.rules — calendar emulator tests.
 *
 * Covers bases/{baseId}/events/{eventId} and bases/{baseId}/settings/{settingId}.
 * Kept in its own file so the calendar block does not collide with message-rule
 * edits in firestore.rules.test.js (PR #25 merge surface).
 *
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
  limit,
  Timestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-moonbase';
const RULES_PATH = path.resolve(__dirname, '..', '..', 'firestore.rules');

const ALICE = 'alice'; // owner
const BOB = 'bob'; // member
const CAROL = 'carol'; // non-member
const BASE = 'base1';

// Dart mirrors: kEventTitleMaxLen / kEventNotesMaxLen / kCalendarWindowMaxDays.
const TITLE_MAX = 80;
const NOTES_MAX = 500;
const WINDOW_MAX = 365;

let testEnv;

function rulesContent() {
  return fs.readFileSync(RULES_PATH, 'utf8');
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
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

const START = Timestamp.fromMillis(1_700_000_000_000);
const END_AFTER = Timestamp.fromMillis(1_700_003_600_000);
const END_BEFORE = Timestamp.fromMillis(1_699_999_999_000);
const WRITE_AT = Timestamp.fromMillis(1_700_000_000_500);

function eventDoc(createdBy, overrides = {}) {
  return {
    title: 'Dinner',
    startAt: START,
    endAt: null,
    allDay: false,
    notes: null,
    createdBy,
    createdAt: WRITE_AT,
    updatedAt: WRITE_AT,
    schemaVersion: 1,
    ...overrides,
  };
}

function settingsDoc(overrides = {}) {
  return {
    pastDays: 7,
    futureDays: 30,
    eventCreation: 'members',
    updatedAt: WRITE_AT,
    schemaVersion: 1,
    ...overrides,
  };
}

function eventRef(db, eventId) {
  return doc(db, 'bases', BASE, 'events', eventId);
}

function settingsRef(db, settingId = 'calendar') {
  return doc(db, 'bases', BASE, 'settings', settingId);
}

/** Alice owns BASE; Bob is a member; Carol is not. */
async function seedBaseWithOwnerAndMember() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'bases', BASE), baseDoc(ALICE, [ALICE, BOB]));
    await setDoc(doc(db, 'bases', BASE, 'members', ALICE), memberDoc('owner', 'Alice'));
    await setDoc(doc(db, 'bases', BASE, 'members', BOB), memberDoc('member', 'Bob'));
  });
}

async function seedSettings(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(settingsRef(ctx.firestore()), settingsDoc(overrides));
  });
}

async function seedEvent(eventId, createdBy, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(eventRef(ctx.firestore(), eventId), eventDoc(createdBy, overrides));
  });
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
  await seedBaseWithOwnerAndMember();
});

describe('events — read', () => {
  test('member can read an event; non-member is denied', async () => {
    await seedEvent('e1', ALICE);
    const snap = await assertSucceeds(getDoc(eventRef(dbFor(BOB), 'e1')));
    expect(snap.data().title).toBe('Dinner');
    await assertFails(getDoc(eventRef(dbFor(CAROL), 'e1')));
  });

  test('member can run the window range query (single-field, no composite index)', async () => {
    await seedEvent('e1', ALICE);
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(dbFor(BOB), 'bases', BASE, 'events'),
          where('startAt', '>=', Timestamp.fromMillis(1_699_000_000_000)),
          where('startAt', '<', Timestamp.fromMillis(1_701_000_000_000)),
          orderBy('startAt'),
          limit(200),
        ),
      ),
    );
    expect(snap.size).toBe(1);
  });
});

describe('events — create policy (settings/calendar.eventCreation)', () => {
  test('member create ok when no settings doc exists (default = members)', async () => {
    await assertSucceeds(setDoc(eventRef(dbFor(BOB), 'e1'), eventDoc(BOB)));
  });

  test("member create ok when eventCreation == 'members'", async () => {
    await seedSettings({ eventCreation: 'members' });
    await assertSucceeds(setDoc(eventRef(dbFor(BOB), 'e1'), eventDoc(BOB)));
  });

  test("member create denied when eventCreation == 'owner'", async () => {
    await seedSettings({ eventCreation: 'owner' });
    await assertFails(setDoc(eventRef(dbFor(BOB), 'e1'), eventDoc(BOB)));
  });

  test("owner create ok when eventCreation == 'owner'", async () => {
    await seedSettings({ eventCreation: 'owner' });
    await assertSucceeds(setDoc(eventRef(dbFor(ALICE), 'e1'), eventDoc(ALICE)));
  });

  test('non-member create denied even with default policy', async () => {
    await assertFails(setDoc(eventRef(dbFor(CAROL), 'e1'), eventDoc(CAROL)));
  });

  test('create with foreign createdBy is denied', async () => {
    await assertFails(setDoc(eventRef(dbFor(BOB), 'e1'), eventDoc(ALICE)));
  });
});

describe('events — field validation on create', () => {
  test(`title: 0 chars denied, ${TITLE_MAX + 1} denied, ${TITLE_MAX} ok`, async () => {
    await assertFails(setDoc(eventRef(dbFor(BOB), 'empty'), eventDoc(BOB, { title: '' })));
    await assertFails(
      setDoc(eventRef(dbFor(BOB), 'long'), eventDoc(BOB, { title: 'x'.repeat(TITLE_MAX + 1) })),
    );
    await assertSucceeds(
      setDoc(eventRef(dbFor(BOB), 'max'), eventDoc(BOB, { title: 'x'.repeat(TITLE_MAX) })),
    );
  });

  test('endAt < startAt denied; endAt >= startAt ok; endAt omitted ok', async () => {
    await assertFails(setDoc(eventRef(dbFor(BOB), 'bad'), eventDoc(BOB, { endAt: END_BEFORE })));
    await assertSucceeds(setDoc(eventRef(dbFor(BOB), 'ok'), eventDoc(BOB, { endAt: END_AFTER })));
    const noEnd = eventDoc(BOB);
    delete noEnd.endAt;
    await assertSucceeds(setDoc(eventRef(dbFor(BOB), 'noEnd'), noEnd));
  });

  test(`notes: ${NOTES_MAX + 1} denied, ${NOTES_MAX} ok, omitted ok`, async () => {
    await assertFails(
      setDoc(eventRef(dbFor(BOB), 'long'), eventDoc(BOB, { notes: 'n'.repeat(NOTES_MAX + 1) })),
    );
    await assertSucceeds(
      setDoc(eventRef(dbFor(BOB), 'max'), eventDoc(BOB, { notes: 'n'.repeat(NOTES_MAX) })),
    );
    const noNotes = eventDoc(BOB);
    delete noNotes.notes;
    await assertSucceeds(setDoc(eventRef(dbFor(BOB), 'noNotes'), noNotes));
  });

  test('missing allDay / non-timestamp startAt / unknown key / wrong schemaVersion are denied', async () => {
    const noAllDay = eventDoc(BOB);
    delete noAllDay.allDay;
    await assertFails(setDoc(eventRef(dbFor(BOB), 'noAllDay'), noAllDay));
    await assertFails(
      setDoc(eventRef(dbFor(BOB), 'strStart'), eventDoc(BOB, { startAt: '2026-01-01' })),
    );
    await assertFails(
      setDoc(eventRef(dbFor(BOB), 'extra'), eventDoc(BOB, { attachmentPaths: [] })),
    );
    await assertFails(setDoc(eventRef(dbFor(BOB), 'v2'), eventDoc(BOB, { schemaVersion: 2 })));
  });
});

describe('events — update', () => {
  test('author update ok', async () => {
    await seedEvent('e1', BOB);
    await assertSucceeds(
      updateDoc(eventRef(dbFor(BOB), 'e1'), { title: 'Lunch', updatedAt: WRITE_AT }),
    );
  });

  test('other member update denied', async () => {
    await seedEvent('e1', ALICE);
    await assertFails(
      updateDoc(eventRef(dbFor(BOB), 'e1'), { title: 'Hijacked', updatedAt: WRITE_AT }),
    );
  });

  test("owner update ok (also under eventCreation == 'owner' — policy gates creation only)", async () => {
    await seedSettings({ eventCreation: 'owner' });
    await seedEvent('e1', BOB);
    await assertSucceeds(
      updateDoc(eventRef(dbFor(ALICE), 'e1'), { title: 'Moved', updatedAt: WRITE_AT }),
    );
  });

  test("author may still edit own event under eventCreation == 'owner'", async () => {
    await seedSettings({ eventCreation: 'owner' });
    await seedEvent('e1', BOB);
    await assertSucceeds(
      updateDoc(eventRef(dbFor(BOB), 'e1'), { title: 'Mine', updatedAt: WRITE_AT }),
    );
  });

  test('createdBy / createdAt are immutable; validation applies on update', async () => {
    await seedEvent('e1', BOB);
    await assertFails(updateDoc(eventRef(dbFor(BOB), 'e1'), { createdBy: ALICE }));
    await assertFails(
      updateDoc(eventRef(dbFor(BOB), 'e1'), { createdAt: Timestamp.fromMillis(1) }),
    );
    await assertFails(
      updateDoc(eventRef(dbFor(BOB), 'e1'), { title: 'x'.repeat(TITLE_MAX + 1) }),
    );
    await assertFails(updateDoc(eventRef(dbFor(BOB), 'e1'), { endAt: END_BEFORE }));
  });
});

describe('events — delete', () => {
  test('author delete ok', async () => {
    await seedEvent('e1', BOB);
    await assertSucceeds(deleteDoc(eventRef(dbFor(BOB), 'e1')));
  });

  test('owner delete ok', async () => {
    await seedEvent('e1', BOB);
    await assertSucceeds(deleteDoc(eventRef(dbFor(ALICE), 'e1')));
  });

  test('other member delete denied; non-member delete denied', async () => {
    await seedEvent('e1', ALICE);
    await assertFails(deleteDoc(eventRef(dbFor(BOB), 'e1')));
    await assertFails(deleteDoc(eventRef(dbFor(CAROL), 'e1')));
  });
});

describe('settings/calendar', () => {
  test('member can read; non-member denied', async () => {
    await seedSettings();
    const snap = await assertSucceeds(getDoc(settingsRef(dbFor(BOB))));
    expect(snap.data().eventCreation).toBe('members');
    await assertFails(getDoc(settingsRef(dbFor(CAROL))));
  });

  test('owner write ok (create then update)', async () => {
    await assertSucceeds(setDoc(settingsRef(dbFor(ALICE)), settingsDoc()));
    await assertSucceeds(
      setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ pastDays: 0, futureDays: 7, eventCreation: 'owner' })),
    );
  });

  test('member write denied', async () => {
    await assertFails(setDoc(settingsRef(dbFor(BOB)), settingsDoc()));
  });

  test(`pastDays ${WINDOW_MAX + 1} denied; ${WINDOW_MAX} ok; negative denied; non-int denied`, async () => {
    await assertFails(
      setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ pastDays: WINDOW_MAX + 1 })),
    );
    await assertSucceeds(
      setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ pastDays: WINDOW_MAX, futureDays: WINDOW_MAX })),
    );
    await assertFails(setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ futureDays: -1 })));
    await assertFails(setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ futureDays: 7.5 })));
  });

  test("eventCreation 'anyone' denied", async () => {
    await assertFails(
      setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ eventCreation: 'anyone' })),
    );
  });

  test('unknown key / missing updatedAt / wrong schemaVersion denied', async () => {
    await assertFails(setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ quietHours: true })));
    const noUpdated = settingsDoc();
    delete noUpdated.updatedAt;
    await assertFails(setDoc(settingsRef(dbFor(ALICE)), noUpdated));
    await assertFails(setDoc(settingsRef(dbFor(ALICE)), settingsDoc({ schemaVersion: 2 })));
  });

  test("settings/other (any settingId != 'calendar') write denied even for owner", async () => {
    await assertFails(setDoc(settingsRef(dbFor(ALICE), 'notifications'), settingsDoc()));
  });

  test('owner can delete settings doc (deleteBase sweep); member cannot', async () => {
    await seedSettings();
    await assertFails(deleteDoc(settingsRef(dbFor(BOB))));
    await assertSucceeds(deleteDoc(settingsRef(dbFor(ALICE))));
  });
});
