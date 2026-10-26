import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/user_profile.dart';
import '../../domain/validation/input_validators.dart';

/// Reads and writes the public profile and the server-owned account status.
abstract interface class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);

  /// Creates `users/{uid}` if it does not exist. Safe to call repeatedly.
  Future<void> ensureProfile({required String uid, String? displayName});

  /// Sets the display name, creating the profile if needed. Pass
  /// [acceptedRulesVersion] when the user has just accepted the community
  /// rules, such as at sign-up.
  Future<void> saveDisplayName({
    required String uid,
    required String displayName,
    int? acceptedRulesVersion,
  });

  /// Records that the user accepted [version] of the community rules,
  /// creating the profile if needed.
  Future<void> acceptRules({required String uid, required int version});

  /// Emits [AccountStatus.active] when no restriction document exists.
  Stream<AccountStatus> watchAccountStatus(String uid);
}

/// Used when no Firebase project is configured. Nobody can sign in in that
/// mode, so these streams only need to be well-behaved.
class UnconfiguredProfileRepository implements ProfileRepository {
  const UnconfiguredProfileRepository();

  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(null);

  @override
  Future<void> ensureProfile({
    required String uid,
    String? displayName,
  }) async {}

  @override
  Future<void> saveDisplayName({
    required String uid,
    required String displayName,
    int? acceptedRulesVersion,
  }) async {}

  @override
  Future<void> acceptRules({required String uid, required int version}) async {}

  @override
  Stream<AccountStatus> watchAccountStatus(String uid) =>
      Stream.value(AccountStatus.active);
}

/// Display name used when none is available. Never derived from the email,
/// which would leak part of it to other users.
const fallbackDisplayName = 'Student';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _profile(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final name = data['displayName'];
      final rules = data['rulesVersion'];
      return UserProfile(
        uid: uid,
        displayName: name is String ? name : fallbackDisplayName,
        rulesVersion: rules is int ? rules : 0,
      );
    });
  }

  @override
  Future<void> ensureProfile({required String uid, String? displayName}) {
    final name = _safeName(displayName);
    final ref = _profile(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      tx.set(ref, {
        'displayName': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> saveDisplayName({
    required String uid,
    required String displayName,
    int? acceptedRulesVersion,
  }) => _write(
    uid: uid,
    name: _safeName(displayName),
    rulesVersion: acceptedRulesVersion,
  );

  @override
  Future<void> acceptRules({required String uid, required int version}) =>
      _write(uid: uid, rulesVersion: version);

  /// One transaction for both fields, so sign-up never races the session
  /// controller's fallback profile into losing the acceptance.
  Future<void> _write({required String uid, String? name, int? rulesVersion}) {
    final ref = _profile(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.data()?['rulesVersion'];
      final accepts =
          rulesVersion != null && rulesVersion > (current is int ? current : 0);
      final rules = {
        if (accepts) ...{
          'rulesVersion': rulesVersion,
          'rulesAcceptedAt': FieldValue.serverTimestamp(),
        },
      };
      if (snap.exists) {
        if (name == null && rules.isEmpty) return;
        tx.update(ref, {
          'displayName': ?name,
          ...rules,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'displayName': name ?? fallbackDisplayName,
          ...rules,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  @override
  Stream<AccountStatus> watchAccountStatus(String uid) {
    return _db
        .collection('accountRestrictions')
        .doc(uid)
        .snapshots()
        .map((snap) => AccountStatus.fromValue(snap.data()?['status']));
  }

  static String _safeName(String? raw) {
    final name = InputValidators.normalizeDisplayName(raw ?? '');
    return InputValidators.displayName(name) == null
        ? name
        : fallbackDisplayName;
  }
}
