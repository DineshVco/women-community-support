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
function createPostBatch(db, uid, postId, alias = 'Quiet Fox') {
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts', postId), {
    alias,
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
function addCommentBatch(db, uid, postId, commentId, alias = 'Gentle Heron') {
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts', postId, 'comments', commentId), {
    alias,
    content: 'Same here. Try the faculty office first.',
    timestamp: serverTimestamp(),
    parentCommentId: null,
    status: 'visible',
    flagCount: 0,
  });
  batch.set(doc(db, 'posts', postId, 'commentAuthors', commentId), {
    authorId: uid,
    createdAt: serverTimestamp(),
  });
  batch.update(doc(db, 'posts', postId), {
    commentCount: 1,
    lastCommentId: commentId,
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

  test('members cannot post as "Looma Team" (any spelling)', async () => {
    for (const [i, alias] of [
      'Looma Team', 'looma team', 'LOOMA TEAM', 'LoomaTeam', 'Looma-Team',
      ' Looma  Team ', 'Looma.Team',
    ].entries()) {
      const uid = `m${i}`;
      await makeMember(uid);
      await assertFails(createPostBatch(as(uid), uid, `p${i}`, alias));
    }
  });

  test('aliases that only contain the words are fine', async () => {
    await makeMember('amira');
    await assertSucceeds(
      createPostBatch(as('amira'), 'amira', 'p1', 'Looma Teammate Fox'),
    );
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

  test('members cannot reply as "Looma Team" (any spelling)', async () => {
    await makeMember('siti');
    for (const [i, alias] of ['Looma Team', 'looma team', 'LoomaTeam'].entries()) {
      await assertFails(
        addCommentBatch(as('siti'), 'siti', 'p1', `c${i}`, alias),
      );
    }
  });

  test('members can reply to a Looma Team starter post', async () => {
    await seed((db) =>
      setDoc(doc(db, 'posts', 'starter_01'), {
        alias: 'Looma Team',
        categoryId: 'health_wellness',
        title: 'Welcome to Looma',
        content: 'Say hello.',
        timestamp: new Date(),
        flagCount: 0,
        meTooCount: 0,
        commentCount: 0,
        status: 'visible',
      }),
    );
    await makeMember('siti');
    await assertSucceeds(
      addCommentBatch(as('siti'), 'siti', 'starter_01', 'c1'),
    );
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
    // Reporting needs a finished member.
    for (const uid of ['siti', 'amira']) await makeMember(uid);
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

// ───────────────────────── Phase 3: polls ─────────────────────────

const voteKey = (uid, postId) =>
  createHash('sha256').update(`looma-vote:${postId}:${uid}`).digest('hex');

async function makeModerator(uid) {
  await makeMember(uid);
  await seed((db) => setDoc(doc(db, 'moderators', uid), {}));
}

/** What PostRepository.createPoll writes, in one batch. */
function createPollBatch(db, uid, postId, extra = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts', postId), {
    alias: 'Quiet Fox',
    categoryId: 'health_wellness',
    title: 'Do you feel guilty when you rest?',
    content: '',
    timestamp: serverTimestamp(),
    flagCount: 0,
    meTooCount: 0,
    commentCount: 0,
    status: 'visible',
    type: 'poll',
    options: ['Yes', 'Sometimes', 'No'],
    voteCounts: [0, 0, 0],
    ...extra,
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

/** What PostRepository.vote writes: her vote key + the new counts. */
function voteBatch(db, uid, postId, newCounts, key = voteKey(uid, postId)) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts', postId, 'votes', key), {
    createdAt: serverTimestamp(),
  });
  batch.update(doc(db, 'posts', postId), { voteCounts: newCounts });
  return batch.commit();
}

async function seedPoll(id = 'poll1', counts = [0, 0, 0], status = 'visible') {
  await seed((db) =>
    setDoc(doc(db, 'posts', id), {
      alias: 'Looma Team',
      categoryId: 'health_wellness',
      title: 'Do you feel guilty when you rest?',
      content: '',
      timestamp: new Date(),
      flagCount: 0,
      meTooCount: 0,
      commentCount: 0,
      status,
      type: 'poll',
      options: ['Yes', 'Sometimes', 'No'],
      voteCounts: counts,
    }),
  );
}

/** A plain post (not a poll), straight into the database. */
async function seedPlainPost(id, categoryId = 'education') {
  await seed((db) =>
    setDoc(doc(db, 'posts', id), {
      alias: 'Quiet Fox',
      categoryId,
      title: 'Scholarship tips?',
      content: 'Any advice?',
      timestamp: new Date(),
      flagCount: 0,
      meTooCount: 0,
      commentCount: 0,
      status: 'visible',
    }),
  );
}

describe('polls', () => {
  test('a member can create a poll with 2 to 4 options', async () => {
    await makeMember('a2');
    await assertSucceeds(
      createPollBatch(as('a2'), 'a2', 'p2', {
        options: ['Yes', 'No'],
        voteCounts: [0, 0],
      }),
    );
    await makeMember('a3');
    await assertSucceeds(createPollBatch(as('a3'), 'a3', 'p3'));
    await makeMember('a4');
    await assertSucceeds(
      createPollBatch(as('a4'), 'a4', 'p4', {
        options: ['A', 'B', 'C', 'D'],
        voteCounts: [0, 0, 0, 0],
      }),
    );
  });

  test('wrong shapes are refused', async () => {
    const bad = [
      { options: ['Only one'], voteCounts: [0] },
      { options: ['a', 'b', 'c', 'd', 'e'], voteCounts: [0, 0, 0, 0, 0] },
      { options: ['Yes', 'x'.repeat(61), 'No'] },
      { options: ['Yes', '', 'No'] },
      { voteCounts: [5, 0, 0] }, // cannot start with votes
      { voteCounts: [0, 0] }, // count list does not match the options
      { type: 'survey' },
    ];
    for (const [i, extra] of bad.entries()) {
      const uid = `m${i}`;
      await makeMember(uid);
      await assertFails(createPollBatch(as(uid), uid, `p${i}`, extra));
    }
  });

  test('a normal post cannot carry poll fields', async () => {
    await makeMember('amira');
    const db = as('amira');
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'p1'), {
      alias: 'Quiet Fox',
      categoryId: 'education',
      title: 'Scholarship tips?',
      content: 'Any advice?',
      timestamp: serverTimestamp(),
      flagCount: 0,
      meTooCount: 0,
      commentCount: 0,
      status: 'visible',
      voteCounts: [0, 0],
    });
    batch.set(doc(db, 'authors', 'p1'), {
      authorId: 'amira',
      createdAt: serverTimestamp(),
    });
    batch.set(
      doc(db, 'users', 'amira'),
      { lastPostAt: serverTimestamp() },
      { merge: true },
    );
    await assertFails(batch.commit());
  });

  test('polls follow the post rules: members only, one per minute', async () => {
    await assertFails(createPollBatch(as('newbie'), 'newbie', 'p1'));
    await makeMember('amira');
    await assertSucceeds(createPollBatch(as('amira'), 'amira', 'p1'));
    await assertFails(createPollBatch(as('amira'), 'amira', 'p2'));
  });

  test('members cannot create a poll as "Looma Team"', async () => {
    await makeMember('amira');
    await assertFails(
      createPollBatch(as('amira'), 'amira', 'p1', { alias: 'Looma Team' }),
    );
  });
});

describe('poll votes', () => {
  beforeEach(async () => {
    await seedPoll();
    await makeMember('siti');
  });

  test('a member votes once: +1 on one option', async () => {
    await assertSucceeds(voteBatch(as('siti'), 'siti', 'poll1', [0, 1, 0]));
  });

  test('a second vote by the same person is refused', async () => {
    await assertSucceeds(voteBatch(as('siti'), 'siti', 'poll1', [0, 1, 0]));
    await assertFails(voteBatch(as('siti'), 'siti', 'poll1', [1, 1, 0]));
  });

  test('two people can each vote once', async () => {
    await makeMember('amira');
    await assertSucceeds(voteBatch(as('siti'), 'siti', 'poll1', [0, 1, 0]));
    await assertSucceeds(voteBatch(as('amira'), 'amira', 'poll1', [0, 2, 0]));
  });

  test('wrong counts are refused', async () => {
    for (const counts of [
      [1, 1, 0], // two at once
      [0, 2, 0], // +2
      [0, 0, 0], // nothing
      [1, 0, 0, 0], // wrong option count
      [1, 0], // wrong option count
      [-1, 2, 0], // one down, one up
      [0.5, 0.5, 0], // not whole numbers
    ]) {
      await assertFails(voteBatch(as('siti'), 'siti', 'poll1', counts));
    }
  });

  test('the vote id must be her own vote key', async () => {
    await assertFails(
      voteBatch(as('siti'), 'siti', 'poll1', [1, 0, 0], 'siti'),
    );
    await assertFails(
      voteBatch(as('siti'), 'siti', 'poll1', [1, 0, 0], voteKey('amira', 'poll1')),
    );
  });

  test('the vote holds only the time (no option, no uid)', async () => {
    const db = as('siti');
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'poll1', 'votes', voteKey('siti', 'poll1')), {
      createdAt: serverTimestamp(),
      option: 1,
    });
    batch.update(doc(db, 'posts', 'poll1'), { voteCounts: [0, 1, 0] });
    await assertFails(batch.commit());
  });

  test('counts never change without a vote, and a vote needs the count', async () => {
    await assertFails(
      updateDoc(doc(as('siti'), 'posts', 'poll1'), { voteCounts: [0, 1, 0] }),
    );
    await assertFails(
      setDoc(
        doc(as('siti'), 'posts', 'poll1', 'votes', voteKey('siti', 'poll1')),
        { createdAt: serverTimestamp() },
      ),
    );
  });

  test('votes cannot be changed, deleted or listed; she can see her own', async () => {
    await voteBatch(as('siti'), 'siti', 'poll1', [0, 1, 0]);
    const mine = doc(
      as('siti'),
      'posts',
      'poll1',
      'votes',
      voteKey('siti', 'poll1'),
    );
    await assertSucceeds(getDoc(mine));
    await assertFails(updateDoc(mine, { createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(mine));

    await makeMember('amira');
    const theirs = doc(
      as('amira'),
      'posts',
      'poll1',
      'votes',
      voteKey('siti', 'poll1'),
    );
    await assertFails(getDoc(theirs));
    await assertFails(getDocs(collection(as('amira'), 'posts', 'poll1', 'votes')));
  });

  test('non-members and hidden polls cannot get votes', async () => {
    await assertFails(voteBatch(as('newbie'), 'newbie', 'poll1', [1, 0, 0]));
    await seedPoll('poll2', [0, 0, 0], 'hidden');
    await assertFails(voteBatch(as('siti'), 'siti', 'poll2', [1, 0, 0]));
  });

  test('normal posts cannot be voted on', async () => {
    await seedPlainPost('p1');
    await assertFails(voteBatch(as('siti'), 'siti', 'p1', [1]));
  });
});

// ───────────────────────── Phase 3: Ask Looma ─────────────────────────

describe('Ask Looma Team', () => {
  test('a member can ask in the Ask Looma category', async () => {
    await makeMember('amira');
    const db = as('amira');
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'q1'), {
      alias: 'Quiet Fox',
      categoryId: 'ask_looma',
      title: 'How do I change my alias?',
      content: 'Is it possible?',
      timestamp: serverTimestamp(),
      flagCount: 0,
      meTooCount: 0,
      commentCount: 0,
      status: 'visible',
    });
    batch.set(doc(db, 'authors', 'q1'), {
      authorId: 'amira',
      createdAt: serverTimestamp(),
    });
    batch.set(
      doc(db, 'users', 'amira'),
      { lastPostAt: serverTimestamp() },
      { merge: true },
    );
    await assertSucceeds(batch.commit());
  });

  test('a moderator can reply as "Looma Team"; a member cannot', async () => {
    await seedPlainPost('q1', 'ask_looma');
    await makeModerator('mod');
    await makeMember('siti');
    await assertSucceeds(
      addCommentBatch(as('mod'), 'mod', 'q1', 'c1', 'Looma Team'),
    );
    await assertFails(
      addCommentBatch(as('siti'), 'siti', 'q1', 'c2', 'Looma Team'),
    );
    // Members still reply under their own alias (on another question: the
    // test helper always sets commentCount to 1).
    await seedPlainPost('q2', 'ask_looma');
    await assertSucceeds(addCommentBatch(as('siti'), 'siti', 'q2', 'c3'));
  });

  test('a moderator can post as "Looma Team"', async () => {
    await makeModerator('mod');
    await assertSucceeds(createPostBatch(as('mod'), 'mod', 'w1', 'Looma Team'));
  });
});

