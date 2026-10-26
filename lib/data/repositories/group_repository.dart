import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/community.dart';
import '../../domain/validation/link_detector.dart';
import 'community_failure.dart';

/// Groups, membership and group chat.
///
/// Cost notes: the group list is a one-off read, not a listener. Only the
/// open chat has listeners, and only for the newest page.
abstract interface class GroupRepository {
  Future<List<Group>> listGroups();
  Future<Group?> getGroup(String groupId);

  /// Owner only (enforced by the rules). Returns the new group's id.
  Future<String> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required String category,
  });

  /// Ids and roles of the groups the user belongs to.
  Future<Map<String, MemberRole>> myMemberships(String uid);

  /// The user's role in one group, or null when not a member. One read.
  Future<MemberRole?> myRole(String groupId, String uid);

  Future<void> join({
    required String groupId,
    required String uid,
    required String displayName,
  });
  Future<void> leave({required String groupId, required String uid});
  Future<List<GroupMember>> listMembers(String groupId, {int limit = 50});
  Future<void> removeMember({required String groupId, required String uid});

  /// Owner only (enforced by the rules): appoints or removes a moderator.
  Future<void> setMemberRole({
    required String groupId,
    required String uid,
    required MemberRole role,
  });

  /// Newest visible messages, newest first, updating live.
  Stream<List<ChatMessage>> watchRecent(String groupId);

  /// The user's own messages still waiting for moderation.
  Stream<List<ChatMessage>> watchMyPending(String groupId, String uid);

  /// A page of visible messages older than [before], newest first.
  Future<List<ChatMessage>> loadOlder(String groupId, ChatMessage before);

  /// Returns the status the message was stored with.
  Future<MessageStatus> send({
    required String groupId,
    required String uid,
    required String senderName,
    required String text,
  });

  Future<void> withdraw({required String groupId, required String messageId});

  // Moderation.
  Future<List<PendingItem>> pendingForGroup(String groupId);
  Future<List<PendingItem>> pendingAcrossGroups();
  Future<void> moderate({
    required String groupId,
    required String messageId,
    required String moderatorId,
    required bool approve,
  });
}

