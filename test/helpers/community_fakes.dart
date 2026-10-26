import 'dart:async';

import 'package:deutschhelfer/data/repositories/account_repository.dart';
import 'package:deutschhelfer/data/repositories/community_failure.dart';
import 'package:deutschhelfer/data/repositories/conversation_repository.dart';
import 'package:deutschhelfer/data/repositories/group_repository.dart';
import 'package:deutschhelfer/data/repositories/push_repository.dart';
import 'package:deutschhelfer/data/repositories/report_repository.dart';
import 'package:deutschhelfer/domain/models/community.dart';
import 'package:deutschhelfer/domain/validation/link_detector.dart';

/// In-memory groups that mimic the server's moderation behaviour.
class FakeGroupRepository implements GroupRepository {
  final groups = <String, Group>{};
  final members = <String, Map<String, GroupMember>>{};
  final messages = <String, List<ChatMessage>>{};
  final _changes = StreamController<String>.broadcast();
  final calls = <String>[];
  bool refuseWrites = false;
  var _clock = DateTime(2026, 1, 1, 9);

  void addGroup(String id, String name, {int memberCount = 0}) {
    groups[id] = Group(
      id: id,
      name: name,
      description: 'About $name',
      category: 'visa',
      memberCount: memberCount,
      isActive: true,
    );
  }

  void addMember(
    String groupId,
    String uid,
    String name, {
    MemberRole role = MemberRole.member,
  }) {
    (members[groupId] ??= {})[uid] = GroupMember(
      uid: uid,
      displayName: name,
      role: role,
    );
  }

  ChatMessage addMessage(
    String groupId,
    String sender,
    String text, {
    MessageStatus status = MessageStatus.visible,
  }) {
    _clock = _clock.add(const Duration(minutes: 1));
    final message = ChatMessage(
      id: 'msg${(messages[groupId] ?? []).length + 1}',
      senderId: sender,
      senderName: sender,
      text: text,
      createdAt: _clock,
      status: status,
    );
    (messages[groupId] ??= []).add(message);
    _changes.add(groupId);
    return message;
  }

  List<ChatMessage> _where(String groupId, bool Function(ChatMessage) test) =>
      (messages[groupId] ?? []).where(test).toList().reversed.toList();

  void _guard() {
    if (refuseWrites) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
  }

  @override
  Future<List<Group>> listGroups() async => groups.values.toList();

  @override
  Future<Group?> getGroup(String groupId) async => groups[groupId];

