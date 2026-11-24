// Makes the web build lighter before it is deployed. Runs automatically
// before every Firebase Hosting deploy (see "predeploy" in firebase.json),
// or by hand after `flutter build web --release`:
//
//   node tool/trim_web_build.mjs
//
// 1. Icon fonts: the phosphor_flutter package ships six weights, and the
//    web app downloads every font in FontManifest.json before its first
//    frame. Looma only uses Regular and Fill (AppIcons; a test checks
//    that), so the other four (about 630 KB) are taken out.
// 2. Service worker: Looma no longer uses one (web/flutter_bootstrap.js).
//    Phones that still have the old one fetch this file to update it; it is
//    replaced by one that deletes its saved copies and removes itself.
//
// Safe to run more than once.

import { existsSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const web = join(root, 'build', 'web');
const manifestPath = join(web, 'assets', 'FontManifest.json');

if (!existsSync(manifestPath)) {
  console.error('No web build found. Run: flutter build web --release');
  process.exit(1);
}

// 1. Unused icon font weights.
const keep = new Set([
  'packages/phosphor_flutter/PhosphorRegular',
  'packages/phosphor_flutter/PhosphorFill',
]);
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
let saved = 0;
const kept = manifest.filter((family) => {
  const phosphor = family.family.startsWith('packages/phosphor_flutter/');
  if (!phosphor || keep.has(family.family)) return true;
  for (const font of family.fonts) {
    const file = join(web, 'assets', font.asset);
    if (existsSync(file)) {
      saved += statSync(file).size;
      rmSync(file);
    }
  }
  console.log(`  removed unused icon font: ${family.family}`);
  return false;
});
writeFileSync(manifestPath, JSON.stringify(kept));
console.log(
  `Icon fonts: kept ${keep.size} of the Phosphor weights` +
    (saved ? `, ${(saved / 1024).toFixed(0)} KB lighter.` : ' (already trimmed).'),
);

// 2. A service worker that cleans up and removes itself.
writeFileSync(
  join(web, 'flutter_service_worker.js'),
  `// Looma no longer uses a service worker. A phone that still has the old
// one gets this: it deletes the old saved copies and removes itself.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k.startsWith('flutter-')).map((k) => caches.delete(k)));
    await self.registration.unregister();
  })());
});
`,
);
console.log('Service worker: replaced by one that removes itself.');
