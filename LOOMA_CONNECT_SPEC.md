# Looma Connect: find people who relate, private chat, better profile

Read the whole file first. Build in the phases below, ONE phase at a time. After each phase: flutter analyze, flutter test, rules tests, and a manual test with TWO accounts (emulator + a phone, or two emulators). Do not start the next phase until the user says so.

## 0. Principles (do not break these)
1. **A chat identity is separate from post aliases.** Nothing in the app may let anyone link a chat profile to a post or reply (no "message the author" button on posts). People connect only through the Connect hub, by choice.
2. **Opt-in everywhere.** Not listed in the hub until she turns on "Open to chat". She can turn it off any time and she disappears from the hub.
3. **Mutual consent.** No message can be sent until the other person accepts a request.
4. **No pressure.** No read receipts, no "typing...", no online status, no streaks, no red badges. A small dot on the tab is enough.
5. **No media, no links.** Text only. Block phone numbers, emails, links and handles (client check + rules regex).
6. **Safety tools one tap away:** block, report, end chat, hide, Quick exit.
7. **Honest wording.** "Women only" is self-confirmed, not proven. Say so in the safety page.
8. Free plan only: Firestore + in-app listeners. No Cloud Functions, no push notifications (say so in the report as future work).
9. Copy the style already used: black and white, Newsreader headings, blush accent #E9B8B3, 4/8/12/16/24 spacing, Cupertino transitions, haptics, reduce-motion respected.

## 1. Navigation
Bottom bar becomes 4 tabs: Discuss, Connect, Get help, Me. Small dot on Connect when there is a new request or message.

## 2. Phase A: Profile revamp (Me tab) + chat profile
Me tab layout, top to bottom:
- Avatar (choose from the 12 line-art cat/colour avatars in assets/images/avatars/, create simple ones in the same style; no photos allowed) + chat alias (editable, 3 to 20 chars, no real-name patterns, filtered) + one-line bio (max 120 chars, filtered).
- "Open to chat" switch with an explanation: "Other women can see your alias, avatar, interests and bio. Never your name, email or posts."
- Interests: choose up to 5 chips (Health, Study, Career, Safety, Family, Money, Friendship, Mental wellbeing, New in town, Hobbies). Also "Looking for": Someone to talk to / Study buddy / Career advice / Just friends (choose up to 2).
- My space: My posts (read from authors/{postId} where authorId == me; only she sees this), Saved posts, My requests, Blocked list.
- Privacy centre: plain words list of what others can see and what the project owner can see; "Download my data" (optional), "Delete my account and data" (required), Sign out.
- Settings: Dark mode (system/light/dark), Gentle mode (hides counts and trending), Reduce motion.
- Badges: "Founding member" if she is among the first 50 accounts (flag set by admin only).
Data: `chatProfiles/{uid}` { alias, avatarId, bio, interests[], lookingFor[], open (bool), createdAt, updatedAt }. Rules: owner can create/update; any signed-in woman member can READ only when open == true; nobody can delete from the app except the owner turning off or deleting the account. Validate lengths, allowed keys, interests from a fixed list.
Seed: a cooldown of 24 hours after account creation before "Open to chat" can be turned on.

## 3. Phase B: Connect hub (find people who relate)
- Header "Connect", sub line "Meet women who understand. You choose who to talk to."
- Filter chips: All, plus interests. Sort: "Most in common" (count of shared interests) then newest. Do NOT use post history for matching (it would break anonymity).
- Cards (not a feed of posts): avatar, alias, 3 interest chips (blush for ones in common), bio, "Looking for ...", button "Say hi".
- "Say hi" opens a bottom sheet: a short intro (max 140 chars, filtered, suggested starters like "Hi, I also find exams stressful. Want to chat?"). Sends a request.
- Limits: 5 new requests per day per person (rules), one open request per person pair, 24h account age.
- Requests inbox (top right icon on Connect): Accept / Decline. Decline is silent (sender just sees "Pending"). Requests expire after 7 days (check on read).
- Empty state with the cat picture: "No one here yet. Turn on Open to chat in Me so others can find you."
Data: `chatRequests/{fromUid_toUid}` { from, to, intro, status: 'pending'|'accepted'|'declined', createdAt }. Rules: only from can create (with the limits), only to can change status, both can read, no deletes.

## 4. Phase C: Private chat
- Chat list under Connect (segmented control: People / Chats). Each row: avatar, alias, last message preview, time. No unread numbers, just a bold line.
- Chat screen: Apple-like bubbles, mine black with white text, theirs light grey (dark mode inverted), rounded 20, soft spring on send, haptic. Top bar: avatar + alias, "..." menu: Mute, Report, Block, End chat. Composer: text only, 1000 chars max.
- Safety banner pinned on the first open: "Never share your real name, address or phone number. If you feel unsafe, block or report."
- Client filter + rules regex: block phone numbers, emails, URLs, @handles. Show a kind message when blocked ("For your safety, links and contact details are not allowed here.").
- Rate limit: 1 message per second, 30 per minute (rules via lastMessageAt on the chat doc).
- Messages are NOT end-to-end encrypted (Firestore). Say this honestly in the privacy centre.
Data: `chats/{chatId}` { members[uid,uid], createdAt, lastMessageAt, lastMessagePreview, endedBy? , muted maps } and `chats/{chatId}/messages/{id}` { from, text, createdAt }. Rules: only members read/write; create message only if chat active and neither blocked; no updates or deletes of messages (except ending the chat).
- `blocks/{uid}/blocked/{otherUid}`: a blocked person cannot send requests or messages; the blocked person cannot tell they are blocked (requests show "Pending").

## 5. Phase D: Safety and moderation
- Report a chat or person: reasons list; when she reports, the app copies the last 20 messages into `chatReports/{id}` (reporterId, chatId, snapshot[], reason, status, createdAt). Moderators read ONLY reported snapshots, never whole chats. Rules tests for this.
- 3 reports from different people against one profile auto-hides it from the hub (client-side filter + rule on `open`) until a moderator reviews.
- Moderator screen: add a "Chat reports" tab next to post reports.
- Safety page in the app: how Looma tries to keep Connect safe, honest limits (self-declared women only, project owner can see database, no encryption), where to get help.

## 6. Tests and checks
- Rules tests for every collection above (allowed and denied cases, two users, blocked users, rate limits, regex).
- Widget tests for the hub, the request sheet and the chat screen (empty states, blocked text).
- Manual: two accounts, request, accept, chat, block, report, turn off Open to chat, delete account.
- Performance: paginate the hub (20 cards), chat messages limit(50) with load-more.
- After Phase D: ask the user to run the rules through a careful review (use the strongest model for this) before real users join.

## 7. Report to the user in simple English after each phase
What changed, what to test, what is not done, anything risky.
