# Onboarding: girl on page 1, Looma cat on pages 2 to 4

New files (copy into the project, same paths; add them to pubspec.yaml assets):
- assets/images/looma_cat_share.png    cat with a speech bubble and heart  -> page 2 "Share anonymously"
- assets/images/looma_cat_browse.png   cat sitting on a stack of books     -> page 3 "Browse by category"
- assets/images/looma_cat_safe.png     cat holding a shield with a tick    -> page 4 "Stay safe and protected"
- assets/images/looma_cat_heart.png    cat with a floating heart           -> spare: empty states, success screens, steps
- source_svg/ has the same drawings as SVG (keep for later edits, do not ship in the app)
These are original Looma drawings. Do NOT use or copy artwork from any other app.

## Task for the Claude in VS Code
1. Onboarding PageView, 4 pages:
   - Page 1: unchanged (girl with cat, "Welcome to Looma", the 4 feature icons, buttons).
   - Page 2: looma_cat_share.png, title "Share anonymously", line "Speak freely in a safe and respectful space. You get a random alias, never your name."
   - Page 3: looma_cat_browse.png, title "Browse by category", line "Find stories on health, school, work and safety, and see you are not the only one."
   - Page 4: looma_cat_safe.png, title "Stay safe and protected", line "Report anything harmful. Moderators keep Looma kind and respectful."
   Pages 2 to 4: picture about 260 high, centred, title in Newsreader 32, line in grey 16, same bottom buttons and "Skip" at the top right. Active dot is a longer pill. Page 4 shows "Get Started" as the main button.
2. Make a small reusable widget `FloatingIllustration(asset, height)` for pages 2 to 4: gentle float (6px, 3.5s, easeInOutSine, loop), and a fade + rise 12px when the page becomes visible. Stop when MediaQuery.disableAnimations is true. (Page 1 keeps LoomaCharacter with its steam and heart.)
3. Page change: the picture cross-fades and slides slightly with the swipe (use the PageView page offset for a subtle parallax, max 24px). Light haptic selectionClick on page change.
4. Use looma_cat_heart.png for empty states (no posts yet, no search results) and the "thank you for sharing" screen.
5. Dark mode: put cat pictures on the same white rounded card used for the girl.
6. Add a small widget test (4 pages swipe, Skip works, no animation when disableAnimations is true). Run flutter analyze and flutter test. Report in simple English.
