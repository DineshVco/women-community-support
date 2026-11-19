// ╔══════════════════════════════════════════════════════════════════════╗
// ║  DEMO CONTENT for the Looma booth. NOT real people or real stories.  ║
// ║  Every post has `demo: true` so it can be found and removed again.   ║
// ╚══════════════════════════════════════════════════════════════════════╝
//
// Adds 12 starter posts and a few replies to Firestore using the Firebase
// Admin SDK (it runs on your PC, not in the app, so the app's 1-post-per-
// minute rule does not apply).
//
// How to run (from the tool/ folder):
//   1. Firebase console → Project settings → Service accounts →
//      "Generate new private key". Save it OUTSIDE the project folder, e.g.
//      C:\Users\<you>\firebase-keys\looma-admin.json, and pass that path to
//      --key. Never share or commit it.
//   2. npm install                         (first time only)
//   3. node seed.mjs --key <key path>          (dry run: shows what it would do)
//   4. node seed.mjs --key <key path> --yes    (writes the demo content)
//   To remove it again:
//      node seed.mjs --key <key path> --delete --yes
//
// Fixed ids (demo-01 … demo-12), so running it twice does not duplicate.
// Also works against the local emulator: add --emulator instead of --key.

import { readFileSync } from 'node:fs';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

// The app has four categories. Work and money → career, family → health &
// wellness, study → education.
const CAREER = 'career_development';
const HEALTH = 'health_wellness';
const STUDY = 'education';
const SAFETY = 'personal_safety';

/** hoursAgo: how long ago the post was written (spreads them over 3 days). */
const POSTS = [
  {
    id: 'demo-01',
    category: CAREER,
    alias: 'Quiet Fox',
    hoursAgo: 2,
    meToo: 6,
    title: 'First job interview next week, so nervous',
    content:
      'Got my first proper interview at a bank in KL next Tuesday. Any tips ah? ' +
      'What did you all wear and what questions did they ask?',
    replies: [
      {
        alias: 'Steady Heron',
        text:
          'Wear something simple and neat, cannot go wrong. Prepare "tell me about ' +
          'yourself" properly, they always ask that first.',
      },
      { alias: 'Quiet Fox', text: 'Thank you! Will practise tonight in front of the mirror.' },
    ],
  },
  {
    id: 'demo-02',
    category: CAREER,
    alias: 'Brave Hornbill',
    hoursAgo: 5,
    meToo: 11,
    title: 'How do you ask for a raise without sounding demanding?',
    content:
      'Almost 2 years in my company, workload doubled but salary still the same. ' +
      'My boss is quite nice but I really don’t know how to bring it up.',
    replies: [
      {
        alias: 'Calm Orchid',
        text:
          'List down what you took on since you joined, with numbers if can. Then ask ' +
          'for a review meeting, not "a raise". Easier to start the talk that way.',
      },
    ],
  },
  {
    id: 'demo-03',
    category: HEALTH, // family
    alias: 'Gentle Lotus',
    hoursAgo: 9,
    meToo: 14,
    title: 'Family keeps asking when I’m getting married',
    content:
      'Every Raya same question lah. I’m 27 and happy focusing on my career for now. ' +
      'How do you all handle the aunties without being rude?',
    replies: [
      {
        alias: 'Witty Mynah',
        text: 'Just smile and say "when the time is right, Aunty". Works every time 😂',
      },
    ],
  },
  {
    id: 'demo-04',
    category: HEALTH, // family
    alias: 'Patient Turtle',
    hoursAgo: 14,
    meToo: 8,
    title: 'Caring for my mum while working full time',
    content:
      'My mum had a stroke last year and I’m the main caregiver. Some days I feel so ' +
      'tired and guilty at the same time. Anyone in the same boat?',
    replies: [],
  },
  {
    id: 'demo-05',
    category: HEALTH,
    alias: 'Hopeful Fern',
    hoursAgo: 20,
    meToo: 12,
    title: 'Period pain so bad I can’t go to class',
    content:
      'Every month confirm 1 or 2 days I cannot get out of bed. Painkillers not ' +
      'helping much. Is this normal or should I see a gynae?',
    replies: [
      {
        alias: 'Kind Egret',
        text:
          'Not normal if it stops you from going to class. Please see a gynae, better ' +
          'to check early. Write down your symptoms each month to show the doctor.',
      },
    ],
  },
  {
    id: 'demo-06',
    category: HEALTH,
    alias: 'Curious Sunbird',
    hoursAgo: 26,
    meToo: 4,
    title: 'First time going for a pap smear, what happens?',
    content:
      'My clinic sent a reminder for a pap smear. First time, quite scared. ' +
      'What actually happens ah? Does it hurt?',
    replies: [],
  },
  {
    id: 'demo-07',
    category: CAREER, // money
    alias: 'Honest Gecko',
    hoursAgo: 31,
    meToo: 9,
    title: 'How much do you all save every month?',
    content:
      'Just started working, salary RM3,200. After rent, car and sending money home, ' +
      'left very little. How do you all budget?',
    replies: [
      {
        alias: 'Thoughtful Swallow',
        text:
          'I put a fixed amount into a separate account the day salary comes in, even ' +
          'RM100. Whatever left is for spending. Small amount also can.',
      },
    ],
  },
  {
    id: 'demo-08',
    category: CAREER, // money
    alias: 'Sincere Magpie',
    hoursAgo: 38,
    meToo: 5,
    title: 'Where to start investing with small amounts?',
    content:
      'I have about RM200 extra every month. Very scared of scams after what happened ' +
      'to my cousin. Where should a beginner start?',
    replies: [],
  },
  {
    id: 'demo-09',
    category: SAFETY,
    alias: 'Bold Tapir',
    hoursAgo: 44,
    meToo: 10,
    title: 'Driver kept asking personal questions',
    content:
      'Last night the e-hailing driver kept asking where I stay and if I live alone. ' +
      'Nothing happened but I felt very uncomfortable. Should I report?',
    replies: [
      {
        alias: 'Swift Kingfisher',
        text:
          'Yes, report in the e-hailing app. They take it seriously and it helps protect ' +
          'the next person. Next time you can also share your trip with a friend.',
      },
    ],
  },
  {
    id: 'demo-10',
    category: SAFETY,
    alias: 'Serene Dragonfly',
    hoursAgo: 52,
    meToo: 7,
    title: 'Walking back from the LRT at night',
    content:
      'My office finishes late and the walk from the station is quite dark. ' +
      'What do you all do to feel safer?',
    replies: [],
  },
  {
    id: 'demo-11',
    category: STUDY,
    alias: 'Earnest Pandan',
    hoursAgo: 60,
    meToo: 6,
    title: 'FYP supervisor not replying for weeks',
    content:
      'My final year project supervisor has ignored my emails for 3 weeks already. ' +
      'Deadline is next month. Should I go to the faculty?',
    replies: [
      {
        alias: 'Clever Starling',
        text:
          'Go see the FYP coordinator. Bring printouts of your emails so you can show ' +
          'you tried. Happened to my friend, they helped quickly.',
      },
    ],
  },
  {
    id: 'demo-12',
    category: STUDY,
    alias: 'Bright Hibiscus',
    hoursAgo: 68,
    meToo: 3,
    title: 'Scholarship interview tips?',
    content:
      'Shortlisted for a scholarship interview, first time! Got group discussion and ' +
      'a panel interview. Any advice?',
    replies: [],
  },
];

