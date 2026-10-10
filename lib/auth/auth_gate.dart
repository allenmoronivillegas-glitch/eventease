import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';
import '../home_page.dart';
import '../theme/app_theme.dart';
import 'auth_page.dart';
import 'onboarding_page.dart';

/// Decides what to show based on the Firebase Auth state.
/// Signed in with an incomplete profile -> onboarding
/// Signed in with a complete profile -> your existing HomePage
/// Signed out -> AuthPage (login / sign up)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final UserProfileService _profileService = UserProfileService();
  late final Stream<User?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return _AuthErrorScreen(
            message: 'Could not check your sign-in status. Please try again.',
            onRetry: () => setState(() {}),
          );
        }
        final user = snapshot.data;
        if (user == null) return const AuthPage();
        return _AuthenticatedUserGate(
          key: ValueKey(user.uid),
          user: user,
          profileService: _profileService,
        );
      },
    );
  }
}

class _AuthenticatedUserGate extends StatefulWidget {
  const _AuthenticatedUserGate({
    required this.user,
    required this.profileService,
    super.key,
  });

  final User user;
  final UserProfileService profileService;

  @override
  State<_AuthenticatedUserGate> createState() => _AuthenticatedUserGateState();
}

class _AuthenticatedUserGateState extends State<_AuthenticatedUserGate> {
  static const _profileCheckTimeout = Duration(seconds: 15);

  late Future<bool> _profileCheck;

  @override
  void initState() {
    super.initState();
    _profileCheck = _checkProfile();
  }

  Future<bool> _checkProfile() async {
    try {
      return await widget.profileService
          .hasCompletedOnboarding(widget.user.uid)
          .timeout(_profileCheckTimeout);
    } on TimeoutException {
      debugPrint(
        '[AuthGate] Profile check timed out '
        'after ${_profileCheckTimeout.inSeconds} seconds',
      );
      rethrow;
    }
  }

  void _retry() {
    setState(() => _profileCheck = _checkProfile());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _profileCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }
        if (snapshot.hasError) {
          return _AuthErrorScreen(
            message: _profileErrorMessage(snapshot.error),
            onRetry: _retry,
          );
        }
        if (snapshot.data != true) {
          return OnboardingPage(user: widget.user, onFinished: _retry);
        }
        return const HomePage();
      },
    );
  }
}

String _profileErrorMessage(Object? error) {
  if (error is TimeoutException) {
    return 'The profile check took too long. Check your connection and try again.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore denied access to your profile. Check your account permissions or contact support.';
      case 'unauthenticated':
      case 'user-mismatch':
        return 'Your sign-in changed or expired while loading your profile. Sign out and sign in again.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'Could not reach Firestore. Check your connection or try again when the service is available.';
      default:
        return 'Your profile could not be loaded (Firestore error: ${error.code}). Please try again.';
    }
  }
  return 'Your profile could not be loaded. Please try again.';
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 42,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
