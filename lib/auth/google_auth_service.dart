import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import 'windows_google_sign_in_stub.dart'
    if (dart.library.io) 'windows_google_sign_in_io.dart'
    as windows_sign_in;

class GoogleAuthService {
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  static Future<UserCredential?> signIn() async {
    if (kIsWeb) {
      try {
        return await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return null;
        }
        rethrow;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return windows_sign_in.signInWithGoogleOnWindows();
    }

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(
            code: 'missing-google-id-token',
            message: 'Google did not return an ID token. Check the OAuth client configuration.',
          );
        }

        return await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return null;
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message: e.description?.trim().isNotEmpty == true
              ? e.description
              : 'Could not complete Google sign-in. Please try again.',
        );
      }
    }

    throw UnsupportedError('Google sign-in is not available on this platform.');
  }
}