// ───────────────────────── Command line ─────────────────────────

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const keyPath = args[args.indexOf('--key') + 1];
const confirmed = flag('--yes');
const remove = flag('--delete');
const useEmulator = flag('--emulator');

if (!useEmulator && (!args.includes('--key') || !keyPath)) {
  console.error('Usage: node seed.mjs --key <key path> [--yes] [--delete]');
  process.exit(1);
}

let projectId;
if (useEmulator) {
  projectId = 'demo-looma';
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  initializeApp({ projectId });
} else {
  const key = JSON.parse(readFileSync(keyPath, 'utf8'));
  projectId = key.project_id;
  initializeApp({ credential: cert(key), projectId });
}
const db = getFirestore();

console.log(`Project: ${projectId}${useEmulator ? ' (local emulator)' : ''}`);
console.log(remove ? 'Action: DELETE demo content' : 'Action: ADD demo content');

if (!confirmed) {
  console.log('\nDry run. Nothing was changed. It would:');
  for (const p of POSTS) {
    console.log(`  ${remove ? '-' : '+'} ${p.id}  [${p.category}]  ${p.title}  (${p.replies.length} replies)`);
  }
  console.log('\nAdd --yes to really do it.');
  process.exit(0);
}

// ───────────────────────── Write / delete ─────────────────────────

const now = Date.now();
const batch = db.batch();

for (const p of POSTS) {
  const postRef = db.collection('posts').doc(p.id);
  const replyRefs = p.replies.map((_, i) =>
    postRef.collection('comments').doc(`${p.id}-r${i + 1}`),
  );

  if (remove) {
    replyRefs.forEach((ref) => batch.delete(ref));
    batch.delete(postRef);
    continue;
  }

  const postedAt = now - p.hoursAgo * 3600 * 1000;
  batch.set(postRef, {
    alias: p.alias,
    categoryId: p.category,
    title: p.title,
    content: p.content,
    timestamp: Timestamp.fromMillis(postedAt),
    flagCount: 0,
    meTooCount: p.meToo,
    commentCount: p.replies.length,
    status: 'visible',
    demo: true, // DEMO CONTENT marker
  });

  p.replies.forEach((reply, i) => {
    batch.set(replyRefs[i], {
      alias: reply.alias,
      content: reply.text,
      // Replies arrive 20 minutes apart after the post.
      timestamp: Timestamp.fromMillis(postedAt + (i + 1) * 20 * 60 * 1000),
      parentCommentId: null,
      demo: true, // DEMO CONTENT marker
    });
  });
}

await batch.commit();
const replyCount = POSTS.reduce((n, p) => n + p.replies.length, 0);
console.log(
  remove
    ? `Deleted ${POSTS.length} demo posts and their ${replyCount} replies.`
    : `Added ${POSTS.length} demo posts and ${replyCount} replies.`,
);
