import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/session_controller.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/report_repository.dart';
import '../../../../domain/models/community.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/chat_view_model.dart';
import '../widgets/chat_view.dart';
import '../widgets/report_sheet.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.session,
    required this.conversations,
    required this.reports,
  });

  final String conversationId;
  final SessionController session;
  final ConversationRepository conversations;
  final ReportRepository reports;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  String get _me => widget.session.session?.uid ?? '';

  /// Conversation ids are `uidA_uidB`; Firebase uids contain no underscore.
  String get _other => widget.conversationId
      .split('_')
      .firstWhere((id) => id != _me, orElse: () => _me);

  late final ChatViewModel _chat = ChatViewModel(
    watchRecent: () => widget.conversations.watchRecent(widget.conversationId),
    loadOlderPage: (before) =>
        widget.conversations.loadOlder(widget.conversationId, before),
    sendText: (text) => widget.conversations.send(
      conversationId: widget.conversationId,
      uid: _me,
      text: text,
    ),
  )..start();

  late final Stream<Set<String>> _blocked = widget.conversations.watchBlocked(
    _me,
  );
  String? _name;

  @override
  void initState() {
    super.initState();
    widget.conversations.displayName(_other).then((name) {
      if (mounted) setState(() => _name = name);
    });
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  String get _displayName => _name ?? context.l10n.unknownUser;

  Future<void> _toggleBlock(bool blocked) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!blocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.dmBlockConfirmTitle(_displayName)),
          content: Text(l10n.dmBlockConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.dmBlock),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return;
    }
    try {
      if (blocked) {
        await widget.conversations.unblock(me: _me, other: _other);
      } else {
        await widget.conversations.block(me: _me, other: _other);
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityOffline)));
    }
  }

  Future<void> _actions(ChatMessage message) async {
    final l10n = context.l10n;
    final mine = message.senderId == _me;
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
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.messageActionReport),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.messageCopied)));
      }
    } else {
      await showReportSheet(
        context,
        repository: widget.reports,
        reporterId: _me,
        target: ReportTarget.directMessage(
          conversationId: widget.conversationId,
          message: message,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<Set<String>>(
      stream: _blocked,
      builder: (context, snapshot) {
        final blocked = snapshot.data?.contains(_other) ?? false;
        return Scaffold(
          appBar: AppBar(
            title: Text(_displayName),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'block') await _toggleBlock(blocked);
                  if (value == 'report' && context.mounted) {
                    await showReportSheet(
                      context,
                      repository: widget.reports,
                      reporterId: _me,
                      target: ReportTarget.user(userId: _other),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'block',
                    child: Text(blocked ? l10n.dmUnblock : l10n.dmBlock),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Text(l10n.dmReportUser),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ChatView(
                  viewModel: _chat,
                  myId: _me,
                  onLongPress: _actions,
                  showSenderNames: false,
                  linksOpenable: false,
                  warnAboutLinks: false,
                  composerEnabled: !blocked,
                  historyHeader: InlineMessage(
                    tone: InlineMessageTone.info,
                    message: l10n.dmLinksPlain,
                  ),
                  banner: blocked
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: InlineMessage(
                                  tone: InlineMessageTone.info,
                                  message: l10n.dmBlockedNotice,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              TextButton(
                                onPressed: () => _toggleBlock(true),
                                child: Text(l10n.dmUnblock),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
