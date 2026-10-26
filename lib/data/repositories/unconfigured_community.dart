import '../../domain/models/community.dart';
import 'community_failure.dart';
import 'conversation_repository.dart';
import 'group_repository.dart';
import 'report_repository.dart';

/// Stand-ins for builds without Firebase. Nobody can sign in there, so these
/// only need to fail safely.
const _refused = CommunityException(CommunityFailure.notAllowed);

class UnconfiguredGroupRepository implements GroupRepository {
  const UnconfiguredGroupRepository();

  @override
  Future<List<Group>> listGroups() async => const [];
  @override
  Future<Group?> getGroup(String groupId) async => null;
  @override
  Future<String> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required String category,
  }) => Future.error(_refused);
  @override
  Future<Map<String, MemberRole>> myMemberships(String uid) async => const {};
  @override
  Future<MemberRole?> myRole(String groupId, String uid) async => null;
  @override
  Future<void> join({
    required String groupId,
    required String uid,
    required String displayName,
  }) => Future.error(_refused);
  @override
  Future<void> leave({required String groupId, required String uid}) =>
      Future.error(_refused);
  @override
  Future<List<GroupMember>> listMembers(
    String groupId, {
    int limit = 50,
  }) async => const [];
  @override
  Future<void> removeMember({required String groupId, required String uid}) =>
      Future.error(_refused);
  @override
  Future<void> setMemberRole({
    required String groupId,
    required String uid,
    required MemberRole role,
  }) => Future.error(_refused);
  @override
  Stream<List<ChatMessage>> watchRecent(String groupId) =>
      Stream.value(const []);
  @override
  Stream<List<ChatMessage>> watchMyPending(String groupId, String uid) =>
      Stream.value(const []);
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
  }) => Future.error(_refused);
  @override
  Future<void> withdraw({required String groupId, required String messageId}) =>
      Future.error(_refused);
  @override
  Future<List<PendingItem>> pendingForGroup(String groupId) async => const [];
  @override
  Future<List<PendingItem>> pendingAcrossGroups() async => const [];
  @override
  Future<void> moderate({
    required String groupId,
    required String messageId,
    required String moderatorId,
    required bool approve,
  }) => Future.error(_refused);
}

class UnconfiguredConversationRepository implements ConversationRepository {
  const UnconfiguredConversationRepository();

  @override
  Stream<List<Conversation>> watchInbox(String uid) => Stream.value(const []);
  @override
  Future<String> open({
    required String me,
    required String other,
    required String groupId,
  }) => Future.error(_refused);
  @override
  Stream<List<ChatMessage>> watchRecent(String conversationId) =>
      Stream.value(const []);
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
  }) => Future.error(_refused);
  @override
  Stream<Set<String>> watchBlocked(String uid) => Stream.value(const {});
  @override
  Future<void> block({required String me, required String other}) =>
      Future.error(_refused);
  @override
  Future<void> unblock({required String me, required String other}) =>
      Future.error(_refused);
  @override
  Future<String?> displayName(String uid) async => null;
}

class UnconfiguredReportRepository implements ReportRepository {
  const UnconfiguredReportRepository();

  @override
  Future<ReportOutcome> submit({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    required String details,
  }) => Future.error(_refused);
  @override
  Future<List<Report>> openReports() async => const [];
  @override
  Future<void> resolve({
    required String reportId,
    required String staffId,
    required bool actioned,
    required String resolution,
  }) => Future.error(_refused);
  @override
  Future<void> suspend({
    required String userId,
    required String staffId,
    required String reason,
  }) => Future.error(_refused);
  @override
  Future<List<Suspension>> suspendedAccounts() async => const [];
}
