import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/post_repository.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_settings.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/auth_gate.dart';

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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Saved on the phone: dark mode, Gentle mode, Reduce motion.
  final theme = await ThemeProvider.load();
  final settings = await AppSettings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: settings),
        // Shared repositories: every screen reads and writes through them.
        Provider<PostRepository>(create: (_) => PostRepository()),
        Provider<ChatRepository>(create: (_) => ChatRepository()),
      ],
      child: const LoomaApp(),
    ),
  );
}

class LoomaApp extends StatelessWidget {
  const LoomaApp({super.key});

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
            child: child!,
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
