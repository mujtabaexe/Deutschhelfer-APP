import 'package:flutter/material.dart';

import '../../../../data/repositories/conversation_repository.dart';
import '../../../core/l10n_extensions.dart';

/// Asks for confirmation, then blocks [other]. Returns whether the block was
/// saved. Failures show a snackbar, so callers only report success.
Future<bool> confirmAndBlock(
  BuildContext context, {
  required ConversationRepository conversations,
  required String me,
  required String other,
  required String name,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final shown = name.trim().isEmpty ? l10n.unknownUser : name;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.dmBlockConfirmTitle(shown)),
      content: Text(l10n.groupBlockConfirmBody),
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
  if (confirmed != true || me.isEmpty || me == other) return false;
  try {
    await conversations.block(me: me, other: other);
    return true;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.communityNotAllowed)));
    return false;
  }
}
