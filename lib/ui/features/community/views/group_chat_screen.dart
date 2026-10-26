import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/session_controller.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/group_repository.dart';
import '../../../../data/repositories/report_repository.dart';
import '../../../../domain/models/auth_session.dart';
import '../../../../domain/models/community.dart';
import '../../../core/l10n_extensions.dart';
import '../view_models/chat_view_model.dart';
import '../widgets/block_dialog.dart';
import '../widgets/chat_view.dart';
import '../widgets/report_sheet.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.session,
    required this.groups,
    required this.reports,
    required this.conversations,
  });

  final String groupId;
  final SessionController session;
  final GroupRepository groups;
  final ReportRepository reports;

  /// Owns the user's block list.
  final ConversationRepository conversations;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  String get _uid => widget.session.session?.uid ?? '';

  late final ChatViewModel _chat = ChatViewModel(
    watchRecent: () => widget.groups.watchRecent(widget.groupId),
    watchPending: () => widget.groups.watchMyPending(widget.groupId, _uid),
    loadOlderPage: (before) => widget.groups.loadOlder(widget.groupId, before),
    sendText: (text) => widget.groups.send(
      groupId: widget.groupId,
      uid: _uid,
      senderName: widget.session.displayName,
      text: text,
    ),
  )..start();

  String? _title;
  MemberRole? _role;
  StreamSubscription<Set<String>>? _blockedSub;

  @override
  void initState() {
    super.initState();
    _loadHeader();
    _blockedSub = widget.conversations
        .watchBlocked(_uid)
        .listen(_chat.setHiddenSenders, onError: (Object _) {});
  }

  Future<void> _loadHeader() async {
    try {
      final group = await widget.groups.getGroup(widget.groupId);
      final role = await widget.groups.myRole(widget.groupId, _uid);
      if (!mounted) return;
      if (role == null) {
        // Not a member (left, removed, or a stale link): show details.
        context.go('${AppRoutes.groups}/${widget.groupId}');
        return;
      }
      setState(() {
        _title = group?.name;
        _role = role;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_blockedSub?.cancel());
    _chat.dispose();
    super.dispose();
  }

  bool get _canModerate {
    final role = widget.session.session?.role ?? UserRole.student;
    return role == UserRole.owner ||
        (role == UserRole.studentAdmin && _role == MemberRole.moderator);
  }

  Future<void> _actions(ChatMessage message) async {
    final l10n = context.l10n;
    final mine = message.senderId == _uid;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.messageActionCopy),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (mine && !message.isSending)
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(l10n.messageActionWithdraw),
                onTap: () => Navigator.pop(context, 'withdraw'),
              ),
            if (!mine) ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.messageActionReport),
                onTap: () => Navigator.pop(context, 'report'),
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: Text(l10n.blockActionBlock(message.senderName)),
                onTap: () => Navigator.pop(context, 'block'),
              ),
              if (_canModerate)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: Text(l10n.messageActionRemove),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'copy':
          await Clipboard.setData(ClipboardData(text: message.text));
          messenger.showSnackBar(SnackBar(content: Text(l10n.messageCopied)));
        case 'withdraw':
          await widget.groups.withdraw(
            groupId: widget.groupId,
            messageId: message.id,
          );
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.messageWithdrawn)),
          );
        case 'report':
          if (!mounted) return;
          await showReportSheet(
            context,
            repository: widget.reports,
            reporterId: _uid,
            target: ReportTarget.groupMessage(
              groupId: widget.groupId,
              message: message,
            ),
          );
        case 'block':
          if (!mounted) return;
          final blocked = await confirmAndBlock(
            context,
            conversations: widget.conversations,
            me: _uid,
            other: message.senderId,
            name: message.senderName,
          );
          if (blocked) {
            messenger.showSnackBar(SnackBar(content: Text(l10n.blockDone)));
          }
        case 'remove':
          await widget.groups.moderate(
            groupId: widget.groupId,
            messageId: message.id,
            moderatorId: _uid,
            approve: false,
          );
          messenger.showSnackBar(SnackBar(content: Text(l10n.moderationDone)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityNotAllowed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? l10n.groupsTitle),
        actions: [
          IconButton(
            tooltip: l10n.groupInfo,
            icon: const Icon(Icons.info_outline),
            onPressed: () =>
                context.go('${AppRoutes.groups}/${widget.groupId}'),
          ),
        ],
      ),
      body: ChatView(viewModel: _chat, myId: _uid, onLongPress: _actions),
    );
  }
}