// ───────────────────────── Phase 3: Small wins threads ─────────────────────────

describe('Small wins threads', () => {
  const day = 24 * 3600 * 1000;

  /** What PostRepository.startSmallWins writes: the post and its thread. */
  function startThreadBatch(db, uid, id, thread = {}) {
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', id), {
      alias: 'Looma Team',
      categoryId: 'health_wellness',
      title: 'Small wins this week: what went well, even a little?',
      content: 'Share one small good thing.',
      timestamp: serverTimestamp(),
      flagCount: 0,
      meTooCount: 0,
      commentCount: 0,
      status: 'visible',
    });
    batch.set(doc(db, 'authors', id), {
      authorId: uid,
      createdAt: serverTimestamp(),
    });
    batch.set(
      doc(db, 'users', uid),
      { lastPostAt: serverTimestamp() },
      { merge: true },
    );
    batch.set(doc(db, 'threads', id), {
      title: 'Small wins this week: what went well, even a little?',
      kind: 'smallWins',
      startsAt: new Date(),
      endsAt: new Date(Date.now() + 7 * day),
      pinned: true,
      ...thread,
    });
    return batch.commit();
  }

  test('a moderator starts a thread; members can read it', async () => {
    await makeModerator('mod');
    await assertSucceeds(startThreadBatch(as('mod'), 'mod', 'w1'));
    await makeMember('siti');
    await assertSucceeds(getDoc(doc(as('siti'), 'threads', 'w1')));
  });

  test('a non-moderator cannot create a thread', async () => {
    await makeMember('siti');
    await assertFails(startThreadBatch(as('siti'), 'siti', 'w1', {}));
    await assertFails(
      setDoc(doc(as('siti'), 'threads', 'w2'), {
        title: 'Small wins',
        kind: 'smallWins',
        startsAt: new Date(),
        endsAt: new Date(Date.now() + day),
        pinned: true,
      }),
    );
  });

  test('wrong shapes are refused, even for moderators', async () => {
    for (const [i, extra] of [
      { kind: 'announcement' },
      { endsAt: new Date(Date.now() - day) },
      { pinned: 'yes' },
      { title: 'Hi' },
      { extra: 1 },
    ].entries()) {
      // A fresh moderator each time (one post per minute).
      const mod = `mod${i}`;
      await makeModerator(mod);
      await assertFails(startThreadBatch(as(mod), mod, `w${i}`, extra));
    }
  });

  test('a thread needs its post', async () => {
    await makeModerator('mod');
    await assertFails(
      setDoc(doc(as('mod'), 'threads', 'w1'), {
        title: 'Small wins this week',
        kind: 'smallWins',
        startsAt: new Date(),
        endsAt: new Date(Date.now() + day),
        pinned: true,
      }),
    );
  });

  test('members reply to the thread normally', async () => {
    await makeModerator('mod');
    await startThreadBatch(as('mod'), 'mod', 'w1');
    await makeMember('siti');
    await assertSucceeds(addCommentBatch(as('siti'), 'siti', 'w1', 'c1'));
  });
});

