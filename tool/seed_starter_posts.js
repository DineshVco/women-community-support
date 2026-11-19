// Looma starter posts: a few posts by "Looma Team" so the feed is not empty
// on day one. Runs on your PC with the Firebase Admin SDK (not in the app).
//
// SAFETY
//   * The service account key must live OUTSIDE this project folder, e.g.
//     C:\Users\<you>\firebase-keys\looma-admin.json. Never commit or share it.
//   * Without --yes this is a DRY RUN: it only prints what it would do.
//
// USAGE (from the tool/ folder, after `npm install`)
//   node seed_starter_posts.js --key "C:\path\outside\project\key.json"          dry run
//   node seed_starter_posts.js --key "C:\path\outside\project\key.json" --yes    write
//   node seed_starter_posts.js --key "C:\path\outside\project\key.json" --delete --yes
//   Options: --posts <file>  (default: content/looma_starter_posts.json,
//                             else looma_starter_posts.json in the project root)
//            --emulator      (local emulator instead of --key)
//
// WHAT IT WRITES (exactly what the app and firestore.rules expect)
//   posts/starter_NN    {alias, categoryId, title, content, timestamp,
//                        flagCount: 0, meTooCount: 0, commentCount, status}
//   authors/starter_NN  {authorId: 'looma-team', createdAt}
//   replies (optional)  posts/starter_NN/comments/starter_NN_rM
//                       {alias, content, timestamp, parentCommentId: null}
//                       + posts/starter_NN/commentAuthors/starter_NN_rM
//   Fixed ids, and posts that already exist are SKIPPED (their Me too and
//   reply counts are left alone), so running it twice adds nothing.
//   starter_01 is the newest; the rest are spread over the last 5 days.

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const ALIAS = 'Looma Team';
/** Not a real Firebase uid (those are 28 characters), so no member owns it. */
const TEAM_AUTHOR_ID = 'looma-team';
const CATEGORIES = [
  'health_wellness',
  'education',
  'career_development',
  'personal_safety',
];
const SPREAD_MS = 5 * 24 * 3600 * 1000; // last 5 days

// ───────────────────────── Command line ─────────────────────────

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith('--')
    ? args[i + 1]
    : undefined;
};

const keyPath = option('--key');
const confirmed = flag('--yes');
const remove = flag('--delete');
const useEmulator = flag('--emulator');
const here = fileURLToPath(new URL('.', import.meta.url));
// content/looma_starter_posts.json, or the project root if it is there.
const defaultPosts = [
  resolve(here, '../content/looma_starter_posts.json'),
  resolve(here, '../looma_starter_posts.json'),
].find((f) => existsSync(f));
const postsPath = option('--posts') ? resolve(option('--posts')) : defaultPosts;
if (!postsPath || !existsSync(postsPath)) {
  console.error('Cannot find looma_starter_posts.json (use --posts <file>).');
  process.exit(1);
}

if (!useEmulator && !keyPath) {
  console.error(
    'Usage: node seed_starter_posts.js --key <path to key outside the project> ' +
      '[--yes] [--delete] [--posts file] [--emulator]',
  );
  process.exit(1);
}

// Refuse a key that sits inside the project folder.
if (keyPath) {
  const projectRoot = resolve(here, '..').toLowerCase();
  if (resolve(keyPath).toLowerCase().startsWith(projectRoot)) {
    console.error(
      'The key file is inside the project folder. Move it outside the ' +
        'project (e.g. C:\\Users\\<you>\\firebase-keys\\) and try again.',
    );
    process.exit(1);
  }
}

// ───────────────────────── Read and check the posts ─────────────────────────

/**
 * Reads looma_starter_posts.json:
 *   { "author": "Looma Team",
 *     "posts":   [ { "categoryId", "title", "content" }, ... ],
 *     "replies": [ { "postIndex": 0, "content": "..." }, ... ] }
 * postIndex counts from 0, so postIndex 0 is starter_01.
 */
