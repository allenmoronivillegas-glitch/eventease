import 'package:eventease/auth/auth_page.dart';
import 'package:eventease/home_page.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

void main() async {

  // Initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EventEaseApp());
}

class EventEaseApp extends StatelessWidget {
  const EventEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventEase - Event Management Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthPage(),
    );
  }
} 