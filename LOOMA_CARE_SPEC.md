# Looma "Care and Community" spec: give the app depth and soul

Read this whole file and the files in content/ first. Build ONE phase at a time. After each phase:
flutter analyze, flutter test, rules tests (if rules changed), a short manual test, then a commit on branch `feature/care`.
Stop and report in simple English. Do not start the next phase until the user says "next".

## Global rules
- Style: Apple-like (Cupertino widgets, large titles, blurred bars, inset lists), black and white base, warm off-white #FBF7F3, Newsreader headings, system body font, blush accent #E9B8B3, soft category colours (blush #E9B8B3, sage #BFD0C1, sand #E6D3B3, lavender-grey #CFC9DB) ONLY for small dots, icons and labels. Reduce motion respected. Haptics light.
- Mascot (looma_cat_*) used on empty, loading, success and error states with the gentle float. Warm, plain, kind text. ALL user-facing strings in one place (ARB files, see Phase 6).
- Free Firebase plan only: no Cloud Functions, no push notifications, no paid APIs. Derive things on the device when possible.
- Anonymity rules from LOOMA_CONNECT_SPEC.md still apply. Nothing new may link a person to her posts. Private features (journal, mood, safety plan) are stored ONLY on her phone.
- Local private data: encrypt at rest (AES-GCM, key in flutter_secure_storage), exclude from cloud backup. On web, secure storage is weak: on web show these features with a clear note, or disable the journal and safety plan. Tell the user which you chose.
- Medical and legal content is general information only. Never give diagnoses, doses, or legal advice. Every guide ends with: "This is general information, not medical or legal advice." Facts marked [VERIFY] in content/ must be checked by Najwa with a trusted source before the booth; show the guide only after she removes the mark.
- Not an emergency service: show "In danger? Call 999" on the Care tab and in guides about safety.

## Phase 1: Care tab (local tools)
Navigation: tabs become Discuss, Connect (placeholder until Connect Phase B exists: hide it for now), Care, Me. "Get help" moves into Care.
Care screen (large title "Care"), sections as inset groups:
1. "In danger right now?" soft card, Call 999 (as in the Get help redesign).
2. Tools: Breathe, Ground yourself, How are you feeling, My journal, Safety plan.
3. Help lines (the redesigned Get help list, grouped by need, with "last checked" date).
4. Guides (links to the library, Phase 2).
Tools:
- Breathe: full-screen calm screen, the cat grows and shrinks with a circle (4s in, 4s hold optional, 6s out). Choose 1, 3 or 5 minutes. Soft haptic at each phase. Respect reduce motion (show a text counter instead).
- Ground yourself: 5-4-3-2-1 steps one screen at a time ("Name 5 things you can see"), big text, Next button, ends with a kind message.
- How are you feeling: 5 cat faces (great, good, okay, low, rough). Tap one, optional one-line note, saved on the phone. Calendar month view with small coloured dots, and a gentle weekly line ("You logged 4 days this week."). No scores, no streaks, no red. Under a low or rough tap, show a soft card: "Want to talk to someone?" linking to help lines.
- My journal: private notes with optional prompts (content/journal_prompts in guides.json). List, create, edit, delete. Locked with App lock later.
- Safety plan: as in the earlier app-lock spec: safe contacts, safe place, code word, things to keep ready, notes. Clear-my-plan button.
Tests: widget tests for each tool, storage encryption test, calendar logic test.

## Phase 2: Guides and directory (offline content)
- Load content/guides.json and content/directory.json from assets (offline). Guides list with category dots and reading time, detail page with large title, short sections, and a footer note.
- Directory: helplines and organisations with name, what they help with, number or website, language, hours (only if verified), and "Last checked: <date>". Tap to call or open the website; Copy button. Use ONLY entries in directory.json. Do not invent numbers, hours or addresses.
- Search across guides. Bookmark guides (local).
- Show only guides where `verified: true` unless the app runs in debug mode.
Tests: JSON loads, unverified guides hidden, search.