  @override
  Future<String> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required String category,
  }) async {
    _guard();
    final id = 'new${groups.length + 1}';
    groups[id] = Group(
      id: id,
      name: name.trim(),
      description: description.trim(),
      category: category,
      memberCount: 0,
      isActive: true,
    );
    calls.add('create:$id:$ownerId:$category');
    return id;
  }

  @override
  Future<Map<String, MemberRole>> myMemberships(String uid) async => {
    for (final entry in members.entries)
      if (entry.value[uid] case final member?) entry.key: member.role,
  };

  @override
  Future<MemberRole?> myRole(String groupId, String uid) async =>
      members[groupId]?[uid]?.role;

  @override
  Future<void> join({
    required String groupId,
    required String uid,
    required String displayName,
  }) async {
    _guard();
    calls.add('join:$groupId');
    addMember(groupId, uid, displayName);
  }

  @override
  Future<void> leave({required String groupId, required String uid}) async {
    calls.add('leave:$groupId');
    members[groupId]?.remove(uid);
  }

  @override
  Future<List<GroupMember>> listMembers(
    String groupId, {
    int limit = 50,
  }) async => (members[groupId] ?? {}).values.toList();

  @override
  Future<void> removeMember({required String groupId, required String uid}) =>
      leave(groupId: groupId, uid: uid);

  @override
  Future<void> setMemberRole({
    required String groupId,
    required String uid,
    required MemberRole role,
  }) async {
    calls.add('role:$uid:${role.name}');
    final m = members[groupId]![uid]!;
    addMember(groupId, uid, m.displayName, role: role);
  }

  @override
  Stream<List<ChatMessage>> watchRecent(String groupId) async* {
    List<ChatMessage> visible() =>
        _where(groupId, (m) => m.status == MessageStatus.visible);
    yield visible();
    yield* _changes.stream.where((id) => id == groupId).map((_) => visible());
  }

  @override
  Stream<List<ChatMessage>> watchMyPending(String groupId, String uid) async* {
    List<ChatMessage> mine() => _where(
      groupId,
      (m) => m.senderId == uid && m.status == MessageStatus.pending,
    );
    yield mine();
    yield* _changes.stream.where((id) => id == groupId).map((_) => mine());
  }

  @override
  Future<List<ChatMessage>> loadOlder(
    String groupId,
    ChatMessage before,
  ) async => const [];

  @override
  Future<MessageStatus> send({
    required String groupId,
    required String uid,
    required String senderName,
    required String text,
  }) async {
    _guard();
    final status = containsLink(text)
        ? MessageStatus.pending
        : MessageStatus.visible;
    addMessage(groupId, uid, text, status: status);
    return status;
  }

  void _setStatus(String groupId, String messageId, MessageStatus status) {
    final list = messages[groupId]!;
    final index = list.indexWhere((m) => m.id == messageId);
    final m = list[index];
    list[index] = ChatMessage(
      id: m.id,
      senderId: m.senderId,
      senderName: m.senderName,
      text: m.text,
      createdAt: m.createdAt,
      status: status,
    );
    _changes.add(groupId);
  }

  @override
  Future<void> withdraw({
    required String groupId,
    required String messageId,
  }) async {
    _guard();
    _setStatus(groupId, messageId, MessageStatus.withdrawn);
  }

  @override
  Future<List<PendingItem>> pendingForGroup(String groupId) async => [
    for (final m in _where(groupId, (m) => m.status == MessageStatus.pending))
      PendingItem(groupId: groupId, message: m),
  ];

  @override
  Future<List<PendingItem>> pendingAcrossGroups() async => [
    for (final id in messages.keys) ...await pendingForGroup(id),
  ];

  @override
  Future<void> moderate({
    required String groupId,
    required String messageId,
    required String moderatorId,
    required bool approve,
  }) async {
    _guard();
    calls.add('${approve ? 'approve' : 'remove'}:$messageId');
    _setStatus(
      groupId,
      messageId,
      approve ? MessageStatus.visible : MessageStatus.removed,
    );
  }
}

class FakeConversationRepository implements ConversationRepository {
  final names = <String, String>{};
  final conversations = <String, Conversation>{};
  final messages = <String, List<ChatMessage>>{};
  final blocked = <String>{};
  final _changes = StreamController<void>.broadcast();
  bool refuseOpen = false;
  var _clock = DateTime(2026, 1, 1, 9);

  @override
  Stream<List<Conversation>> watchInbox(String uid) async* {
    List<Conversation> mine() => conversations.values
        .where((c) => c.participants.contains(uid))
        .toList();
    yield mine();
    yield* _changes.stream.map((_) => mine());
  }

  @override
  Future<String> open({
    required String me,
    required String other,
    required String groupId,
  }) async {
    if (refuseOpen) throw const CommunityException(CommunityFailure.notAllowed);
    final id = Conversation.idFor(me, other);
    conversations[id] ??= Conversation(
      id: id,
      participants: [me, other]..sort(),
      groupId: groupId,
    );
    _changes.add(null);
    return id;
  }

  @override
  Stream<List<ChatMessage>> watchRecent(String conversationId) async* {
    List<ChatMessage> all() =>
        (messages[conversationId] ?? []).reversed.toList();
    yield all();
    yield* _changes.stream.map((_) => all());
  }

  @override
  Future<List<ChatMessage>> loadOlder(
    String conversationId,
    ChatMessage before,
  ) async => const [];