class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _groups.doc(groupId).collection('messages');

  static Group _group(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const {};
    return Group(
      id: snap.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? 'general',
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      isActive: d['isActive'] == true,
    );
  }

  static ChatMessage _message(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const {};
    return ChatMessage(
      id: snap.id,
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: readTimestamp(d['createdAt']),
      status: MessageStatus.fromValue(d['status']),
      isSending: snap.metadata.hasPendingWrites,
    );
  }

  @override
  Future<List<Group>> listGroups() => guardFirestore(() async {
    final snap = await _groups
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .limit(100)
        .get();
    return snap.docs.map(_group).toList();
  });

  @override
  Future<Group?> getGroup(String groupId) => guardFirestore(() async {
    final snap = await _groups.doc(groupId).get();
    return snap.exists ? _group(snap) : null;
  });

  @override
  Future<String> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required String category,
  }) => guardFirestore(() async {
    final ref = _groups.doc();
    await ref.set({
      'name': name.trim(),
      'description': description.trim(),
      'category': category,
      'createdBy': ownerId,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'memberCount': 0,
    });
    return ref.id;
  });

  @override
  Future<Map<String, MemberRole>> myMemberships(String uid) =>
      guardFirestore(() async {
        final snap = await _db
            .collectionGroup('members')
            .where('uid', isEqualTo: uid)
            .get();
        return {
          for (final doc in snap.docs)
            if (doc.reference.parent.parent case final group?)
              group.id: doc.data()['role'] == 'moderator'
                  ? MemberRole.moderator
                  : MemberRole.member,
        };
      });

  @override
  Future<MemberRole?> myRole(String groupId, String uid) =>
      guardFirestore(() async {
        final snap = await _groups
            .doc(groupId)
            .collection('members')
            .doc(uid)
            .get();
        final data = snap.data();
        if (data == null) return null;
        return data['role'] == 'moderator'
            ? MemberRole.moderator
            : MemberRole.member;
      });

  @override
  Future<void> join({
    required String groupId,
    required String uid,
    required String displayName,
  }) => guardFirestore(
    () => _groups.doc(groupId).collection('members').doc(uid).set({
      'uid': uid,
      'role': 'member',
      'displayName': displayName,
      'joinedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> leave({required String groupId, required String uid}) =>
      removeMember(groupId: groupId, uid: uid);

  @override
  Future<void> removeMember({required String groupId, required String uid}) =>
      guardFirestore(
        () => _groups.doc(groupId).collection('members').doc(uid).delete(),
      );

  @override
  Future<void> setMemberRole({
    required String groupId,
    required String uid,
    required MemberRole role,
  }) => guardFirestore(
    () => _groups.doc(groupId).collection('members').doc(uid).update({
      'role': role.name,
    }),
  );

  @override
  Future<List<GroupMember>> listMembers(String groupId, {int limit = 50}) =>
      guardFirestore(() async {
        final snap = await _groups
            .doc(groupId)
            .collection('members')
            .orderBy('displayName')
            .limit(limit)
            .get();
        return [
          for (final doc in snap.docs)
            GroupMember(
              uid: doc.id,
              displayName: doc.data()['displayName'] as String? ?? '',
              role: doc.data()['role'] == 'moderator'
                  ? MemberRole.moderator
                  : MemberRole.member,
            ),
        ];
      });

  @override
  Stream<List<ChatMessage>> watchRecent(String groupId) =>
      _messages(groupId)
          .where('status', isEqualTo: 'visible')
          .orderBy('createdAt', descending: true)
          .limit(CommunityLimits.pageSize)
          .snapshots(includeMetadataChanges: true)
          .map((snap) => snap.docs.map(_message).toList());

  @override
  Stream<List<ChatMessage>> watchMyPending(String groupId, String uid) =>
      _messages(groupId)
          .where('senderId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(includeMetadataChanges: true)
          .map((snap) => snap.docs.map(_message).toList());

  @override
  Future<List<ChatMessage>> loadOlder(String groupId, ChatMessage before) =>
      guardFirestore(() async {
        final cursor = before.createdAt;
        if (cursor == null) return const [];
        final snap = await _messages(groupId)
            .where('status', isEqualTo: 'visible')
            .orderBy('createdAt', descending: true)
            .startAfter([Timestamp.fromDate(cursor)])
            .limit(CommunityLimits.pageSize)
            .get();
        return snap.docs.map(_message).toList();
      });

  @override
  Future<MessageStatus> send({
    required String groupId,
    required String uid,
    required String senderName,
    required String text,
  }) => guardFirestore(() async {
    final status = containsLink(text)
        ? MessageStatus.pending
        : MessageStatus.visible;
    final message = _messages(groupId).doc();
    final batch = _db.batch()
      ..set(_db.collection('rateLimits').doc(uid), {
        'lastPostAt': FieldValue.serverTimestamp(),
        'lastMessageId': message.id,
      })
      ..set(message, {
        'senderId': uid,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'status': status.name,
      });
    await batch.commit();
    return status;
  });

  @override
  Future<void> withdraw({required String groupId, required String messageId}) =>
      guardFirestore(
        () => _messages(groupId).doc(messageId).update({'status': 'withdrawn'}),
      );

  @override
  Future<List<PendingItem>> pendingForGroup(String groupId) =>
      guardFirestore(() async {
        final snap = await _messages(groupId)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt')
            .limit(50)
            .get();
        return [
          for (final doc in snap.docs)
            PendingItem(groupId: groupId, message: _message(doc)),
        ];
      });

  @override
  Future<List<PendingItem>> pendingAcrossGroups() => guardFirestore(() async {
    final snap = await _db
        .collectionGroup('messages')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .limit(50)
        .get();
    return [
      for (final doc in snap.docs)
        if (doc.reference.parent.parent case final group?)
          PendingItem(groupId: group.id, message: _message(doc)),
    ];
  });

  @override
  Future<void> moderate({
    required String groupId,
    required String messageId,
    required String moderatorId,
    required bool approve,
  }) => guardFirestore(
    () => _messages(groupId).doc(messageId).update({
      'status': approve ? 'visible' : 'removed',
      'moderatedBy': moderatorId,
      'moderatedAt': FieldValue.serverTimestamp(),
    }),
  );
}
