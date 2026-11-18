// Tests for ../firestore.rules, run against the local Firestore emulator
// (an offline copy of Firestore; nothing touches the real project).
//
//   cd tool
//   npm install          (first time only)
//   npm run test:rules
//
// Uses the "demo-looma" project id: "demo-" projects only exist locally.

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;
const thisYear = new Date().getFullYear();

/** A signed-in person. Real tokens always say how they signed in. */
function as(uid, provider = 'password') {
  return env
    .authenticatedContext(uid, { firebase: { sign_in_provider: provider } })
    .firestore();
}

/** Seeds data directly, skipping the rules (like the Firebase console). */
async function seed(fn) {
  await env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

/** Makes `uid` a member who finished both sign-up steps. */
async function makeMember(uid) {
  await seed((db) =>
    setDoc(doc(db, 'users', uid), { isWoman: true, birthYear: 1995 }),
  );
}

/** What PostRepository.createPost writes, in one batch. */
function createPostBatch(db, uid, postId) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts', postId), {
    alias: 'Quiet Fox',
    categoryId: 'education',
    title: 'Scholarship tips?',
    content: 'Any advice for first-year applications?',
    timestamp: serverTimestamp(),
    flagCount: 0,
    meTooCount: 0,
    commentCount: 0,
    status: 'visible',
  });
  batch.set(doc(db, 'authors', postId), {
    authorId: uid,
    createdAt: serverTimestamp(),
  });
  batch.set(
    doc(db, 'users', uid),
    { lastPostAt: serverTimestamp() },
    { merge: true },
  );
  return batch.commit();
}

/** What PostRepository.addComment writes, in one batch. */
function addCommentBatch(db, uid, postId, commentId) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts', postId, 'comments', commentId), {
    alias: 'Gentle Heron',
    content: 'Same here. Try the faculty office first.',
    timestamp: serverTimestamp(),
    parentCommentId: null,
  });
  batch.set(doc(db, 'posts', postId, 'commentAuthors', commentId), {
    authorId: uid,
    createdAt: serverTimestamp(),
  });
  batch.update(doc(db, 'posts', postId), {
    commentCount: 1,
  });
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-looma',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

// ───────────────────────── Guest logins ─────────────────────────

describe('anonymous (guest) logins', () => {
  test('cannot read posts', async () => {
    await assertFails(getDoc(doc(as('guest', 'anonymous'), 'posts', 'p1')));
  });

  test('cannot start sign-up', async () => {
    const db = as('guest', 'anonymous');
    await assertFails(setDoc(doc(db, 'users', 'guest'), { isWoman: true }));
  });

  test('cannot post even with a member profile', async () => {
    await makeMember('guest');
    await assertFails(createPostBatch(as('guest', 'anonymous'), 'guest', 'p1'));
  });
});

// ───────────────────────── users/{uid} profile ─────────────────────────

