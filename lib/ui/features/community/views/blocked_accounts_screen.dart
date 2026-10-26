import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/repositories/conversation_repository.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';

/// Lists the people this user blocked, from any group or conversation, and
/// lets them unblock.
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({
    super.key,
    required this.uid,
    required this.conversations,
  });

  final String uid;
  final ConversationRepository conversations;

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  StreamSubscription<Set<String>>? _sub;
  List<String>? _ids;
  final _names = <String, String?>{};
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.conversations
        .watchBlocked(widget.uid)
        .listen(
          (ids) {
            setState(() => _ids = ids.toList()..sort());
            for (final id in ids) {
              if (_names.containsKey(id)) continue;
              _names[id] = null;
              unawaited(
                widget.conversations.displayName(id).then((name) {
                  if (mounted) setState(() => _names[id] = name);
                }),
              );
            }
          },
          onError: (Object _) {
            if (mounted) setState(() => _failed = true);
          },
        );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _unblock(String other) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.conversations.unblock(me: widget.uid, other: other);
      messenger.showSnackBar(SnackBar(content: Text(l10n.blockedUnblockDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityNotAllowed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ids = _ids;
    final Widget body;
    if (_failed) {
      body = ErrorView(message: l10n.blockedLoadFailed);
    } else if (ids == null) {
      body = const LoadingView();
    } else if (ids.isEmpty) {
      body = EmptyView(
        icon: Icons.block_outlined,
        title: l10n.blockedEmpty,
        message: l10n.blockedHint,
      );
    } else {
      body = PageBody(
        topPadding: AppSpacing.xs,
        children: [
          Text(l10n.blockedHint),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                for (final id in ids)
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: Text(_names[id] ?? l10n.unknownUser),
                    trailing: TextButton(
                      onPressed: () => _unblock(id),
                      child: Text(
                        l10n.dmUnblock,
                        semanticsLabel: l10n.blockActionUnblock(
                          _names[id] ?? l10n.unknownUser,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedTitle)),
      body: body,
    );
  }
}
