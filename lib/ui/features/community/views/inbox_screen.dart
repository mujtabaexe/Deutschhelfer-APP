import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../domain/models/community.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/state_views.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.repository, required this.uid});

  final ConversationRepository repository;
  final String uid;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Stream<List<Conversation>> _inbox = widget.repository.watchInbox(
    widget.uid,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: StreamBuilder<List<Conversation>>(
        stream: _inbox,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: l10n.chatLoadFailed,
              onRetry: () => setState(() {
                _inbox = widget.repository.watchInbox(widget.uid);
              }),
            );
          }
          final conversations = snapshot.data;
          if (conversations == null) return const LoadingView();
          if (conversations.isEmpty) {
            return EmptyView(
              icon: Icons.chat_bubble_outline,
              title: l10n.inboxEmptyTitle,
              message: l10n.inboxEmptyBody,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(indent: 72),
            itemBuilder: (context, index) => _ConversationTile(
              conversation: conversations[index],
              me: widget.uid,
              repository: widget.repository,
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.me,
    required this.repository,
  });

  final Conversation conversation;
  final String me;
  final ConversationRepository repository;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final other = conversation.otherParticipant(me);
    final last = conversation.lastMessageText;
    final updated = conversation.updatedAt;
    final snippet = last == null
        ? ''
        : conversation.lastMessageSenderId == me
        ? l10n.inboxYou(last)
        : last;
    return FutureBuilder<String?>(
      future: repository.displayName(other),
      builder: (context, snapshot) {
        final name = snapshot.data ?? l10n.unknownUser;
        return ListTile(
          leading: CircleAvatar(
            child: Text(name.isEmpty ? '?' : name.characters.first),
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: snippet.isEmpty
              ? null
              : Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: updated == null
              ? null
              : Text(
                  _formatTime(updated),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          onTap: () => context.go('${AppRoutes.messages}/${conversation.id}'),
        );
      },
    );
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;
    return sameDay
        ? DateFormat.Hm().format(time)
        : DateFormat.MMMd().format(time);
  }
}