describe('private profile', () => {
  test('a person can confirm "I am a woman"', async () => {
    const db = as('amira');
    await assertSucceeds(
      setDoc(doc(db, 'users', 'amira'), { isWoman: true }, { merge: true }),
    );
  });

  test('isWoman can never be false', async () => {
    const db = as('amira');
    await assertFails(setDoc(doc(db, 'users', 'amira'), { isWoman: false }));
  });

  test('birthday step needs the women-only step first', async () => {
    const db = as('amira');
    await assertFails(setDoc(doc(db, 'users', 'amira'), { birthYear: 1995 }));
  });

  test('saves an adult birth year once', async () => {
    await seed((db) => setDoc(doc(db, 'users', 'amira'), { isWoman: true }));
    const db = as('amira');
    await assertSucceeds(
      setDoc(doc(db, 'users', 'amira'), { birthYear: 1995 }, { merge: true }),
    );
    // ...and it cannot be changed afterwards.
    await assertFails(updateDoc(doc(db, 'users', 'amira'), { birthYear: 1990 }));
  });

  test('refuses a birth year that is clearly under 18', async () => {
    await seed((db) => setDoc(doc(db, 'users', 'amira'), { isWoman: true }));
    const db = as('amira');
    await assertFails(
      setDoc(
        doc(db, 'users', 'amira'),
        { birthYear: thisYear - 10 },
        { merge: true },
      ),
    );
  });

  test('refuses extra fields such as a full birth date', async () => {
    const db = as('amira');
    await assertFails(
      setDoc(doc(db, 'users', 'amira'), { isWoman: true, birthday: '1995-03-12' }),
    );
  });

  test('cannot fake the last-post time', async () => {
    await makeMember('amira');
    const db = as('amira');
    await assertFails(
      updateDoc(doc(db, 'users', 'amira'), { lastPostAt: new Date(2000, 0, 1) }),
    );
  });

  test('nobody else can read it', async () => {
    await makeMember('amira');
    await assertSucceeds(getDoc(doc(as('amira'), 'users', 'amira')));
    await assertFails(getDoc(doc(as('siti'), 'users', 'amira')));
  });

  test('owner can read her own profile before it exists (first sign-in)', async () => {
    await assertSucceeds(getDoc(doc(as('amira'), 'users', 'amira')));
  });

  test('a Google account can read and create its own profile', async () => {
    const db = as('gina', 'google.com');
    await assertSucceeds(getDoc(doc(db, 'users', 'gina')));
    await assertSucceeds(
      setDoc(doc(db, 'users', 'gina'), { isWoman: true }, { merge: true }),
    );
  });

  test('nobody can create or change someone else’s profile', async () => {
    await assertFails(setDoc(doc(as('siti'), 'users', 'amira'), { isWoman: true }));
    await makeMember('amira');
    await assertFails(
      updateDoc(doc(as('siti'), 'users', 'amira'), { lastPostAt: serverTimestamp() }),
    );
  });

  test('signed-out visitors cannot read profiles', async () => {
    await makeMember('amira');
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users', 'amira')));
  });

  test('createdAt: server time once, never changed', async () => {
    const db = as('amira');
    await assertSucceeds(
      setDoc(doc(db, 'users', 'amira'), {
        isWoman: true,
        createdAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'users', 'amira'), { createdAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('siti'), 'users', 'siti'), { createdAt: new Date(2000, 0, 1) }),
    );
  });

  test('only the owner can delete her profile (account deletion)', async () => {
    await makeMember('amira');
    await assertFails(deleteDoc(doc(as('siti'), 'users', 'amira')));
    await assertSucceeds(deleteDoc(doc(as('amira'), 'users', 'amira')));
  });
});

// ───────────────────────── Posting ─────────────────────────

describe('posts', () => {
  test('a member can post', async () => {
    await makeMember('amira');
    await assertSucceeds(createPostBatch(as('amira'), 'amira', 'p1'));
  });

  test('posting keeps the profile answers (merge)', async () => {
    await makeMember('amira');
    await createPostBatch(as('amira'), 'amira', 'p1');
    let data;
    await env.withSecurityRulesDisabled(async (ctx) => {
      data = (await getDoc(doc(ctx.firestore(), 'users', 'amira'))).data();
    });
    if (data.isWoman !== true || data.birthYear !== 1995) {
      throw new Error(`profile was overwritten: ${JSON.stringify(data)}`);
    }
  });

  test('someone who skipped the sign-up steps cannot post', async () => {
    await assertFails(createPostBatch(as('newbie'), 'newbie', 'p1'));
  });

  test('someone who only confirmed "I am a woman" cannot post yet', async () => {
    await seed((db) => setDoc(doc(db, 'users', 'half'), { isWoman: true }));
    await assertFails(createPostBatch(as('half'), 'half', 'p1'));
  });

  test('one post per minute', async () => {
    await makeMember('amira');
    await assertSucceeds(createPostBatch(as('amira'), 'amira', 'p1'));
    await assertFails(createPostBatch(as('amira'), 'amira', 'p2'));
  });
});

