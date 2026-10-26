/// Groups, messages, conversations and reports.
library;

/// Limits shared with `firebase/firestore.rules`.
abstract final class CommunityLimits {
  static const int messageMaxLength = 2000;
  static const int summaryMaxLength = 120;
  static const int reportDetailsMaxLength = 500;
  static const int groupMaxMembers = 2000;
  static const int groupNameMinLength = 3;
  static const int groupNameMaxLength = 60;
  static const int groupDescriptionMaxLength = 500;
  static const int suspensionReasonMaxLength = 500;

  /// Group categories accepted by the rules, in display order.
  static const groupCategories = [
    'admissions',
    'visa',
    'ielts',
    'living',
    'general',
  ];
  static const int pageSize = 30;

  /// The server allows one post per second; the client waits a little longer.
  static const Duration minPostInterval = Duration(milliseconds: 1100);
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.memberCount,
    required this.isActive,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int memberCount;
  final bool isActive;

  bool get isFull => memberCount >= CommunityLimits.groupMaxMembers;
}

enum MemberRole { member, moderator }

class GroupMember {
  const GroupMember({
    required this.uid,
    required this.displayName,
    required this.role,
  });

  final String uid;
  final String displayName;
  final MemberRole role;
}

enum MessageStatus {
  visible,
  pending,
  removed,
  withdrawn;

  static MessageStatus fromValue(Object? value) => switch (value) {
    'pending' => MessageStatus.pending,
    'removed' => MessageStatus.removed,
    'withdrawn' => MessageStatus.withdrawn,
    _ => MessageStatus.visible,
  };
}

/// A message in a group or a direct conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.senderName = '',
    this.status = MessageStatus.visible,
    this.isSending = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;

  /// Null only for a local write not yet confirmed by the server.
  final DateTime? createdAt;
  final MessageStatus status;

  /// True while the write is only in the local cache.
  final bool isSending;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.groupId,
    this.updatedAt,
    this.lastMessageText,
    this.lastMessageSenderId,
  });

  final String id;
  final List<String> participants;
  final String groupId;
  final DateTime? updatedAt;
  final String? lastMessageText;
  final String? lastMessageSenderId;

  String otherParticipant(String me) =>
      participants.firstWhere((id) => id != me, orElse: () => me);

  /// Deterministic id for a pair, matching the security rules.
  static String idFor(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

enum ReportReason { spam, harassment, scam, inappropriate, other }

enum ReportTargetType { groupMessage, directMessage, user }

/// What is being reported. Message targets carry the exact text, which the
/// server checks against the stored message.
class ReportTarget {
  ReportTarget.groupMessage({
    required String this.groupId,
    required ChatMessage message,
  }) : type = ReportTargetType.groupMessage,
       targetId = message.id,
       targetUserId = message.senderId,
       excerpt = message.text,
       conversationId = null;

  ReportTarget.directMessage({
    required String this.conversationId,
    required ChatMessage message,
  }) : type = ReportTargetType.directMessage,
       targetId = message.id,
       targetUserId = message.senderId,
       excerpt = message.text,
       groupId = null;

  const ReportTarget.user({required String userId})
    : type = ReportTargetType.user,
      targetId = userId,
      targetUserId = userId,
      excerpt = '',
      groupId = null,
      conversationId = null;

  final ReportTargetType type;
  final String targetId;
  final String targetUserId;
  final String excerpt;
  final String? groupId;
  final String? conversationId;
}

enum ReportStatus { open, dismissed, actioned }

class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.reason,
    required this.details,
    required this.excerpt,
    required this.status,
    this.groupId,
    this.conversationId,
    this.createdAt,
  });

  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final String targetUserId;
  final ReportReason reason;
  final String details;
  final String excerpt;
  final ReportStatus status;
  final String? groupId;
  final String? conversationId;
  final DateTime? createdAt;
}

/// A suspended account, for staff.
class Suspension {
  const Suspension({
    required this.uid,
    required this.displayName,
    required this.reason,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String reason;
  final DateTime? updatedAt;
}

/// A pending group message with the group it belongs to, for moderators.
class PendingItem {
  const PendingItem({required this.groupId, required this.message});

  final String groupId;
  final ChatMessage message;
}
