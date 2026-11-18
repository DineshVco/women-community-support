# Looma – design and change spec (for the VS Code Claude)

Read this whole file first. Then make the changes in order. Run `flutter analyze` and `flutter test` after each step.
Reference pictures: the Looma onboarding picture the user sent (black and white, girl with mug and cat). Match it closely.

## 0. Rules
- Rename the app to **Looma** everywhere the user can see it (app title, Android label, iOS display name, web title, manifest, texts).
- Do NOT change: Android `applicationId`, iOS bundle id, Dart package name, Firebase project id (`women-community-support`).
- Looma is **women only**. **Remove guest / anonymous sign-in completely** (button, code, and any Firestore rule that allows it). Real accounts only: email + password, and Google.
  - "Anonymous" in the app means posting under a random alias. It does NOT mean guest login. Keep aliases.
- Keep all existing safety features (quick exit, helplines, reports, auto-hide at 3 flags, moderators).
- Style: calm, plain, Apple-like. No gradients, no purple, no shadows. Only black, white, greys, and one small accent.

## 1. Colours (replace the palette)
Light:
- background `#FFFFFF`, surface `#FFFFFF`, soft fill `#F2F2F2`
- text `#111111`, secondary text `#6B6B6B`, border `#DDDDDD`
- primary (buttons, selected) `#111111`, on-primary `#FFFFFF`
- accent (category labels only) `#C8553D`
- danger `#B3261E`
Dark (invert):
- background `#0E0E0E`, soft fill `#1F1E1C`, text `#F5F2EC`, secondary `#9A9690`, border `#3A3835`
- primary `#F5F2EC`, on-primary `#111111`
- In dark mode, put the character picture on a white rounded card (the picture has dark lines).
Danger colour stays for the Get help screen and Report.

## 2. Fonts
- Headings and the "Looma" wordmark: **Newsreader** (regular). Add it with `google_fonts` or bundle it in `assets/fonts/`.
- Body and buttons: system font (San Francisco on iPhone, Roboto on Android). Do not add Inter in the app.
- Sizes: wordmark 56 (onboarding) / 26 (app bar); screen title 32 to 34, letter spacing -0.5; body 16, line height 1.45; small text 12 to 13; button text 16 to 17, weight 500.

## 3. Shape and spacing
- Screen side padding 24. Spacing scale 4, 8, 12, 16, 24, 32.
- Buttons: full width, height 56 (primary) / 52 (outline), fully round (radius 28).
- Primary button = black fill, white text, text then arrow "→". Outline button = 1.5 px black border, black text, no fill.
- Cards and fields: radius 16, 1 px border `#DDDDDD`, white fill. Selected option: 1.8 px black border and a filled black circle with a white tick on the right.
- Category chips: pill, radius 18, selected = black fill white text, not selected = 1 px border.
- No elevation anywhere.

## 4. Assets
- Put `assets/images/looma_character.png` (included, transparent background) in the project and add it to `pubspec.yaml` under `assets:`.
- The four feature icons are normal Flutter icons (outlined style, black): chat bubble, open book, group of people, shield. Each sits in a 52 px circle with fill `#F2F2F2`.

## 5. Screen order (new flow)
1. Onboarding (first launch only)
2. Sign in / Sign up
3. Step 1: Women only confirmation
4. Step 2: Birthday (age check)
5. Home (the existing app shell: Discussions, Get help, Me)
Show steps 3 and 4 only once per account. Save the result in `users/{uid}`.

### 5.1 Onboarding (match the reference picture)
Top to bottom, centred:
- "Looma" in Newsreader 56 with a small 4-point star at the top right of the word.
- "SUPPORT · SHARE · EMPOWER" small caps, letter spacing 2.4, size 10.5.
- Character picture, about 250 wide.
- "Welcome to Looma" Newsreader 34, with a hand-drawn underline (a slightly curved black line, 2 px) under it.
- "A women community support app" grey, 15.
- Row of 4 features separated by thin vertical lines: Share Anonymously ("Speak freely in a safe and respectful space"), Browse by Category ("Explore discussions on topics that matter to you"), Be Part of a Community ("Connect with women who understand"), Stay Safe & Protected ("Report harmful content, moderators keep the community respectful"). Title in Newsreader 12 bold, description grey 10.
- 4 page dots (first one black and longer).
- Buttons: "Get Started →" (black) goes to Sign up. "I already have an account" (outline) goes to Sign in.
- Animations: character fades and rises 12 px (400 ms, easeOutCubic); text fades in after it, one after another (60 ms apart).