// ───────────────────────── Replies ─────────────────────────

describe('replies', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'posts', 'p1'), {
        alias: 'Quiet Fox',
        categoryId: 'education',
        title: 'Scholarship tips?',
        content: 'Any advice?',
        timestamp: new Date(),
        flagCount: 0,
        meTooCount: 0,
        commentCount: 0,
        status: 'visible',
      }),
    );
  });

  test('a member can reply', async () => {
    await makeMember('siti');
    await assertSucceeds(addCommentBatch(as('siti'), 'siti', 'p1', 'c1'));
  });

  test('a non-member cannot reply', async () => {
    await assertFails(addCommentBatch(as('newbie'), 'newbie', 'p1', 'c1'));
  });
});

// ───────────────────────── Looma Connect: chat profiles ─────────────────────────

/** Same as ChatRepository.chatIdFor in the app. */
const chatIdOf = (uid) =>
  createHash('sha256').update('looma-chat:' + uid).digest('hex');

const DAY = 24 * 60 * 60 * 1000;

/** A member whose account is [ageMs] old. */
async function makeMemberAged(uid, ageMs) {
  await seed((db) =>
    setDoc(doc(db, 'users', uid), {
      isWoman: true,
      birthYear: 1995,
      createdAt: new Date(Date.now() - ageMs),
    }),
  );
}

