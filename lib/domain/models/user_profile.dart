/// Public profile stored at `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.rulesVersion = 0,
  });

  final String uid;
  final String displayName;

  /// The community rules version this user accepted; 0 if none.
  final int rulesVersion;
}

/// Account standing, stored server-side at `accountRestrictions/{uid}`.
/// A missing document means [active].
enum AccountStatus {
  active,
  suspended,
  deleted;

  static AccountStatus fromValue(Object? value) => switch (value) {
    'suspended' => AccountStatus.suspended,
    'deleted' => AccountStatus.deleted,
    _ => AccountStatus.active,
  };
}
