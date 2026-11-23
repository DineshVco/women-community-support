// One-time migration: gives every existing reply `status: 'visible'` and
// `flagCount: 0`.
//
// Why: the new firestore.rules let members read only visible replies, and
// the app now asks for `status == 'visible'`. Replies written before that
// change have no status field, so without this they would stop showing.
// Run it BEFORE deploying the new rules.
//
//   * The service account key must live OUTSIDE this project folder.
//   * Without --yes it only counts what it would change (a dry run).
//
//   node migrate_comment_status.mjs --key "C:\path\outside\project\key.json"
//   node migrate_comment_status.mjs --key "C:\path\outside\project\key.json" --yes
//   node migrate_comment_status.mjs --emulator --yes      (local emulator)
//
// Safe to run twice: replies that already have a status are left alone.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith('--')
    ? args[i + 1]
    : undefined;
};

const here = fileURLToPath(new URL('.', import.meta.url));
const keyPath = option('--key');
const write = flag('--yes');
const useEmulator = flag('--emulator');

if (!keyPath && !useEmulator) {
  console.error(
    'Usage: node migrate_comment_status.mjs --key <path to key outside the ' +
      'project> [--yes] | --emulator [--yes]',
  );
  process.exit(1);
}

let projectId = 'demo-looma';
if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  initializeApp({ projectId });
} else {
  // Refuse a key that sits inside the project folder.
  const projectRoot = resolve(here, '..').toLowerCase();
  if (resolve(keyPath).toLowerCase().startsWith(projectRoot)) {
    console.error(
      'The key file is inside the project folder. Move it outside the ' +
        'project first, so it can never be committed.',
    );
    process.exit(1);
  }
  const key = JSON.parse(readFileSync(keyPath, 'utf8'));
  projectId = key.project_id;
  initializeApp({ credential: cert(key), projectId });
}

const db = getFirestore();
console.log(
  `Project: ${projectId}${useEmulator ? ' (local emulator)' : ''}` +
    (write ? '' : '  [dry run: nothing is written]'),
);

let checked = 0;
let toFix = 0;
let batch = db.batch();
let inBatch = 0;

const comments = await db.collectionGroup('comments').get();
for (const doc of comments.docs) {
  checked++;
  const data = doc.data();
  if ('status' in data && 'flagCount' in data) continue;
  toFix++;
  if (!write) continue;
  batch.update(doc.ref, {
    ...('status' in data ? {} : { status: 'visible' }),
    ...('flagCount' in data ? {} : { flagCount: 0 }),
  });
  if (++inBatch === 400) {
    await batch.commit();
    batch = db.batch();
    inBatch = 0;
  }
}
if (write && inBatch > 0) await batch.commit();

console.log(
  `${checked} replies checked; ${toFix} ${write ? 'updated' : 'would be updated'}.`,
);
if (!write && toFix > 0) console.log('Run again with --yes to write.');
