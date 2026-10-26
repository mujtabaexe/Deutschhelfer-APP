import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/community.dart';
import 'community_failure.dart';

/// One-to-one conversations, blocking and display-name lookups.
abstract interface class ConversationRepository {
  /// The user's most recent conversations, updating live.
  Stream<List<Conversation>> watchInbox(String uid);

  /// Returns the id of the conversation, creating it if needed. Both users
  /// must share [groupId] and neither may have blocked the other.
  Future<String> open({
    required String me,
    required String other,
    required String groupId,
  });

  Stream<List<ChatMessage>> watchRecent(String conversationId);
  Future<List<ChatMessage>> loadOlder(
    String conversationId,
    ChatMessage before,
  );
  Future<void> send({
    required String conversationId,
    required String uid,
    required String text,
  });

  Stream<Set<String>> watchBlocked(String uid);
  Future<void> block({required String me, required String other});
  Future<void> unblock({required String me, required String other});

  /// Display name from the public profile, cached for the session.
  Future<String?> displayName(String uid);
}

class FirestoreConversationRepository implements ConversationRepository {
  FirestoreConversationRepository(this._db);

  final FirebaseFirestore _db;
  final Map<String, String?> _names = {};

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(String id) =>
      _conversations.doc(id).collection('directMessages');

  static Conversation _conversation(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? const {};
    final last = d['lastMessage'];
    return Conversation(
      id: s.id,
      participants: [...(d['participants'] as List? ?? const [])]
          .whereType<String>()
          .toList(),
      groupId: d['groupId'] as String? ?? '',
      updatedAt: readTimestamp(d['updatedAt']),
      lastMessageText: last is Map ? last['text'] as String? : null,
      lastMessageSenderId: last is Map ? last['senderId'] as String? : null,
    );
  }

  static ChatMessage _message(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? const {};
    return ChatMessage(
      id: s.id,
      senderId: d['senderId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: readTimestamp(d['createdAt']),
      isSending: s.metadata.hasPendingWrites,
    );
  }

  @override
  Stream<List<Conversation>> watchInbox(String uid) => _conversations
      .where('participants', arrayContains: uid)
      .orderBy('updatedAt', descending: true)
      .limit(CommunityLimits.pageSize)
      .snapshots()
      .map((snap) => snap.docs.map(_conversation).toList());

  @override
  Future<String> open({
    required String me,
    required String other,
    required String groupId,
  }) => guardFirestore(() async {
    final id = Conversation.idFor(me, other);
    final ref = _conversations.doc(id);
    final existing = await ref.get();
    if (existing.exists) return id;
    final participants = [me, other]..sort();
    await ref.set({
      'participants': participants,
      'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  });

  @override
  Stream<List<ChatMessage>> watchRecent(String conversationId) =>
      _messages(conversationId)
          .orderBy('createdAt', descending: true)
          .limit(CommunityLimits.pageSize)
          .snapshots(includeMetadataChanges: true)
          .map((snap) => snap.docs.map(_message).toList());

  @override
  Future<List<ChatMessage>> loadOlder(
    String conversationId,
    ChatMessage before,
  ) => guardFirestore(() async {
    final cursor = before.createdAt;
    if (cursor == null) return const [];
    final snap = await _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(cursor)])
        .limit(CommunityLimits.pageSize)
        .get();
    return snap.docs.map(_message).toList();
  });

  @override
  Future<void> send({
    required String conversationId,
    required String uid,
    required String text,
  }) => guardFirestore(() async {
    final summary = text.length > CommunityLimits.summaryMaxLength
        ? text.substring(0, CommunityLimits.summaryMaxLength)
        : text;
    final message = _messages(conversationId).doc();
    final batch = _db.batch()
      ..set(_db.collection('rateLimits').doc(uid), {
        'lastPostAt': FieldValue.serverTimestamp(),
        'lastMessageId': message.id,
      })
      ..set(message, {
        'senderId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(_conversations.doc(conversationId), {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': {'senderId': uid, 'text': summary.trim()},
      });
    await batch.commit();
  });

  CollectionReference<Map<String, dynamic>> _blocked(String uid) =>
      _db.collection('users').doc(uid).collection('blocked');

  @override
  Stream<Set<String>> watchBlocked(String uid) =>
      _blocked(uid)
          .snapshots()
          .map((snap) => {for (final doc in snap.docs) doc.id});

  @override
  Future<void> block({required String me, required String other}) =>
      guardFirestore(
        () =>
            _blocked(me)
                .doc(other)
                .set({'createdAt': FieldValue.serverTimestamp()}),
      );

  @override
  Future<void> unblock({required String me, required String other}) =>
      guardFirestore(() => _blocked(me).doc(other).delete());

  @override
  Future<String?> displayName(String uid) async {
    if (_names.containsKey(uid)) return _names[uid];
    try {
      final snap = await _db.collection('users').doc(uid).get();
      return _names[uid] = snap.data()?['displayName'] as String?;
    } on FirebaseException {
      return null;
    }
  }
}
