import 'package:cloud_functions/cloud_functions.dart';

/// Privileged account operations. These run in Cloud Functions, which check
/// the caller's identity and role on the server.
abstract interface class AccountRepository {
  /// Deletes the signed-in user's account. The caller should sign out after.
  Future<void> deleteMyAccount();

  /// Owner only: grants or removes the student-admin role.
  Future<void> setStudentAdmin({required String uid, required bool enabled});

  /// Staff only: lifts a suspension.
  Future<void> liftSuspension(String uid);
}

enum AccountFailure { notAllowed, notConfigured, offline, unknown }

class AccountException implements Exception {
  const AccountException(this.failure);
  final AccountFailure failure;

  @override
  String toString() => 'AccountException(${failure.name})';
}

class FunctionsAccountRepository implements AccountRepository {
  FunctionsAccountRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<void> _call(String name, [Map<String, Object?>? data]) async {
    try {
      await _functions.httpsCallable(name).call<Object?>(data);
    } on FirebaseFunctionsException catch (error) {
      throw AccountException(switch (error.code) {
        'permission-denied' || 'unauthenticated' => AccountFailure.notAllowed,
        'failed-precondition' => AccountFailure.notConfigured,
        'unavailable' || 'deadline-exceeded' => AccountFailure.offline,
        _ => AccountFailure.unknown,
      });
    }
  }

  @override
  Future<void> deleteMyAccount() => _call('deleteMyAccount');

  @override
  Future<void> setStudentAdmin({required String uid, required bool enabled}) =>
      _call('setUserRole', {
        'uid': uid,
        'role': enabled ? 'student-admin' : 'student',
      });

  @override
  Future<void> liftSuspension(String uid) =>
      _call('liftSuspension', {'uid': uid});
}

class UnconfiguredAccountRepository implements AccountRepository {
  const UnconfiguredAccountRepository();

  static const _refused = AccountException(AccountFailure.notConfigured);

  @override
  Future<void> deleteMyAccount() => Future.error(_refused);

  @override
  Future<void> setStudentAdmin({required String uid, required bool enabled}) =>
      Future.error(_refused);

  @override
  Future<void> liftSuspension(String uid) => Future.error(_refused);
}
