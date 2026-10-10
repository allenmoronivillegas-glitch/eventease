import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<bool> hasCompletedOnboarding(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data()?['onboardingCompleted'] == true;
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
    final userRef = _firestore.collection('users').doc(uid);

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
  }
}
