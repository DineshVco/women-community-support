// Gives the "Founding member" badge to the first 50 Looma accounts.
//
// The badge lives in badges/{uid} = { foundingMember: true }. The app can
// only READ it (firestore.rules: write is false), so it can only be set here,
// with the Firebase Admin SDK, by the project owner.
//
// How to run (from the tool/ folder):
//   1. Put the service account key in tool/service-account.json
//      (see seed.mjs; it is in .gitignore. Never share or commit it.)
//   2. node founding-members.mjs --key service-account.json         (dry run)
//   3. node founding-members.mjs --key service-account.json --yes   (writes)
//
// "First 50" = the 50 oldest real logins (email or Google) by creation time.
// Anonymous guest logins from old versions are skipped. Running it again
// does not change anyone already badged.
import { readFileSync } from 'node:fs';
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const LIMIT = 50;

const args = process.argv.slice(2);
const keyIndex = args.indexOf('--key');
const write = args.includes('--yes');

if (keyIndex < 0 || !args[keyIndex + 1]) {
  console.error('Usage: node founding-members.mjs --key service-account.json [--yes]');
  process.exit(1);
}

const key = JSON.parse(readFileSync(args[keyIndex + 1], 'utf8'));
initializeApp({ credential: cert(key) });
const auth = getAuth();
const db = getFirestore();

// All logins, page by page.
const users = [];
let pageToken;
do {
  const page = await auth.listUsers(1000, pageToken);
  users.push(...page.users);
  pageToken = page.pageToken;
} while (pageToken);

const founders = users
  .filter((u) => u.providerData.length > 0) // skip anonymous guests
  .sort(
    (a, b) =>
      new Date(a.metadata.creationTime) - new Date(b.metadata.creationTime),
  )
  .slice(0, LIMIT);

console.log(`${users.length} logins; ${founders.length} founding members:`);
for (const u of founders) {
  // Print only the uid and date: no emails in the terminal history.
  console.log(`  ${u.uid}  joined ${u.metadata.creationTime}`);
}

if (!write) {
  console.log('\nDry run. Add --yes to write the badges.');
  process.exit(0);
}

const batch = db.batch();
for (const u of founders) {
  batch.set(db.collection('badges').doc(u.uid), { foundingMember: true });
}
await batch.commit();
console.log(`\nDone: ${founders.length} badges written.`);
