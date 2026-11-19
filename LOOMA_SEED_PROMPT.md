# Seed content for the booth (Looma Team starter posts)

Content file: looma_starter_posts.json (15 posts + 3 replies, all by "Looma Team").

## Honesty rule (important)
These are starter posts written by the Looma team. They are NOT real users' stories. Show them as official Looma Team posts with a small "Looma Team" badge. Never present them as real community members. In the report, say so.

## Task for the Claude in VS Code
1. Add a script `tool/seed_starter_posts.js` (Node + firebase-admin) that writes the posts to Firestore with the exact field shape the app and rules expect (alias, categoryId, title, content, timestamp, flagCount 0, meTooCount 0, commentCount, status 'visible'), plus matching `authors/{postId}` documents. Use alias "Looma Team". Spread timestamps over the last 5 days so the feed looks natural. Make the script safe to run twice (no duplicates: use fixed ids like `starter_01`).
2. The script needs a Firebase service account key. NEVER commit it. Put it outside the repo or in a folder ignored by .gitignore, and add that ignore rule. The repo is public. Tell me step by step how to download the key (Firebase Console, Project settings, Service accounts) and delete it after seeding.
3. In the app: show a small "Looma Team" badge (black pill, white text, 10px) next to the alias when alias == "Looma Team", in the feed, post detail and replies.
4. Security: in firestore.rules, normal users must NOT be able to use the alias "Looma Team" (add `d.alias != 'Looma Team'` to post creation and the same for comments). Only the admin script can write it. Add rules tests.
5. Add a short "From the Looma Team" line on the first screen of Home: "Starter posts to begin the conversation. Add yours."
6. Run flutter analyze and flutter test. Report in simple English, including how to delete the seeded posts later.

## For Najwa to check before the booth
- Helpline numbers on the Get help tab (official sites).
- Read all 15 posts once and change any wording she does not like.
