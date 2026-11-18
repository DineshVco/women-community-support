import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/post_repository.dart';
import 'firebase_options.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // One shared repository: every screen reads and writes through it.
        Provider<PostRepository>(create: (_) => PostRepository()),
      ],
      child: const HerCircleApp(),
    ),
  );
}

class HerCircleApp extends StatelessWidget {
  const HerCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HerCircle',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeProvider>().themeMode,
      home: const AuthGate(),
    );
  }
}
