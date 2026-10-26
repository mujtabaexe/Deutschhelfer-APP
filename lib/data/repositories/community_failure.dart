import 'package:cloud_firestore/cloud_firestore.dart';

/// Failures the community screens explain to the user.
enum CommunityFailure {
  /// The server refused. Usually rate limiting, a suspension, a block, or
  /// lost membership. The server does not say which, by design.
  notAllowed,
  offline,
  notFound,
  unknown,
}

class CommunityException implements Exception {
  const CommunityException(this.failure);

  final CommunityFailure failure;

  @override
  String toString() => 'CommunityException(${failure.name})';
}

/// Runs a Firestore call and converts its errors. Never includes message
/// text or document data in the exception.
Future<T> guardFirestore<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on FirebaseException catch (error) {
    throw CommunityException(switch (error.code) {
      'permission-denied' ||
      'failed-precondition' => CommunityFailure.notAllowed,
      'unavailable' || 'deadline-exceeded' => CommunityFailure.offline,
      'not-found' => CommunityFailure.notFound,
      _ => CommunityFailure.unknown,
    });
  }
}

DateTime? readTimestamp(Object? value) =>
    value is Timestamp ? value.toDate() : null;
