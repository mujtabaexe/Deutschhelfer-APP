/// App-wide roles. Assigned only by trusted backend code through Firebase
/// Auth custom claims, never by the client.
enum UserRole {
  student,
  studentAdmin,
  owner;

  static UserRole fromClaim(Object? value) => switch (value) {
    'owner' => UserRole.owner,
    'student-admin' => UserRole.studentAdmin,
    _ => UserRole.student,
  };

  String get claimValue => switch (this) {
    UserRole.student => 'student',
    UserRole.studentAdmin => 'student-admin',
    UserRole.owner => 'owner',
  };

  bool get canModerate => this != UserRole.student;
}

/// The signed-in user as seen by the client.
///
/// [role] and [isPremium] come from the ID token and are for display only.
/// Firestore Rules check the same claims on the server.
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.displayName,
    this.role = UserRole.student,
    this.isPremium = false,
  });

  final String uid;
  final String email;
  final bool emailVerified;
  final String? displayName;
  final UserRole role;
  final bool isPremium;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.uid == uid &&
      other.email == email &&
      other.emailVerified == emailVerified &&
      other.displayName == displayName &&
      other.role == role &&
      other.isPremium == isPremium;

  @override
  int get hashCode =>
      Object.hash(uid, email, emailVerified, displayName, role, isPremium);
}
