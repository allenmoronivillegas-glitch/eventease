import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

import 'package:eventease/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Google Sign-In on supported native platforms.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await GoogleSignIn.instance.initialize();
  }

  final themeController = ThemeController();
  await themeController.initialize();

  runApp(EventEaseApp(themeController: themeController));
}

class EventEaseApp extends StatelessWidget {
  const EventEaseApp({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        title: 'EventEase - Event Management Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode,
        builder: (context, child) =>
            ThemeControllerScope(controller: themeController, child: child!),
        home: const SplashScreen(),
      ),
    );
  }
}
