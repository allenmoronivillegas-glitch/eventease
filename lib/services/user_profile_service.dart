import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    _requireMatchingAuthenticatedUser(uid, 'watchProfile');
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

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

  Future<void> saveAppearancePreferences({
    required String uid,
    required String themeMode,
    required String accentColor,
  }) async {
    _requireMatchingAuthenticatedUser(uid, 'saveAppearancePreferences');
    const allowedModes = {'system', 'light', 'dark'};
    const allowedAccents = {
      'indigo',
      'blue',
      'teal',
      'green',
      'pink',
      'orange',
    };
    if (!allowedModes.contains(themeMode) ||
        !allowedAccents.contains(accentColor)) {
      throw ArgumentError('The appearance preference is not supported.');
    }
    await _firestore.collection('users').doc(uid).set({
      'themeMode': themeMode,
      'accentColor': accentColor,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDisplayName({
    required String uid,
    required String displayName,
  }) async {
    _requireMatchingAuthenticatedUser(uid, 'saveDisplayName');
    final name = displayName.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Display names must contain 1 to 100 characters.');
    }
    final user = _auth.currentUser!;
    await user.updateDisplayName(name);
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) async {
    _requireMatchingAuthenticatedUser(uid, 'uploadProfilePhoto');
    const maxBytes = 5 * 1024 * 1024;
    const supportedTypes = {'image/jpeg', 'image/png', 'image/webp'};
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('Choose an image no larger than 5 MB.');
    }
    if (!supportedTypes.contains(contentType) ||
        !_hasValidImageSignature(bytes, contentType)) {
      throw ArgumentError('Choose a valid PNG, JPEG, or WebP image.');
    }

    final reference = _storage
        .ref()
        .child('profile_photos')
        .child(uid)
        .child('profile_photo');
    final task = reference.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    await for (final snapshot in task.snapshotEvents) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    }
    final photoUrl = await reference.getDownloadURL();
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'photoURL': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auth.currentUser!.updatePhotoURL(photoUrl);
    await _auth.currentUser!.reload();
    return photoUrl;
  }

  bool _hasValidImageSignature(Uint8List bytes, String contentType) {
    bool matches(List<int> signature) {
      if (bytes.length < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      return true;
    }

    return switch (contentType) {
      'image/png' => matches([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      'image/jpeg' => matches([0xFF, 0xD8, 0xFF]),
      'image/webp' =>
        bytes.length >= 12 &&
            matches([0x52, 0x49, 0x46, 0x46]) &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50,
      _ => false,
    };
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
