import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/security/app_lock.dart';
import 'core/security/secure_store.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/chat_repository.dart';
import 'data/content_library.dart';
import 'data/microcopy.dart';
import 'data/help_lines.dart';
import 'data/journal.dart';
import 'data/local_private_data.dart';
import 'data/mood.dart';
import 'data/repositories/post_repository.dart';
import 'data/safety_plan.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_settings.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/auth_gate.dart';
import 'presentation/widgets/app_lock_gate.dart';
import 'presentation/widgets/web_start.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The bundled heading font's licence (SIL OFL) must ship with the app.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Newsreader font'], text);
  });
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/google_fonts/Caveat-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Caveat font'], text);
  });

  if (kIsWeb) {
    // Web: draw at once (the page's own loading screen hands over to this
    // one), and get everything ready behind it.
    runApp(WebStart(start: LoomaServices.start));
    return;
  }
  // Phones: the native splash stays up until everything is ready.
  runApp(LoomaRoot(services: await LoomaServices.start()));
}

/// Everything the app needs before its first real screen.
class LoomaServices {
  LoomaServices._({
    required this.theme,
    required this.settings,
    required this.appLock,
    required this.safetyPlan,
    required this.moodLog,
    required this.journal,
    required this.guideBookmarks,
    required this.content,
  });

  final ThemeProvider theme;
  final AppSettings settings;
  final AppLock appLock;
  final SafetyPlanStore safetyPlan;
  final MoodStore moodLog;
  final JournalStore journal;
  final GuideBookmarks guideBookmarks;
  final ContentLibrary content;

  /// Starts Firebase and loads the saved settings, the App lock and the
  /// bundled content, all at the same time.
  static Future<LoomaServices> start() async {
    // Kept only on this phone, in secure storage: App lock and safety plan.
    final secureStore = DeviceSecureStore();
    final appLock = AppLock(secureStore);

    final firebase = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      if (kIsWeb) {
        // Safari can hang for a long time on Firestore's default streaming
        // connection; long polling is slower in theory but always works.
        FirebaseFirestore.instance.settings = const Settings(
          webExperimentalForceLongPolling: true,
        );
      }
    });
    // Saved on the phone: dark mode, Gentle mode, Reduce motion.
    final theme = ThemeProvider.load();
    final settings = AppSettings.load();
    final lock = appLock.load();
    // Help lines, guides and directory: bundled with the app (offline).
    final content = ContentLibrary.load();
    final microcopy = Microcopy.load(); // warm lines for empty lists

    await Future.wait<void>([
      firebase,
      theme,
      settings,
      lock,
      content,
      microcopy,
    ]);

    return LoomaServices._(
      theme: await theme,
      settings: await settings,
      appLock: appLock,
      safetyPlan: SafetyPlanStore(secureStore),
      moodLog: MoodStore(secureStore),
      journal: JournalStore(secureStore),
      guideBookmarks: GuideBookmarks(secureStore),
      content: await content,
    );
  }
}

/// The app with everything it reads through Provider.
class LoomaRoot extends StatelessWidget {
  const LoomaRoot({super.key, required this.services});

  final LoomaServices services;

  @override
  Widget build(BuildContext context) {
    final s = services;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: s.theme),
        ChangeNotifierProvider.value(value: s.settings),
        // Shared repositories: every screen reads and writes through them.
        Provider<PostRepository>(create: (_) => PostRepository()),
        Provider<ChatRepository>(create: (_) => ChatRepository()),
        Provider<SafetyPlanStore>.value(value: s.safetyPlan),
        Provider<MoodStore>.value(value: s.moodLog),
        Provider<JournalStore>.value(value: s.journal),
        Provider<LocalPrivateData>.value(
          value: LocalPrivateData(
            moodLog: s.moodLog,
            journal: s.journal,
            safetyPlan: s.safetyPlan,
            guideBookmarks: s.guideBookmarks,
          ),
        ),
        Provider<GuideBookmarks>.value(value: s.guideBookmarks),
      ],
      child: ContentScope(
        library: s.content,
        child: LoomaApp(appLock: s.appLock),
      ),
    );
  }
}

class LoomaApp extends StatelessWidget {
  const LoomaApp({super.key, required this.appLock});

  final AppLock appLock;

  /// Lets "Forgot PIN" (shown above every screen) go back to the start.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  /// "Forgot PIN": sign out, delete the safety plan and the journal (only
  /// the PIN protected them), then remove the lock. Her data on the server
  /// stays.
  Future<void> _forgotPin(BuildContext context) async {
    final posts = context.read<PostRepository>();
    final plan = context.read<SafetyPlanStore>();
    final journal = context.read<JournalStore>();
    try {
      await plan.clear();
    } catch (_) {}
    try {
      await journal.clear();
    } catch (_) {}
    try {
      await posts.signOut();
    } catch (_) {}
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    await appLock.forgetPin();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Looma',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeProvider>().themeMode,
      scrollBehavior: const _BouncingScrollBehavior(),
      // Smoothness check: flutter run --profile --dart-define=PERF_OVERLAY=true
      showPerformanceOverlay: const bool.fromEnvironment('PERF_OVERLAY'),
      navigatorKey: navigatorKey,
      home: const AuthGate(),
      // Reduce motion (Me tab) switches animations off everywhere, through
      // the same flag as the phone's own setting (AppMotion reads it).
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return AppSettingsScope(
          settings: settings,
          child: MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || settings.reduceMotion,
            ),
            // App lock sits above every screen.
            child: AppLockGate(
              lock: appLock,
              onForgot: () => _forgotPin(context),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// iOS-style rubber-band scrolling on every platform.
class _BouncingScrollBehavior extends MaterialScrollBehavior {
  const _BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  // No Android glow/stretch: the bounce already shows the edge.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