function loadPosts(path) {
  const raw = JSON.parse(readFileSync(path, 'utf8'));
  if (raw.author !== undefined && raw.author !== ALIAS) {
    throw new Error(`${path}: author is "${raw.author}", expected "${ALIAS}"`);
  }
  const list = raw.posts;
  if (!Array.isArray(list) || list.length === 0) {
    throw new Error(`${path}: no posts found`);
  }
  if (list.length > 99) throw new Error('At most 99 starter posts.');

  const posts = list.map((p, i) => ({
    id: `starter_${String(i + 1).padStart(2, '0')}`,
    categoryId: p.categoryId,
    title: String(p.title ?? '').trim(),
    content: String(p.content ?? '').trim(),
    replies: [],
  }));

  for (const [j, r] of (raw.replies ?? []).entries()) {
    const post = posts[r.postIndex];
    if (!Number.isInteger(r.postIndex) || !post) {
      throw new Error(`reply ${j + 1}: postIndex ${r.postIndex} is not a post (0 to ${posts.length - 1})`);
    }
    post.replies.push(String(r.content ?? '').trim());
  }

  for (const p of posts) {
    const problems = [];
    if (!CATEGORIES.includes(p.categoryId)) {
      problems.push(`category "${p.categoryId}" is not one of ${CATEGORIES.join(', ')}`);
    }
    if (p.title.length < 3 || p.title.length > 120) problems.push('title must be 3–120 characters');
    if (p.content.length < 1 || p.content.length > 5000) problems.push('content must be 1–5000 characters');
    p.replies.forEach((r, k) => {
      if (r.length < 1 || r.length > 2000) problems.push(`reply ${k + 1} must be 1–2000 characters`);
    });
    if (problems.length) throw new Error(`${p.id} ("${p.title}"): ${problems.join('; ')}`);
  }
  return posts;
}

const posts = loadPosts(postsPath);

// ───────────────────────── Firebase ─────────────────────────

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
console.log(`Posts file: ${postsPath}`);
console.log(remove ? 'Action: DELETE the starter posts' : 'Action: ADD the starter posts');

// starter_01 is the newest; the others go back evenly over 5 days, with a
// few minutes' variation so they do not look machine-made.
const now = Date.now();
const step = SPREAD_MS / posts.length;
const postedAt = (i) =>
  now - Math.round(step * i + step * 0.25 + ((i * 37) % 55) * 60 * 1000);

if (!confirmed) {
  console.log('\nDry run. Nothing was changed. It would:');
  for (const [i, p] of posts.entries()) {
    const when = remove ? '' : `  ${new Date(postedAt(i)).toISOString().slice(0, 16)}`;
    console.log(
      `  ${remove ? '-' : '+'} ${p.id}${when}  [${p.categoryId}]  ${p.title}` +
        (p.replies.length ? `  (${p.replies.length} replies)` : ''),
    );
  }
  console.log('\nAdd --yes to really do it.');
  process.exit(0);
}

// ───────────────────────── Delete ─────────────────────────

if (remove) {
  let deleted = 0;
  for (const p of posts) {
    const postRef = db.collection('posts').doc(p.id);
    const snap = await postRef.get();
    if (snap.exists && snap.get('alias') !== ALIAS) {
      console.log(`  ! ${p.id} is not a Looma Team post. Left alone.`);
      continue;
    }
    // The post with its replies, reply authors and Me too reactions.
    await db.recursiveDelete(postRef);
    const authorRef = db.collection('authors').doc(p.id);
    const author = await authorRef.get();
    if (author.exists && author.get('authorId') === TEAM_AUTHOR_ID) {
      await authorRef.delete();
    }
    if (snap.exists) deleted++;
  }
  console.log(`Deleted ${deleted} starter posts (and everything under them).`);
  process.exit(0);
}

// ───────────────────────── Write ─────────────────────────

let added = 0;
for (const [i, p] of posts.entries()) {
  const postRef = db.collection('posts').doc(p.id);
  if ((await postRef.get()).exists) {
    console.log(`  = ${p.id} already there, skipped.`);
    continue;
  }
  const at = postedAt(i);
  const batch = db.batch();
  batch.set(postRef, {
    alias: ALIAS,
    categoryId: p.categoryId,
    title: p.title,
    content: p.content,
    timestamp: Timestamp.fromMillis(at),
    flagCount: 0,
    meTooCount: 0,
    commentCount: p.replies.length,
    status: 'visible',
  });
  batch.set(db.collection('authors').doc(p.id), {
    authorId: TEAM_AUTHOR_ID,
    createdAt: Timestamp.fromMillis(at),
  });
  p.replies.forEach((content, j) => {
    const replyId = `${p.id}_r${j + 1}`;
    // Replies 30 minutes apart, never in the future.
    const replyAt = Timestamp.fromMillis(Math.min(at + (j + 1) * 30 * 60 * 1000, now));
    batch.set(postRef.collection('comments').doc(replyId), {
      alias: ALIAS,
      content,
      timestamp: replyAt,
      parentCommentId: null,
    });
    batch.set(postRef.collection('commentAuthors').doc(replyId), {
      authorId: TEAM_AUTHOR_ID,
      createdAt: replyAt,
    });
  });
  await batch.commit();
  added++;
  console.log(`  + ${p.id}  ${p.title}`);
}
console.log(`Added ${added} starter posts (${posts.length - added} were already there).`);
