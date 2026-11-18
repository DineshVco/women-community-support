# Looma polish: make it alive and more feminine

Files in this zip (copy into the project, keep the same paths):
- assets/images/looma_character.png   (REPLACES the old one: girl + cat only)
- assets/images/looma_heart.png       (new, small heart layer)
- assets/images/looma_sparks.png      (new, 3 spark lines layer)
- lib/presentation/widgets/looma_character.dart  (animated widget, starting point)
All three PNGs have the same canvas size, so they line up when stacked. Add the two new ones to pubspec.yaml assets.

## Do this, in order. Run `flutter analyze` and `flutter test` after each step.
1. Add the files. Review looma_character.dart, fix anything that does not compile (it was written without running Flutter), and add a small widget test (it builds, and does not animate when disableAnimations is true).
2. Use `LoomaCharacter` instead of any plain Image of the girl on: onboarding, sign in, sign up, women-only step, birthday step, and empty states. Remove the old static picture usage. Check the dark-mode white card still works.
3. Entrance animation on each of those screens: the character fades in and rises 12px (450ms, easeOutCubic), then the title, text and buttons fade in one after another (60ms apart).
4. Make onboarding a swipeable PageView with 4 pages. Page 1 = the welcome screen as designed. Pages 2, 3 and 4 each show LoomaCharacter (smaller) plus ONE of the feature ideas as a big title and one line: "Share anonymously", "Browse by category", "Be part of a community", "Stay safe and protected". Dots animate (active dot is a longer pill). "Get Started" and "I already have an account" stay at the bottom on every page. Add "Skip" at the top right on pages 2 to 4.
5. Buttons: press scale 0.97 (100ms) and a light haptic. On sign-in success, change the button to a tick for 400ms before navigating.
6. Soft feminine touch, still black and white with ONE accent, blush #E9B8B3:
   - background #FFFBF8 in light mode (dark mode stays #0E0E0E), borders warm grey #E8E2DE
   - blush used ONLY for: a soft glow circle behind the character (blurred, 10% opacity), selected option cards (a faint blush fill), the active dot, the "Me too" pressed state, and the small star next to the wordmark
   - corner radius: cards 20, fields 18, chips full round
   - add google_fonts and use "Caveat" ONLY for: the line "a safer, brighter tomorrow" on onboarding, and the greeting on Home
7. Home: greeting by time of day in Caveat ("Good morning", "Good afternoon", "Good evening", and after 22:00 "Take a breath, it is late"), and a small line under it: "You are not alone here."
8. After her very first post: a small soft burst of 6 to 8 blush hearts rising and fading (800ms) and a haptic. Only once per account (save a flag in SharedPreferences, not in Firestore).
9. Respect MediaQuery.disableAnimations everywhere. Keep it smooth (check with the Flutter performance overlay on the emulator). No heavy new packages.
10. Finish with a short report in simple English: what changed, anything that looks wrong on the emulator, and what to check on a real phone.
