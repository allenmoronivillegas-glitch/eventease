import 'package:firebase_auth/firebase_auth.dart';

String firestoreErrorMessage(Object error, String action) {
  if (error is FirebaseAuthException && error.code == 'unauthenticated') {
    return 'Could not $action: sign in again and retry.';
  }
  if (error is FirebaseException &&
      (error.code == 'permission-denied' || error.code == 'unauthorized')) {
    return 'Could not $action: Firestore denied access. Check that your '
        'account role and record ownership are correct, and that the deployed '
        'Firestore rules match this app.';
  }
  if (error is FirebaseException) {
    return 'Could not $action (Firebase error: ${error.code}).';
  }
  return 'Could not $action: $error';
}
