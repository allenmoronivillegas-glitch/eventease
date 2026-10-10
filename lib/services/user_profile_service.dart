import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<bool> hasCompletedOnboarding(String uid) async {
    _requireMatchingAuthenticatedUser(uid, 'hasCompletedOnboarding');

    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      final completed = snapshot.data()?['onboardingCompleted'] == true;
      debugPrint(
        '[UserProfileService] hasCompletedOnboarding: '
        'documentExists=${snapshot.exists}, onboardingCompleted=$completed',
      );
      return completed;
    } on FirebaseException catch (error) {
      debugPrint(
        '[UserProfileService] hasCompletedOnboarding failed '
        '(code=${error.code})',
      );
      rethrow;
    }
  }

  Future<void> saveOnboardingProfile({
    required String uid,
    required String displayName,
    required String? email,
    required String role,
    required String? phone,
    required String? city,
    required String? organizationName,
    required String? organizationType,
    required List<String> eventCategories,
    required String? expectedEventSize,
    required String? invitationCode,
    required Map<String, bool>? notificationPreferences,
  }) async {
    _requireMatchingAuthenticatedUser(uid, 'saveOnboardingProfile');
    final userRef = _firestore.collection('users').doc(uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(userRef);
        final profile = <String, dynamic>{
          'uid': uid,
          'displayName': displayName,
          'email': email,
          'phone': phone,
          'city': city,
          'role': role,
          'organizationName': organizationName,
          'organizationType': organizationType,
          'eventCategories': eventCategories,
          'expectedEventSize': expectedEventSize,
          'invitationCode': invitationCode,
          'notificationPreferences': notificationPreferences,
          'onboardingCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (existing.data()?['createdAt'] == null) {
          profile['createdAt'] = FieldValue.serverTimestamp();
        }

        transaction.set(userRef, profile, SetOptions(merge: true));
      });
      debugPrint('[UserProfileService] saveOnboardingProfile completed');
    } on FirebaseException catch (error) {
      debugPrint(
        '[UserProfileService] saveOnboardingProfile failed '
        '(code=${error.code})',
      );
      rethrow;
    }
  }

  void _requireMatchingAuthenticatedUser(String uid, String operation) {
    final matches = _auth.currentUser?.uid == uid;
    debugPrint(
      '[UserProfileService] $operation: '
      'authenticatedUidMatchesDocumentId=$matches',
    );
    if (!matches) {
      debugPrint('[UserProfileService] $operation failed (code=user-mismatch)');
      throw FirebaseAuthException(
        code: 'user-mismatch',
        message: 'The authenticated user does not match the requested profile.',
      );
    }
  }
}