## Phase 3: Take part (polls, small wins, themed weeks, Ask Looma)
Backend (Firestore, rules, tests):
- Poll posts: `posts/{id}` gets optional `type: 'poll'` and `options: [string, ...]` (2 to 4 options, max 60 chars each) and `voteCounts: [int, ...]`. Rules: only valid shapes. Normal users may create polls like posts (same rate limit, same women-member check). Alias rules unchanged ("Looma Team" alias reserved).
- Voting: `posts/{id}/votes/{voteKey}` where voteKey = one-way hash of (uid + postId) so votes cannot be linked to a person. One vote per person (rules check the vote doc does not exist and the count goes up by exactly 1 for the chosen option, same pattern as "Me too"). No changing votes. Results are shown only after she votes.
- Small wins: a recurring thread. Admin (moderator) creates `threads/{id}` { title, kind: 'smallWins', startsAt, endsAt, pinned: true }. The app pins the current thread at the top of Discuss. Replies are normal replies. Only moderators can create threads.
- Themed weeks: `themes/current` { title, subtitle, colorKey, guideIds[], startsAt, endsAt } written by a moderator in the console. Home shows a banner while active.
- Ask Looma Team: a category "Ask Looma" where anyone posts a question; only moderators can reply with the alias "Looma Team" (admin only, via console or the moderator screen, no new server).
UI: poll card in the feed (options as rounded bars after voting, percentages), a "New poll" option in the compose sheet. Banner and pinned thread cards. Daily gentle question card (content/daily_questions.json, 30 items, changes at local midnight, deterministic by date); tapping it opens compose with the question as the title.
Tests: rules tests for polls, votes (double vote denied, wrong option count denied), threads (non-moderator denied). Widget tests for poll voting.

## Phase 4: Personal and alive
- Onboarding step "What brings you here?" (choose up to 3: Study, Work, Family, Safety, Friendship, Money, Feeling low, Just looking). Store `interests` in users/{uid} (private). Home sorts and highlights matching categories and guides (client side). Editable in Me.
- Activity centre (bell on Discuss): derived on the device. For each of her posts (found through her own authors docs) and her replies, compare current `commentCount`, `meTooCount` and `helpfulCount` with the last seen values stored locally. Show lines like "3 women replied to your post" and "12 felt 'me too'". No names. Mark seen when opened. A small dot on the bell, no numbers.
- "This helped me": a reaction on replies (like Me too, vote-key style, one per person) that increments `helpfulCount`. Shown as a small count and hand icon.
- Kindness summary (private, in Me): computed on the device from her own replies: how many replies received "This helped me". Soft labels ("Good listener" after 5). Never public, no leaderboard, no streaks.
- "Check on me tomorrow": after she posts something that triggered the "Are you okay?" sheet, offer a local reminder (flutter_local_notifications, notification text: "Looma: just checking in." with no private details). Needs permission, skip on web.
- Gentle mode (already built) also hides activity counts.
Tests: derived activity logic, helpful reaction rules.

## Phase 5: Human content
- "Why Looma exists": page under Me > About with the letter from content/why_looma.md (placeholder). Najwa will replace it with her own words.
- "Voices" card on Home: a story chosen by Najwa, read from a Firestore doc `voices/current` { text, alias, week } written by a moderator. Shown only when present. Label it clearly as "Shared with permission".
- Greetings (content/microcopy.json): 5 variants shown on Home by time of day. Quiet-day line when the feed is calm. Cat blinks every 8 to 12 seconds on Care and onboarding.
- Rewrite all empty, error and success text using content/microcopy.json (replace old strings).

## Phase 6: Languages (English and Bahasa Malaysia)
- Move all user-facing strings to ARB files (flutter_localizations, intl): app_en.arb and app_ms.arb. Language switch in Me > Settings; default follows the phone.
- Produce the Malay translations, marked as a draft for Najwa to review (she must read every string). Guides and directory: translate titles and summaries only for now.
- Layouts must not break with longer Malay text. Test both languages in light and dark mode.

## Phase 7: Final polish and safety review
- Run the Soul pass prompt (mascot states, colours, delights) if not done.
- Performance: lists paginate 20 at a time, images cached, no full-feed rebuilds, release-mode check.
- Security: review all new rules (polls, votes, threads, themes, voices) with the strongest model. App Check and API key restriction (see earlier security list).
- Accessibility: text scaling, 48px tap targets, labels for screen readers, contrast.
- Write a short README section: what each tool does, what is stored where, and what is not done (future work).

## Report after each phase (simple English)
What changed, what to test on a real phone, what is not done, anything risky.
