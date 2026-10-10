import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential?> signInWithGoogleOnWindows() {
  throw UnsupportedError(
    'Windows Google sign-in requires the Windows OAuth implementation.',
  );
}