// ───────────────────────── Phase 3: themed weeks ─────────────────────────

describe('themed week banner', () => {
  const theme = () => ({
    title: 'Rest week',
    subtitle: 'Small ways to recharge.',
    colorKey: 'sage',
    guideIds: ['sleep-basics'],
    startsAt: new Date(),
    endsAt: new Date(Date.now() + 7 * 24 * 3600 * 1000),
  });

  test('members can read it; only moderators can write it', async () => {
    await seed((db) => setDoc(doc(db, 'themes', 'current'), theme()));
    await makeMember('siti');
    await assertSucceeds(getDoc(doc(as('siti'), 'themes', 'current')));
    await assertFails(setDoc(doc(as('siti'), 'themes', 'current'), theme()));
    await assertFails(deleteDoc(doc(as('siti'), 'themes', 'current')));
    await makeModerator('mod');
    await assertSucceeds(setDoc(doc(as('mod'), 'themes', 'current'), theme()));
  });

  test('only themes/current, with a valid shape', async () => {
    await makeModerator('mod');
    const db = as('mod');
    await assertFails(setDoc(doc(db, 'themes', 'other'), theme()));
    await assertFails(
      setDoc(doc(db, 'themes', 'current'), { ...theme(), colorKey: 'red' }),
    );
    await assertFails(
      setDoc(doc(db, 'themes', 'current'), { ...theme(), extra: true }),
    );
  });

  test('signed-out visitors cannot read it', async () => {
    await seed((db) => setDoc(doc(db, 'themes', 'current'), theme()));
    const visitor = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(visitor, 'themes', 'current')));
  });
});

