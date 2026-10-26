import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/community.dart';
import 'community_failure.dart';

enum ReportOutcome { submitted, alreadyReported }

/// Reports from users, and their resolution and account suspensions by
/// staff.
abstract interface class ReportRepository {
  Future<ReportOutcome> submit({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  });

  Future<List<Report>> openReports();

  Future<void> resolve({
    required String reportId,
    required String staffId,
    required bool actioned,
    required String resolution,
  });

  Future<void> suspend({
    required String userId,
    required String staffId,
    required String reason,
  });

  /// Suspended accounts, most recent first. Staff only.
  Future<List<Suspension>> suspendedAccounts();
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  /// Matches the deterministic id the rules require, so one user can report
  /// a target only once.
  static String reportId(String reporterId, ReportTarget target) =>
      '${reporterId}_${target.type.name}_${target.targetId}';

  @override
  Future<ReportOutcome> submit({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  }) async {
    final ref = _reports.doc(reportId(reporterId, target));
    try {
      await ref.set({
        'reporterId': reporterId,
        'targetType': target.type.name,
        'targetId': target.targetId,
        'targetUserId': target.targetUserId,
        'groupId': target.groupId,
        'conversationId': target.conversationId,
        'reason': reason.name,
        'details': details.trim(),
        'excerpt': target.excerpt,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
      return ReportOutcome.submitted;
    } on FirebaseException catch (error) {
      // A second report of the same target is an update, which the rules
      // deny. Treat it as already reported rather than an error.
      if (error.code == 'permission-denied') {
        return ReportOutcome.alreadyReported;
      }
      throw CommunityException(
        error.code == 'unavailable'
            ? CommunityFailure.offline
            : CommunityFailure.unknown,
      );
    }
  }

  static Report _report(QueryDocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data();
    return Report(
      id: s.id,
      reporterId: d['reporterId'] as String? ?? '',
      targetType: ReportTargetType.values.firstWhere(
        (t) => t.name == d['targetType'],
        orElse: () => ReportTargetType.user,
      ),
      targetId: d['targetId'] as String? ?? '',
      targetUserId: d['targetUserId'] as String? ?? '',
      reason: ReportReason.values.firstWhere(
        (r) => r.name == d['reason'],
        orElse: () => ReportReason.other,
      ),
      details: d['details'] as String? ?? '',
      excerpt: d['excerpt'] as String? ?? '',
      status: ReportStatus.values.firstWhere(
        (r) => r.name == d['status'],
        orElse: () => ReportStatus.open,
      ),
      groupId: d['groupId'] as String?,
      conversationId: d['conversationId'] as String?,
      createdAt: readTimestamp(d['createdAt']),
    );
  }

  @override
  Future<List<Report>> openReports() => guardFirestore(() async {
    final snap = await _reports
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map(_report).toList();
  });

  @override
  Future<void> resolve({
    required String reportId,
    required String staffId,
    required bool actioned,
    required String resolution,
  }) => guardFirestore(
    () => _reports.doc(reportId).update({
      'status': actioned ? 'actioned' : 'dismissed',
      'resolvedBy': staffId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolution': resolution,
    }),
  );

  @override
  Future<void> suspend({
    required String userId,
    required String staffId,
    required String reason,
  }) => guardFirestore(
    () => _db.collection('accountRestrictions').doc(userId).set({
      'status': 'suspended',
      'reason': reason,
      'updatedBy': staffId,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<List<Suspension>> suspendedAccounts() => guardFirestore(() async {
    final snap = await _db
        .collection('accountRestrictions')
        .where('status', isEqualTo: 'suspended')
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .get();
    final names = await Future.wait([
      for (final doc in snap.docs)
        _db
            .collection('users')
            .doc(doc.id)
            .get()
            .then(
              (user) => user.data()?['displayName'] as String? ?? '',
              onError: (Object _) => '',
            ),
    ]);
    return [
      for (final (i, doc) in snap.docs.indexed)
        Suspension(
          uid: doc.id,
          displayName: names[i],
          reason: doc.data()['reason'] as String? ?? '',
          updatedAt: readTimestamp(doc.data()['updatedAt']),
        ),
    ];
  });
}
