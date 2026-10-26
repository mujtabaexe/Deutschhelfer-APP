import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/repositories/community_failure.dart';
import '../../../../domain/models/community.dart';
import '../../../../domain/validation/link_detector.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../view_models/chat_view_model.dart';

String communityFailureMessage(BuildContext context, CommunityFailure f) {
  final l10n = context.l10n;
  return switch (f) {
    CommunityFailure.offline => l10n.communityOffline,
    CommunityFailure.notAllowed => l10n.communityNotAllowed,
    _ => l10n.chatSendFailed,
  };
}

/// Message list plus composer. Used by group chats and direct messages.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.viewModel,
    required this.myId,
    required this.onLongPress,
    this.showSenderNames = true,
    this.linksOpenable = true,
    this.warnAboutLinks = true,
    this.composerEnabled = true,
    this.banner,
    this.historyHeader,
  });

  final ChatViewModel viewModel;
  final String myId;
  final void Function(ChatMessage message) onLongPress;
  final bool showSenderNames;

  /// Approved group messages may offer to open links; DMs do not.
  final bool linksOpenable;

  /// Shows the moderation notice while the draft contains a link.
  final bool warnAboutLinks;
  final bool composerEnabled;

  /// Optional notice shown above the composer, such as a block notice.
  final Widget? banner;

  /// Optional notice at the start of the history. It scrolls with the
  /// messages, so it never takes fixed space on small screens.
  final Widget? historyHeader;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadOlder);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadOlder() {
    // The list is reversed, so "older" is at the max scroll extent.
    if (_scroll.position.extentAfter < 400) widget.viewModel.loadOlder();
  }

  Widget? _header() {
    final header = widget.historyHeader;
    if (header == null) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        0,
      ),
      child: header,
    );
  }

  Future<void> _send() async {
    final text = _controller.text;
    final accepted = await widget.viewModel.send(text);
    if (accepted && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final Widget list;
        if (vm.isLoading) {
          list = const LoadingView();
        } else if (vm.failed) {
          list = ErrorView(message: l10n.chatLoadFailed, onRetry: vm.retry);
        } else if (vm.messages.isEmpty) {
          list = ListView(
            children: [
              ?_header(),
              EmptyView(
                icon: Icons.forum_outlined,
                title: l10n.chatEmptyTitle,
                message: l10n.chatEmptyBody,
              ),
            ],
          );
        } else {
          final messages = vm.messages;
          list = ListView.builder(
            controller: _scroll,
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            itemCount: messages.length + 1,
            itemBuilder: (context, index) {
              if (index == messages.length) {
                return Column(
                  children: [
                    if (vm.reachedStart) ?_header(),
                    _HistoryEnd(
                      loading: vm.isLoadingOlder,
                      reachedStart: vm.reachedStart,
                    ),
                  ],
                );
              }
              final message = messages[index];
              return MessageBubble(
                message: message,
                isMine: message.senderId == widget.myId,
                showSenderName: widget.showSenderNames,
                linksOpenable: widget.linksOpenable,
                onLongPress: () => widget.onLongPress(message),
              );
            },
          );
        }

        final draft = _controller.text;
        final tooLong = draft.trim().length > CommunityLimits.messageMaxLength;
        final failure = vm.sendFailure;
        return Column(
          children: [
            Expanded(child: list),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: InlineMessage(
                  message: communityFailureMessage(context, failure),
                ),
              ),
            ?widget.banner,
            if (widget.composerEnabled)
              _Composer(
                controller: _controller,
                onSend: draft.trim().isEmpty || tooLong ? null : _send,
                notice: tooLong
                    ? l10n.chatTooLong(CommunityLimits.messageMaxLength)
                    : widget.warnAboutLinks && containsLink(draft)
                    ? l10n.chatLinkNotice
                    : null,
                noticeIsError: tooLong,
              ),
          ],
        );
      },
    );
  }
}

class _HistoryEnd extends StatelessWidget {
  const _HistoryEnd({required this.loading, required this.reachedStart});

  final bool loading;
  final bool reachedStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : reachedStart
            ? Text(
                context.l10n.chatStart,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.notice,
    required this.noticeIsError,
  });

  final TextEditingController controller;
  final VoidCallback? onSend;
  final String? notice;
  final bool noticeIsError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      0,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          noticeIsError
                              ? Icons.error_outline
                              : Icons.shield_outlined,
                          size: 18,
                          color: noticeIsError
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            notice!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: noticeIsError
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: l10n.chatComposerHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    tooltip: l10n.chatSend,
                    onPressed: onSend,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showSenderName,
    required this.linksOpenable,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final bool showSenderName;
  final bool linksOpenable;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = message.status == MessageStatus.pending;
    final created = message.createdAt;
    final time = created == null ? '' : DateFormat.Hm().format(created);
    final background = isMine
        ? scheme.primaryContainer
        : AppTheme.raisedSurface(scheme);
    final foreground = isMine ? scheme.onPrimaryContainer : scheme.onSurface;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: isMine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
    );
    final links = linksOpenable && message.status == MessageStatus.visible
        ? extractHttpLinks(message.text).take(3).toList()
        : const <Uri>[];

    final status = message.isSending
        ? l10n.chatSending
        : pending
        ? l10n.chatPendingBadge
        : null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              side: isMine
                  ? BorderSide.none
                  : BorderSide(color: scheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSenderName && !isMine)
                      Text(
                        message.senderName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontStyle: pending ? FontStyle.italic : null,
                      ),
                    ),
                    for (final link in links)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () => confirmAndOpenLink(context, link),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(l10n.linkOpenButton(link.host)),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pending) ...[
                          Icon(
                            Icons.hourglass_top,
                            size: 14,
                            color: muted?.color,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                        ],
                        Flexible(
                          child: Text(
                            [?status, if (time.isNotEmpty) time].join(' · '),
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a link only after the user sees where it goes and confirms.
Future<void> confirmAndOpenLink(BuildContext context, Uri link) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.linkOpenTitle),
      content: Text(l10n.linkOpenBody(link.host)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.linkOpenAction),
        ),
      ],
    ),
  );
  if (ok ?? false) {
    try {
      await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