function chatProfile(overrides = {}) {
  return {
    alias: 'moonreader',
    avatarId: 'cat_03',
    bio: 'Second-year student, love long walks.',
    interests: ['study', 'mental_wellbeing'],
    lookingFor: ['study_buddy'],
    open: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

/** A stored profile (seeded, so plain dates instead of server time). */
function storedProfile(overrides = {}) {
  return chatProfile({ createdAt: new Date(), updatedAt: new Date(), ...overrides });
}

const myProfileDoc = (db, uid) => doc(db, 'chatProfiles', chatIdOf(uid));

describe('chat profiles', () => {
  test('a member creates her own profile under her hashed id', async () => {
    await makeMemberAged('amira', 2 * DAY);
    await assertSucceeds(setDoc(myProfileDoc(as('amira'), 'amira'), chatProfile()));
  });

  test('the document id must be her hash, not her uid or anyone else’s', async () => {
    await makeMemberAged('amira', 2 * DAY);
    await assertFails(setDoc(doc(as('amira'), 'chatProfiles', 'amira'), chatProfile()));
    await assertFails(setDoc(myProfileDoc(as('amira'), 'siti'), chatProfile()));
  });

  test('non-members cannot create one', async () => {
    await assertFails(setDoc(myProfileDoc(as('newbie'), 'newbie'), chatProfile()));
  });

  test('"Open to chat" needs a 24 hour old account', async () => {
    await makeMemberAged('fresh', 2 * 60 * 60 * 1000); // 2 hours
    await assertFails(
      setDoc(myProfileDoc(as('fresh'), 'fresh'), chatProfile({ open: true })),
    );
    await assertSucceeds(setDoc(myProfileDoc(as('fresh'), 'fresh'), chatProfile()));

    await makeMemberAged('settled', 2 * DAY);
    await assertSucceeds(
      setDoc(myProfileDoc(as('settled'), 'settled'), chatProfile({ open: true })),
    );
  });

  test('accounts without a sign-up time cannot open yet', async () => {
    await makeMember('old');
    await assertFails(
      setDoc(myProfileDoc(as('old'), 'old'), chatProfile({ open: true })),
    );
  });

  test('alias: 3 to 20 allowed characters, no phone numbers', async () => {
    await makeMemberAged('amira', 2 * DAY);
    const db = as('amira');
    for (const alias of ['ab', 'a'.repeat(21), 'bad<alias>', 'me 0123456789', 'amira@x']) {
      await assertFails(setDoc(myProfileDoc(db, 'amira'), chatProfile({ alias })));
    }
    await assertSucceeds(
      setDoc(myProfileDoc(db, 'amira'), chatProfile({ alias: 'calm_kitten-2' })),
    );
  });

  test('bio: max 120 characters and no contact details', async () => {
    await makeMemberAged('amira', 2 * DAY);
    const db = as('amira');
    const refused = [
      'x'.repeat(121),
      'see https://example.org',
      'visit WWW.mypage.net',
      'find me at mypage.com!',
      'my site is mypage.my',
      'email amira@mail.com',
      'IG @amira_x',
      'whatsapp 012-345 6789',
      'call +60 12 345 6789',
    ];
    for (const bio of refused) {
      await assertFails(setDoc(myProfileDoc(db, 'amira'), chatProfile({ bio })));
    }
    const allowed = [
      '',
      'Class of 2020-2024. I love cats.',
      'Studying at uni, @ home most days',
      'I like co-op games and mysteries.',
    ];
    for (const bio of allowed) {
      await assertSucceeds(setDoc(myProfileDoc(db, 'amira'), chatProfile({ bio })));
      // Start fresh: a second create would try to change createdAt.
      await deleteDoc(myProfileDoc(db, 'amira'));
    }
  });

  test('interests, looking-for and avatar come from the fixed lists', async () => {
    await makeMemberAged('amira', 2 * DAY);
    const db = as('amira');
    const bad = [
      { interests: ['health', 'study', 'career', 'safety', 'family', 'money'] },
      { interests: ['dating'] },
      { interests: ['health', 'health'] },
      { lookingFor: ['talk', 'friends', 'study_buddy'] },
      { lookingFor: ['romance'] },
      { avatarId: 'photo_1' },
    ];
    for (const change of bad) {
      await assertFails(setDoc(myProfileDoc(db, 'amira'), chatProfile(change)));
    }
  });

  test('refuses extra fields such as a real name', async () => {
    await makeMemberAged('amira', 2 * DAY);
    await assertFails(
      setDoc(myProfileDoc(as('amira'), 'amira'), chatProfile({ realName: 'Amira' })),
    );
  });

  test('createdAt is kept; updatedAt is server time', async () => {
    await makeMemberAged('amira', 2 * DAY);
    const db = as('amira');
    await assertSucceeds(setDoc(myProfileDoc(db, 'amira'), chatProfile()));
    await assertFails(
      setDoc(myProfileDoc(db, 'amira'), chatProfile({ createdAt: new Date(2000, 0, 1) })),
    );
    await assertFails(
      updateDoc(myProfileDoc(db, 'amira'), { bio: 'hi', updatedAt: new Date(2000, 0, 1) }),
    );
    await assertSucceeds(
      updateDoc(myProfileDoc(db, 'amira'), { bio: 'hi', updatedAt: serverTimestamp() }),
    );
  });

  test('others can read it only while it is open', async () => {
    await makeMemberAged('amira', 2 * DAY);
    await makeMember('siti');
    await seed((db) => setDoc(myProfileDoc(db, 'amira'), storedProfile()));
    await assertFails(getDoc(myProfileDoc(as('siti'), 'amira')));
    // She can always read her own.
    await assertSucceeds(getDoc(myProfileDoc(as('amira'), 'amira')));

    await seed((db) => updateDoc(myProfileDoc(db, 'amira'), { open: true }));
    await assertSucceeds(getDoc(myProfileDoc(as('siti'), 'amira')));
    // Not for people who did not finish sign-up, even when open.
    await assertFails(getDoc(myProfileDoc(as('newbie'), 'amira')));
  });

  test('the hub must ask only for open profiles', async () => {
    await makeMember('siti');
    const db = as('siti');
    await assertFails(getDocs(collection(db, 'chatProfiles')));
    await assertSucceeds(
      getDocs(query(collection(db, 'chatProfiles'), where('open', '==', true))),
    );
  });

  test('nobody else can change or delete it; she can delete it', async () => {
    await makeMemberAged('amira', 2 * DAY);
    await makeMemberAged('siti', 2 * DAY);
    await seed((db) => setDoc(myProfileDoc(db, 'amira'), storedProfile({ open: true })));
    await assertFails(
      updateDoc(myProfileDoc(as('siti'), 'amira'), { bio: 'hacked', updatedAt: serverTimestamp() }),
    );
    await assertFails(deleteDoc(myProfileDoc(as('siti'), 'amira')));
    await assertSucceeds(deleteDoc(myProfileDoc(as('amira'), 'amira')));
  });
});

// ───────────────────────── Saved posts, badges, my replies ─────────────────────────

describe('saved posts', () => {
  test('only she can save, see and remove her saved posts', async () => {
    const mine = doc(as('amira'), 'users', 'amira', 'saved', 'p1');
    await assertSucceeds(setDoc(mine, { createdAt: serverTimestamp() }));
    await assertSucceeds(getDoc(mine));
    await assertFails(getDoc(doc(as('siti'), 'users', 'amira', 'saved', 'p1')));
    await assertFails(
      setDoc(doc(as('siti'), 'users', 'amira', 'saved', 'p2'), { createdAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('amira'), 'users', 'amira', 'saved', 'p3'), {
        createdAt: serverTimestamp(),
        note: 'x',
      }),
    );
    await assertSucceeds(deleteDoc(mine));
  });
});

describe('badges', () => {
  test('she can read her own badge but nobody can write one', async () => {
    await seed((db) => setDoc(doc(db, 'badges', 'amira'), { foundingMember: true }));
    await assertSucceeds(getDoc(doc(as('amira'), 'badges', 'amira')));
    await assertFails(getDoc(doc(as('siti'), 'badges', 'amira')));
    await assertFails(setDoc(doc(as('siti'), 'badges', 'siti'), { foundingMember: true }));
  });
});

describe('finding my own replies (for account deletion)', () => {
  test('she can list her own replies across posts, never someone else’s', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'posts', 'p1', 'commentAuthors', 'c1'), {
        authorId: 'amira',
        createdAt: new Date(),
      });
      await setDoc(doc(db, 'posts', 'p2', 'commentAuthors', 'c2'), {
        authorId: 'siti',
        createdAt: new Date(),
      });
    });
    const mine = await assertSucceeds(
      getDocs(
        query(collectionGroup(as('amira'), 'commentAuthors'), where('authorId', '==', 'amira')),
      ),
    );
    if (mine.size !== 1) throw new Error(`expected 1 reply, got ${mine.size}`);
    await assertFails(
      getDocs(
        query(collectionGroup(as('amira'), 'commentAuthors'), where('authorId', '==', 'siti')),
      ),
    );
  });
});

