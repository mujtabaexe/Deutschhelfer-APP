import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/session_controller.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/push_repository.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/validation/input_validators.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/page_layout.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.session,
    required this.profileRepository,
    required this.accountRepository,
    required this.authRepository,
    this.pushRepository = const UnsupportedPushRepository(),
  });

  final SessionController session;
  final ProfileRepository profileRepository;
  final AccountRepository accountRepository;
  final AuthRepository authRepository;
  final PushRepository pushRepository;

  Future<void> _deleteAccount(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null) return;
    try {
      // The server requires a recent sign-in before deleting.
      await authRepository.reauthenticate(password: password);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileDeleteWrongPassword)),
      );
      return;
    }
    try {
      await accountRepository.deleteMyAccount();
      await session.signOut();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileDeleteFailed)));
    }
  }

  Future<void> _editName(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final uid = session.session?.uid;
    if (uid == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: session.displayName),
    );
    if (name == null || name == session.displayName) return;
    try {
      await profileRepository.saveDisplayName(uid: uid, displayName: name);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileNameSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSignOutConfirmTitle),
        content: Text(l10n.profileSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final auth = session.session;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final role = auth?.role ?? UserRole.student;
          return PageBody(
            topPadding: AppSpacing.xs,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text(
                        _initials(session.displayName),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            session.displayName,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            if (role == UserRole.owner)
                              _RoleChip(label: l10n.profileRoleOwner),
                            if (role == UserRole.studentAdmin)
                              _RoleChip(label: l10n.profileRoleStudentAdmin),
                            if (auth?.isPremium ?? false)
                              _RoleChip(label: l10n.profilePremium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(l10n.profileSectionAccount),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(l10n.profileEditName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editName(context),
                    ),
                    const Divider(indent: AppSpacing.md),
                    ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: Text(l10n.profileEmailLabel),
                      subtitle: Text(
                        '${auth?.email ?? ''}\n${l10n.profileEmailPrivate}',
                      ),
                      isThreeLine: true,
                    ),
                    const Divider(indent: AppSpacing.md),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: scheme.error,
                      ),
                      title: Text(
                        l10n.profileDeleteAccount,
                        style: TextStyle(color: scheme.error),
                      ),
                      onTap: () => _deleteAccount(context),
                    ),
                  ],
                ),
              ),
              if (pushRepository.isSupported && auth != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: _NotificationsTile(
                    repository: pushRepository,
                    uid: auth.uid,
                  ),
                ),
              ],
              if (role.canModerate) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel(l10n.profileSectionCommunity),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(l10n.profileModeration),
                    subtitle: Text(l10n.profileModerationHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.moderation),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(l10n.profileSectionLegal),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block_outlined),
                      title: Text(l10n.profileBlockedAccounts),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(AppRoutes.blockedAccounts),
                    ),
                    const Divider(indent: AppSpacing.md),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(l10n.linkCommunityRules),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.communityRules),
                    ),
                    const Divider(indent: AppSpacing.md),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(l10n.linkPrivacy),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.privacy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.profileAbout),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  shape: const Border(),
                  children: [
                    Text(
                      l10n.profileAboutBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout),
                label: Text(l10n.actionSignOut),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first).toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Turns message notifications on or off for this device.
class _NotificationsTile extends StatefulWidget {
  const _NotificationsTile({required this.repository, required this.uid});

  final PushRepository repository;
  final String uid;

  @override
  State<_NotificationsTile> createState() => _NotificationsTileState();
}

class _NotificationsTileState extends State<_NotificationsTile> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.repository
        .isEnabled(widget.uid)
        .then((value) => value, onError: (Object _) => false)
        .then((value) {
          if (mounted) setState(() => _enabled = value);
        });
  }

  Future<void> _toggle(bool on) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? problem;
    try {
      if (on) {
        final granted = await widget.repository.enable(widget.uid);
        if (!granted) problem = l10n.profileNotificationsDenied;
        _enabled = granted;
      } else {
        await widget.repository.disable(widget.uid);
        _enabled = false;
      }
    } catch (_) {
      problem = l10n.profileNotificationsFailed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = _enabled;
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: Text(l10n.profileNotifications),
      subtitle: Text(l10n.profileNotificationsHint),
      value: enabled ?? false,
      onChanged: enabled == null || _busy ? null : _toggle,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        bottom: AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      InputValidators.normalizeDisplayName(_controller.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.profileEditName),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _controller,
          label: l10n.fieldDisplayName,
          helperText: l10n.fieldDisplayNameHelper,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          maxLength: InputLimits.displayNameMaxLength,
          validator: localizedValidator(context, InputValidators.displayName),
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}

/// Requires typing DELETE and the password, so the account is never removed
/// by a stray tap or by someone holding an unlocked phone. Returns the
/// password when confirmed.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final confirmed =
        _controller.text.trim() == 'DELETE' && _password.text.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.profileDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileDeleteBody),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.profileDeleteConfirmLabel,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPasswordField(
            controller: _password,
            label: l10n.profileDeletePasswordLabel,
            autofillHints: const [AutofillHints.password],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: confirmed
              ? () => Navigator.pop(context, _password.text)
              : null,
          child: Text(l10n.profileDeleteAccount),
        ),
      ],
    );
  }
}