  @override
  Future<void> send({
    required String conversationId,
    required String uid,
    required String text,
  }) async {
    _clock = _clock.add(const Duration(minutes: 1));
    final list = messages[conversationId] ??= [];
    list.add(
      ChatMessage(
        id: 'dm${list.length + 1}',
        senderId: uid,
        text: text,
        createdAt: _clock,
      ),
    );
    final c = conversations[conversationId]!;
    conversations[conversationId] = Conversation(
      id: c.id,
      participants: c.participants,
      groupId: c.groupId,
      updatedAt: _clock,
      lastMessageText: text,
      lastMessageSenderId: uid,
    );
    _changes.add(null);
  }

  @override
  Stream<Set<String>> watchBlocked(String uid) async* {
    yield {...blocked};
    yield* _changes.stream.map((_) => {...blocked});
  }

  @override
  Future<void> block({required String me, required String other}) async {
    blocked.add(other);
    _changes.add(null);
  }

  @override
  Future<void> unblock({required String me, required String other}) async {
    blocked.remove(other);
    _changes.add(null);
  }

  @override
  Future<String?> displayName(String uid) async => names[uid];
}

class FakeReportRepository implements ReportRepository {
  final submitted = <(ReportTarget, ReportReason)>[];
  final open = <Report>[];
  final resolved = <String, bool>{};
  final suspended = <String>[];
  final suspensions = <Suspension>[];

  @override
  Future<ReportOutcome> submit({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  }) async {
    final duplicate = submitted.any(
      (s) => s.$1.type == target.type && s.$1.targetId == target.targetId,
    );
    if (duplicate) return ReportOutcome.alreadyReported;
    submitted.add((target, reason));
    return ReportOutcome.submitted;
  }

  @override
  Future<List<Report>> openReports() async => [...open];

  @override
  Future<void> resolve({
    required String reportId,
    required String staffId,
    required bool actioned,
    required String resolution,
  }) async {
    resolved[reportId] = actioned;
    open.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<void> suspend({
    required String userId,
    required String staffId,
    required String reason,
  }) async {
    suspended.add(userId);
    suspensions.add(
      Suspension(uid: userId, displayName: userId, reason: reason),
    );
  }

  @override
  Future<List<Suspension>> suspendedAccounts() async => [...suspensions];
}

class FakeAccountRepository implements AccountRepository {
  final calls = <String>[];
  bool fail = false;
  bool refuse = false;

  Future<void> _record(String call) async {
    if (refuse) throw const AccountException(AccountFailure.notAllowed);
    if (fail) throw const AccountException(AccountFailure.offline);
    calls.add(call);
  }

  @override
  Future<void> deleteMyAccount() => _record('delete');

  @override
  Future<void> setStudentAdmin({required String uid, required bool enabled}) =>
      _record('studentAdmin:$uid:$enabled');

  @override
  Future<void> liftSuspension(String uid) => _record('lift:$uid');
}

class FakePushRepository implements PushRepository {
  final enabledFor = <String>{};
  final calls = <String>[];
  final _opened = StreamController<Map<String, String>>.broadcast();
  bool deny = false;

  /// When set, [forget] never completes, like a write stuck offline.
  bool hang = false;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isEnabled(String uid) async => enabledFor.contains(uid);

  @override
  Future<bool> enable(String uid) async {
    calls.add('enable:$uid');
    if (deny) return false;
    enabledFor.add(uid);
    return true;
  }

  @override
  Future<void> disable(String uid) async {
    calls.add('disable:$uid');
    enabledFor.remove(uid);
  }

  @override
  Future<void> forget(String uid) async {
    calls.add('forget:$uid');
    if (hang) await Completer<void>().future;
    enabledFor.remove(uid);
  }

  @override
  Stream<Map<String, String>> get openedMessages => _opened.stream;

  /// Simulates the user tapping a notification.
  void tap(Map<String, String> data) => _opened.add(data);
}
