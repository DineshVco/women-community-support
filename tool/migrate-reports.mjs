// One-off: converts reports made before Phase A.5 so they no longer hold
// the reporter's plain uid.
//
// Old: reports/{postId}_{uid}         with reporterId: uid
// New: reports/{postId}_{sha256}      with reporterId: sha256('looma-report:' + uid)
//
// Why: moderators can read reports. With the plain uid they could tell who
// reported, and (with the old alias formula) find the reporter's posts.
// After this, reporters also see their old reports again under "My reports".
//
// How to run (from the tool/ folder, with the git-ignored service key):
//   node migrate-reports.mjs --key service-account.json         (dry run)
//   node migrate-reports.mjs --key service-account.json --yes   (writes)
// Safe to run more than once: already-converted reports are skipped.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const keyIndex = args.indexOf('--key');
const write = args.includes('--yes');

if (keyIndex < 0 || !args[keyIndex + 1]) {
  console.error('Usage: node migrate-reports.mjs --key service-account.json [--yes]');
  process.exit(1);
}

initializeApp({ credential: cert(JSON.parse(readFileSync(args[keyIndex + 1], 'utf8'))) });
const db = getFirestore();

const hashed = (uid) => createHash('sha256').update('looma-report:' + uid).digest('hex');
const isHash = (value) => /^[0-9a-f]{64}$/.test(value ?? '');

const snapshot = await db.collection('reports').get();
const old = snapshot.docs.filter((d) => !isHash(d.data().reporterId));

console.log(`${snapshot.size} reports; ${old.length} still hold a plain uid.`);
if (!write) {
  console.log('Dry run. Add --yes to convert them.');
  process.exit(0);
}

let converted = 0;
let merged = 0;
for (const report of old) {
  const data = report.data();
  const reporterId = hashed(data.reporterId);
  const target = db.collection('reports').doc(`${data.postId}_${reporterId}`);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(target);
    if (existing.exists) {
      merged++; // already reported again under the new id: keep that one
    } else {
      tx.set(target, { ...data, reporterId });
      converted++;
    }
    tx.delete(report.ref);
  });
}
console.log(`Done: ${converted} converted, ${merged} duplicates removed.`);