// ───────────────────────── Who can read what ─────────────────────────

/** A post (and its author record) straight into the database. */
async function seedPost(id, { status = 'visible', authorId = 'amira' } = {}) {
  await seed(async (db) => {
    await setDoc(doc(db, 'posts', id), {
      alias: 'Quiet Fox',
      categoryId: 'education',
      title: 'Scholarship tips?',
      content: 'Any advice?',
      timestamp: new Date(),
      flagCount: status === 'visible' ? 0 : 3,
      meTooCount: 0,
      commentCount: 0,
      status,
    });
    await setDoc(doc(db, 'authors', id), { authorId, createdAt: new Date() });
  });
}

/** A reply (and its author record) straight into the database. */
async function seedReply(postId, id, { status = 'visible', authorId = 'siti' } = {}) {
  await seed(async (db) => {
    await setDoc(doc(db, 'posts', postId, 'comments', id), {
      alias: 'Gentle Heron',
      content: 'Same here.',
      timestamp: new Date(),
      parentCommentId: null,
      status,
      flagCount: status === 'visible' ? 0 : 3,
    });
    await setDoc(doc(db, 'posts', postId, 'commentAuthors', id), {
      authorId,
      createdAt: new Date(),
    });
  });
}

describe('reading: members only, visible items only', () => {
  beforeEach(async () => {
    for (const uid of ['amira', 'siti', 'nur']) await makeMember(uid);
    await makeModerator('mod');
    await makeMember('mod');
  });

  test('signed in is not enough: only finished members read posts', async () => {
    await seedPost('p1');
    await assertFails(getDoc(doc(as('stranger'), 'posts', 'p1')));
    await assertSucceeds(getDoc(doc(as('nur'), 'posts', 'p1')));
  });

  test('replies and poll votes also need a finished member', async () => {
    await seedPost('p1');
    await seedReply('p1', 'c1');
    await assertFails(getDoc(doc(as('stranger'), 'posts', 'p1', 'comments', 'c1')));
    await assertSucceeds(getDoc(doc(as('nur'), 'posts', 'p1', 'comments', 'c1')));
    await seedPoll('poll1');
    await assertFails(
      getDoc(doc(as('stranger'), 'posts', 'poll1', 'votes', voteKey('stranger', 'poll1'))),
    );
  });

  test('the feed must ask for visible posts only', async () => {
    await seedPost('p1');
    await seedPost('p2', { status: 'hidden' });
    const db = as('nur');
    // Asking for everything could return the hidden post: refused.
    await assertFails(getDocs(collection(db, 'posts')));
    await assertSucceeds(
      getDocs(query(collection(db, 'posts'), where('status', '==', 'visible'))),
    );
  });

  for (const status of ['hidden', 'removed']) {
    test(`a ${status} post: not for members; yes for its author and moderators`, async () => {
      await seedPost('p1', { status });
      await assertFails(getDoc(doc(as('nur'), 'posts', 'p1')));
      await assertSucceeds(getDoc(doc(as('amira'), 'posts', 'p1'))); // author
      await assertSucceeds(getDoc(doc(as('mod'), 'posts', 'p1')));
      // And it never comes back in a member's feed query.
      const feed = await getDocs(
        query(collection(as('nur'), 'posts'), where('status', '==', 'visible')),
      );
      expect(feed.size === 0);
    });

    test(`a ${status} reply: not for members; yes for the post author and moderators`, async () => {
      await seedPost('p1');
      await seedReply('p1', 'c1', { status });
      await assertFails(getDoc(doc(as('nur'), 'posts', 'p1', 'comments', 'c1')));
      await assertSucceeds(getDoc(doc(as('amira'), 'posts', 'p1', 'comments', 'c1')));
      await assertSucceeds(getDoc(doc(as('mod'), 'posts', 'p1', 'comments', 'c1')));
    });

    test(`replies on a ${status} post are not for members`, async () => {
      await seedPost('p1', { status });
      await seedReply('p1', 'c1');
      await assertFails(getDoc(doc(as('nur'), 'posts', 'p1', 'comments', 'c1')));
      await assertSucceeds(getDoc(doc(as('amira'), 'posts', 'p1', 'comments', 'c1')));
    });
  }

  test('reply lists must ask for visible replies only', async () => {
    await seedPost('p1');
    await seedReply('p1', 'c1');
    await seedReply('p1', 'c2', { status: 'hidden' });
    const db = as('nur');
    // Asking for every reply could return the hidden one: refused.
    await assertFails(getDocs(collection(db, 'posts', 'p1', 'comments')));
    await assertSucceeds(
      getDocs(
        query(collection(db, 'posts', 'p1', 'comments'), where('status', '==', 'visible')),
      ),
    );
  });

  test('a new reply must start visible with no flags', async () => {
    await seedPost('p1');
    const db = as('siti');
    const bad = writeBatch(db);
    bad.set(doc(db, 'posts', 'p1', 'comments', 'c9'), {
      alias: 'Gentle Heron',
      content: 'Hi',
      timestamp: serverTimestamp(),
      parentCommentId: null,
      status: 'hidden',
      flagCount: 0,
    });
    bad.set(doc(db, 'posts', 'p1', 'commentAuthors', 'c9'), {
      authorId: 'siti',
      createdAt: serverTimestamp(),
    });
    await assertFails(bad.commit());
  });
});