// ───────────────────────── Phase A.5: secret alias key ─────────────────────────

describe('secret alias key', () => {
  const key = 'ab'.repeat(32); // 64 hex characters

  test('she can set it once, as 64 hex characters', async () => {
    await makeMember('amira');
    const mine = doc(as('amira'), 'users', 'amira');
    await assertFails(setDoc(mine, { aliasKey: 'short' }, { merge: true }));
    await assertFails(setDoc(mine, { aliasKey: 'Z'.repeat(64) }, { merge: true }));
    await assertSucceeds(setDoc(mine, { aliasKey: key }, { merge: true }));
    // Never changed afterwards.
    await assertFails(setDoc(mine, { aliasKey: 'cd'.repeat(32) }, { merge: true }));
  });

  test('nobody else can read or set it', async () => {
    await makeMember('amira');
    await seed((db) => updateDoc(doc(db, 'users', 'amira'), { aliasKey: key }));
    await assertFails(getDoc(doc(as('siti'), 'users', 'amira')));
    await assertFails(
      setDoc(doc(as('siti'), 'users', 'amira'), { aliasKey: key }, { merge: true }),
    );
  });

  test('posting still works with the key in her profile', async () => {
    await makeMember('amira');
    await seed((db) => updateDoc(doc(db, 'users', 'amira'), { aliasKey: key }));
    await assertSucceeds(createPostBatch(as('amira'), 'amira', 'p1'));
  });
});