### 5.2 Sign up / Sign in
- Title "Create your space" (sign up) or "Welcome back" (sign in), Newsreader 32.
- Sub text: "We only use your email to sign you in. It is never shown to anyone."
- Fields: Email, Password (with show/hide eye). Sign in also has "Forgot password?".
- Buttons: "Continue" (black), "or", "Continue with Google" (outline).
- **No guest button.**
- Small text at the bottom: "By continuing you agree to keep Looma kind and respectful. Looma is a space for women."
- Link at the bottom to switch between sign in and sign up.

### 5.3 Step 1: Women only
- Back arrow + thin progress bar (1/3 filled). Character picture (about 190 high).
- Title: "Looma is a space for women"
- Text: "Please confirm to continue. Your answer is private and is never shown to anyone."
- Two option cards: **"I am a woman"** (pre-selected) and **"I am not a woman"**.
- "Continue →".
- If "I am not a woman" is chosen: show a calm message "Looma is only for women, so we can't set up an account for you. Thank you for understanding." with one button to go back. Do not create the profile, sign the person out.
- Save `isWoman: true` on `users/{uid}` only when confirmed.
- Note for Najwa: this is a self-confirmation, not proof. Say so honestly in the report.

### 5.4 Step 2: Birthday
- Back arrow + progress bar (2/3). Character picture.
- Title: "When's your birthday?"
- Text: "We only use this to check you are old enough to join. It is kept private."
- Field with a calendar icon, opens the platform date picker (Cupertino style on iPhone). Under it show "25 years old" (calculated).
- Small line with a lock: "Your data is private and secure."
- "Continue →". Block under-age users with a kind message (minimum age: 18, make it one constant `minimumAge` so Najwa can change it).
- Store only `birthYear` (not the full date) in `users/{uid}`, to keep less personal data. Never show it to anyone.
- Do not store anything about calories or health. (An older reference screen mentioned them. Ignore that text.)

### 5.5 Home / Feed
- Header: "Looma" (Newsreader 26) on the left, "Quick exit" small pill on the right.
- Category chips row (All, then the categories).
- Posts are plain rows separated by 1 px lines (no cards): category label in accent colour (uppercase, 11, letter spacing 0.8), title in Newsreader 22, 2 lines of preview in grey, then a footer: alias · time on the left, "N me too" and "N replies" on the right.
- Floating black pill "+ Write a post".
- Bottom bar: Discuss, Get help, Me. Selected = black, others grey.

### 5.6 Post detail
- Back, "…" menu. Category label, title (Newsreader 28), alias · time, body 16.
- Pills: "Me too · N" (black when pressed) and "Report" (outline).
- Replies list with thin separators. Original poster gets a small black "Original poster" tag.
- Composer pinned at the bottom: rounded field "Reply as <alias>" and a black round send button.

## 6. Motion and feel (Apple-like)
- Page transitions: `CupertinoPageTransitionsBuilder` on all platforms. `BouncingScrollPhysics`.
- Buttons: scale to 0.97 on press (100 ms) and a light haptic.
- "Me too": small bounce + `HapticFeedback.selectionClick()`.
- List items fade and slide in 8 px, 40 ms apart, only on first load.
- Use adaptive dialogs and sheets (Cupertino on iPhone).
- Respect "reduce motion": turn animations off when `MediaQuery.disableAnimations` is true.

## 7. Firebase and rules
- Remove `signInAnonymously` from the code. Delete the guest button and any "guest" text.
- In `firestore.rules`, make sure every write needs `request.auth != null` and does NOT rely on anonymous accounts. Optionally also require `get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isWoman == true` for creating posts and comments (one `isWomanMember()` function). Test it.
- Tell the user to turn **Anonymous** sign-in OFF in Firebase Console (Authentication → Sign-in method) after this works, and then deploy: `firebase deploy --only firestore:rules`.
- Sign-in methods needed: Email/Password and Google. For Google on Android, the SHA-1 key must be added in Firebase project settings (explain this to the user in simple steps).
- Existing guest accounts and test data: tell the user how to delete them in the console.

## 8. Seed content (for the booth)
Add 12 short starter posts and a few replies, in natural Malaysian English, across the categories (work, family, health, money, safety, study). Use random aliases. Do not use real names. Put them in a script `tool/seed.dart` or a documented console import. Mark them clearly in the code as demo content.

## 9. Done checklist
- [ ] Name is Looma everywhere users can see it
- [ ] No guest button, no anonymous sign-in in code
- [ ] Palette and fonts replaced; dark mode works
- [ ] Onboarding matches the reference picture
- [ ] Sign up, sign in, women-only step, birthday step work and save to `users/{uid}`
- [ ] Feed and post detail restyled, no cards or shadows
- [ ] Animations and haptics added, reduce-motion respected
- [ ] `flutter analyze` clean, `flutter test` passes, tests updated for the removed guest flow
- [ ] Rules updated and deployed
- [ ] Short report to the user in simple English: what changed, what they must do by hand (Firebase console, SHA-1, helpline numbers check)