function expect(ok) {
  if (!ok) throw new Error('expectation failed');
}

// ───────────────────────── Reply count ─────────────────────────

describe('reply count goes up only with a real new reply', () => {
  beforeEach(async () => {
    await makeMember('amira');
    await makeMember('siti');
    await seedPost('p1');
  });

  function bump(db, { lastCommentId = 'c1', commentCount = 1 } = {}) {
    return updateDoc(doc(db, 'posts', 'p1'), { commentCount, lastCommentId });
  }

  test('reply + author record + count +1 in one write: allowed', async () => {
    await assertSucceeds(addCommentBatch(as('siti'), 'siti', 'p1', 'c1'));
  });

  test('a count bump on its own is refused', async () => {
    await assertFails(bump(as('siti')));
    await assertFails(
      updateDoc(doc(as('siti'), 'posts', 'p1'), { commentCount: 1 }),
    );
  });

  test('+2 is refused, even with a reply', async () => {
    const db = as('siti');
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'p1', 'comments', 'c1'), {
      alias: 'Gentle Heron', content: 'Hi', timestamp: serverTimestamp(),
      parentCommentId: null, status: 'visible', flagCount: 0,
    });
    batch.set(doc(db, 'posts', 'p1', 'commentAuthors', 'c1'), {
      authorId: 'siti', createdAt: serverTimestamp(),
    });
    batch.update(doc(db, 'posts', 'p1'), { commentCount: 2, lastCommentId: 'c1' });
    await assertFails(batch.commit());
  });

  test('pointing at a reply that already existed is refused', async () => {
    await seedReply('p1', 'old');
    await assertFails(bump(as('siti'), { lastCommentId: 'old' }));
  });

  test("the reply's author record must be hers", async () => {
    const db = as('siti');
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'p1', 'comments', 'c1'), {
      alias: 'Gentle Heron', content: 'Hi', timestamp: serverTimestamp(),
      parentCommentId: null, status: 'visible', flagCount: 0,
    });
    batch.set(doc(db, 'posts', 'p1', 'commentAuthors', 'c1'), {
      authorId: 'amira', createdAt: serverTimestamp(),
    });
    batch.update(doc(db, 'posts', 'p1'), { commentCount: 1, lastCommentId: 'c1' });
    await assertFails(batch.commit());
  });

  test('a reply without the count going up is refused', async () => {
    const db = as('siti');
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'p1', 'comments', 'c1'), {
      alias: 'Gentle Heron', content: 'Hi', timestamp: serverTimestamp(),
      parentCommentId: null, status: 'visible', flagCount: 0,
    });
    batch.set(doc(db, 'posts', 'p1', 'commentAuthors', 'c1'), {
      authorId: 'siti', createdAt: serverTimestamp(),
    });
    await assertFails(batch.commit());
  });
});