// ───────────────────────── Phase A.5: account deletion guard ─────────────────────────

describe('deleting users/{uid}', () => {
  test('allowed if she never posted', async () => {
    await makeMember('amira');
    await assertSucceeds(deleteDoc(doc(as('amira'), 'users', 'amira')));
  });

  test('refused within 60 seconds of her last post', async () => {
    await makeMember('amira');
    await seed((db) =>
      updateDoc(doc(db, 'users', 'amira'), { lastPostAt: new Date(Date.now() - 10 * 1000) }),
    );
    await assertFails(deleteDoc(doc(as('amira'), 'users', 'amira')));
  });

  test('allowed once a minute has passed', async () => {
    await makeMember('amira');
    await seed((db) =>
      updateDoc(doc(db, 'users', 'amira'), { lastPostAt: new Date(Date.now() - 2 * 60 * 1000) }),
    );
    await assertSucceeds(deleteDoc(doc(as('amira'), 'users', 'amira')));
  });
});

// ───────────────────────── Phase A.5: reports with a hashed reporter ─────────────────────────

/** Same as PostRepository.reporterIdFor in the app. */
const reporterIdOf = (uid) =>
  createHash('sha256').update('looma-report:' + uid).digest('hex');

/** What PostRepository.reportPost writes, in one batch. */
function reportBatch(db, { postId, reportId, reporterId, flagCount = 1 }) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'reports', reportId), {
    postId,
    postTitle: 'Scholarship tips?',
    reason: 'Spam or advertising',
    reporterId,
    createdAt: serverTimestamp(),
    status: 'open',
  });
  batch.update(doc(db, 'posts', postId), { flagCount, status: 'visible' });
  return batch.commit();
}

describe('reports', () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, 'posts', 'p1'), {
        alias: 'Quiet Fox',
        categoryId: 'education',
        title: 'Scholarship tips?',
        content: 'Any advice?',
        timestamp: new Date(),
        flagCount: 0,
        meTooCount: 0,
        commentCount: 0,
        status: 'visible',
      }),
    );
  });

  test('a report uses the hashed reporter id, never the uid', async () => {
    const hashed = reporterIdOf('siti');
    await assertSucceeds(
      reportBatch(as('siti'), { postId: 'p1', reportId: `p1_${hashed}`, reporterId: hashed }),
    );
  });

  test('a report with the plain uid is refused', async () => {
    await assertFails(
      reportBatch(as('siti'), { postId: 'p1', reportId: 'p1_siti', reporterId: 'siti' }),
    );
    // Hashed document id but plain uid inside: also refused.
    await assertFails(
      reportBatch(as('siti'), {
        postId: 'p1',
        reportId: `p1_${reporterIdOf('siti')}`,
        reporterId: 'siti',
      }),
    );
  });

  test('nobody can file a report as someone else', async () => {
    const amira = reporterIdOf('amira');
    await assertFails(
      reportBatch(as('siti'), { postId: 'p1', reportId: `p1_${amira}`, reporterId: amira }),
    );
  });

  test('she can read her own report; others cannot; moderators can', async () => {
    const hashed = reporterIdOf('siti');
    await seed(async (db) => {
      await setDoc(doc(db, 'reports', `p1_${hashed}`), {
        postId: 'p1',
        postTitle: 'Scholarship tips?',
        reason: 'Spam or advertising',
        reporterId: hashed,
        createdAt: new Date(),
        status: 'open',
      });
      await setDoc(doc(db, 'moderators', 'mod'), {});
    });
    await assertSucceeds(getDoc(doc(as('siti'), 'reports', `p1_${hashed}`)));
    await assertSucceeds(
      getDocs(query(collection(as('siti'), 'reports'), where('reporterId', '==', hashed))),
    );
    await assertFails(getDoc(doc(as('amira'), 'reports', `p1_${hashed}`)));
    await assertSucceeds(getDoc(doc(as('mod'), 'reports', `p1_${hashed}`)));
  });
});