// ───────────────────────── Reports: who and what ─────────────────────────

describe('reports: members only, real posts, once each', () => {
  function report(db, uid, postId) {
    const hashed = createHash('sha256').update(`looma-report:${uid}`).digest('hex');
    return reportBatch(db, {
      postId,
      reportId: `${postId}_${hashed}`,
      reporterId: hashed,
    });
  }

  test('a member can report a post that exists', async () => {
    await makeMember('nur');
    await seedPost('p1');
    await assertSucceeds(report(as('nur'), 'nur', 'p1'));
  });

  test('someone who did not finish sign-up cannot report', async () => {
    await seedPost('p1');
    await assertFails(report(as('stranger'), 'stranger', 'p1'));
  });

  test('a post that does not exist cannot be reported', async () => {
    await makeMember('nur');
    const hashed = createHash('sha256').update('looma-report:nur').digest('hex');
    const db = as('nur');
    await assertFails(
      setDoc(doc(db, 'reports', `ghost_${hashed}`), {
        postId: 'ghost',
        postTitle: 'x',
        reason: 'Spam or advertising',
        reporterId: hashed,
        createdAt: serverTimestamp(),
        status: 'open',
      }),
    );
  });

  test('the same person cannot report the same post twice', async () => {
    await makeMember('nur');
    await seedPost('p1');
    await assertSucceeds(report(as('nur'), 'nur', 'p1'));
    await assertFails(report(as('nur'), 'nur', 'p1'));
  });
});

// ───────────────────────── Reporting replies ─────────────────────────

/** What PostRepository.reportComment writes, in one batch. */
function replyReportBatch(db, uid, { postId = 'p1', commentId = 'c1', flagCount = 1, status = 'visible' } = {}) {
  const hashed = createHash('sha256').update(`looma-report:${uid}`).digest('hex');
  const batch = writeBatch(db);
  batch.set(doc(db, 'reports', `${postId}_${commentId}_${hashed}`), {
    postId,
    commentId,
    postTitle: 'Scholarship tips?',
    reason: 'Harassment or hate',
    reporterId: hashed,
    createdAt: serverTimestamp(),
    status: 'open',
  });
  batch.update(doc(db, 'posts', postId, 'comments', commentId), { flagCount, status });
  return batch.commit();
}

describe('reporting replies', () => {
  beforeEach(async () => {
    for (const uid of ['amira', 'siti', 'nur', 'aisyah', 'farah']) await makeMember(uid);
    await makeModerator('mod');
    await makeMember('mod');
    await seedPost('p1');
    await seedReply('p1', 'c1');
  });

  test('a member reports a reply: +1 flag', async () => {
    await assertSucceeds(replyReportBatch(as('nur'), 'nur'));
  });

  test('once per person per reply', async () => {
    await assertSucceeds(replyReportBatch(as('nur'), 'nur'));
    await assertFails(replyReportBatch(as('nur'), 'nur', { flagCount: 2 }));
  });

  test('the third report hides the reply', async () => {
    await assertSucceeds(replyReportBatch(as('nur'), 'nur', { flagCount: 1 }));
    await assertSucceeds(replyReportBatch(as('aisyah'), 'aisyah', { flagCount: 2 }));
    // Third report: must hide it.
    await assertFails(replyReportBatch(as('farah'), 'farah', { flagCount: 3, status: 'visible' }));
    await assertSucceeds(replyReportBatch(as('farah'), 'farah', { flagCount: 3, status: 'hidden' }));
    // Now members cannot read it; the post author and moderators can.
    await assertFails(getDoc(doc(as('nur'), 'posts', 'p1', 'comments', 'c1')));
    await assertSucceeds(getDoc(doc(as('amira'), 'posts', 'p1', 'comments', 'c1')));
    await assertSucceeds(getDoc(doc(as('mod'), 'posts', 'p1', 'comments', 'c1')));
  });

  test('no flag without a report, and no other changes', async () => {
    const db = as('nur');
    await assertFails(
      updateDoc(doc(db, 'posts', 'p1', 'comments', 'c1'), { flagCount: 1, status: 'visible' }),
    );
    await assertFails(
      updateDoc(doc(db, 'posts', 'p1', 'comments', 'c1'), { content: 'changed' }),
    );
    await assertFails(
      updateDoc(doc(db, 'posts', 'p1', 'comments', 'c1'), { status: 'removed' }),
    );
  });

  test('non-members cannot report a reply', async () => {
    await assertFails(replyReportBatch(as('stranger'), 'stranger'));
  });

  test('a reply that does not exist cannot be reported', async () => {
    const hashed = createHash('sha256').update('looma-report:nur').digest('hex');
    await assertFails(
      setDoc(doc(as('nur'), 'reports', `p1_ghost_${hashed}`), {
        postId: 'p1',
        commentId: 'ghost',
        postTitle: 'x',
        reason: 'Spam or advertising',
        reporterId: hashed,
        createdAt: serverTimestamp(),
        status: 'open',
      }),
    );
  });

  test('the report id must match the reply and her hash', async () => {
    const hashed = createHash('sha256').update('looma-report:nur').digest('hex');
    await assertFails(
      setDoc(doc(as('nur'), 'reports', `p1_${hashed}`), {
        postId: 'p1',
        commentId: 'c1',
        postTitle: 'x',
        reason: 'Spam or advertising',
        reporterId: hashed,
        createdAt: serverTimestamp(),
        status: 'open',
      }),
    );
  });

  test('a moderator removes or keeps a reply; members cannot', async () => {
    await assertSucceeds(
      updateDoc(doc(as('mod'), 'posts', 'p1', 'comments', 'c1'), { status: 'removed' }),
    );
    await assertSucceeds(
      updateDoc(doc(as('mod'), 'posts', 'p1', 'comments', 'c1'), { status: 'visible', flagCount: 0 }),
    );
    await assertFails(
      updateDoc(doc(as('mod'), 'posts', 'p1', 'comments', 'c1'), { content: 'edited' }),
    );
    await assertFails(
      updateDoc(doc(as('amira'), 'posts', 'p1', 'comments', 'c1'), { status: 'removed' }),
    );
  });

  test('the moderator queue can read reply reports; reporters only their own', async () => {
    await assertSucceeds(replyReportBatch(as('nur'), 'nur'));
    await assertSucceeds(
      getDocs(query(collection(as('mod'), 'reports'), where('status', '==', 'open'))),
    );
    const hashed = createHash('sha256').update('looma-report:nur').digest('hex');
    await assertSucceeds(getDoc(doc(as('nur'), 'reports', `p1_c1_${hashed}`)));
    await assertFails(getDoc(doc(as('siti'), 'reports', `p1_c1_${hashed}`)));
  });
});
