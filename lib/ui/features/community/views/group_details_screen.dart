import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../app/session_controller.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/conversation_repository.dart';
import '../../../../data/repositories/group_repository.dart';
import '../../../../data/repositories/report_repository.dart';
import '../../../../domain/models/auth_session.dart';
import '../../../../domain/models/community.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';
import '../widgets/block_dialog.dart';
import '../widgets/report_sheet.dart';
import 'groups_screen.dart';

class GroupDetailsViewModel extends ChangeNotifier {
  GroupDetailsViewModel({
    required this._repository,
    required this.groupId,
    required this.uid,
  });

  final GroupRepository _repository;
  final String groupId;
  final String uid;

  Group? _group;
  MemberRole? _role;
  List<GroupMember> _members = const [];
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _disposed = false;

  Group? get group => _group;
  MemberRole? get role => _role;
  bool get isMember => _role != null;
  List<GroupMember> get members => _members;
  bool get isLoading => _loading;
  bool get failed => _failed;
  bool get isBusy => _busy;

  Future<void> load() async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      final results = await Future.wait([
        _repository.getGroup(groupId),
        _repository.myRole(groupId, uid),
      ]);
      _group = results[0] as Group?;
      _role = results[1] as MemberRole?;
      _members = isMember ? await _repository.listMembers(groupId) : const [];
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<bool> join(String displayName) => _act(
    () =>
        _repository.join(groupId: groupId, uid: uid, displayName: displayName),
  );

  Future<bool> leave() =>
      _act(() => _repository.leave(groupId: groupId, uid: uid));

  Future<bool> _act(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _notify();
    try {
      await action();
      await load();
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.session,
    required this.groups,
    required this.conversations,
    required this.reports,
    required this.accounts,
  });

  final AccountRepository accounts;
  final String groupId;
  final SessionController session;
  final GroupRepository groups;
  final ConversationRepository conversations;
  final ReportRepository reports;

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late final GroupDetailsViewModel _viewModel = GroupDetailsViewModel(
    repository: widget.groups,
    groupId: widget.groupId,
    uid: widget.session.session?.uid ?? '',
  );

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _viewModel.join(widget.session.displayName);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.groupJoined)));
      context.go('${AppRoutes.groups}/${widget.groupId}/chat');
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.communityNotAllowed)));
    }
  }

  Future<void> _leave() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupLeaveConfirmTitle),
        content: Text(l10n.groupLeaveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.groupLeave),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _viewModel.leave();
      if (mounted) context.go(AppRoutes.groups);
    }
  }

  Future<void> _memberActions(GroupMember member) async {
    final l10n = context.l10n;
    final me = widget.session.session?.uid;
    if (me == null || member.uid == me) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(l10n.messageActionMessageSender(member.displayName)),
              onTap: () => Navigator.pop(context, 'message'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.dmReportUser),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(l10n.blockActionBlock(member.displayName)),
              onTap: () => Navigator.pop(context, 'block'),
            ),
            if (widget.session.session?.role == UserRole.owner)
              member.role == MemberRole.moderator
                  ? ListTile(
                      leading: const Icon(Icons.remove_moderator_outlined),
                      title: Text(l10n.groupRemoveModerator),
                      onTap: () => Navigator.pop(context, 'demote'),
                    )
                  : ListTile(
                      leading: const Icon(Icons.add_moderator_outlined),
                      title: Text(l10n.groupMakeModerator),
                      onTap: () => Navigator.pop(context, 'promote'),
                    ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'promote' || action == 'demote') {
      final messenger = ScaffoldMessenger.of(context);
      try {
        if (action == 'promote') {
          await widget.accounts.setStudentAdmin(uid: member.uid, enabled: true);
        }
        await widget.groups.setMemberRole(
          groupId: widget.groupId,
          uid: member.uid,
          role: action == 'promote' ? MemberRole.moderator : MemberRole.member,
        );
        messenger.showSnackBar(SnackBar(content: Text(l10n.groupRoleUpdated)));
        await _viewModel.load();
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.moderationFailed)));
      }
      return;
    }
    if (action == 'block') {
      final messenger = ScaffoldMessenger.of(context);
      final blocked = await confirmAndBlock(
        context,
        conversations: widget.conversations,
        me: me,
        other: member.uid,
        name: member.displayName,
      );
      if (blocked) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.blockDone)));
      }
      return;
    }
    if (action == 'report') {
      await showReportSheet(
        context,
        repository: widget.reports,
        reporterId: me,
        target: ReportTarget.user(userId: member.uid),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await widget.conversations.open(
        me: me,
        other: member.uid,
        groupId: widget.groupId,
      );
      if (mounted) context.go('${AppRoutes.messages}/$id');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dmStartFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupInfo)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final vm = _viewModel;
          final group = vm.group;
          if (vm.isLoading && group == null) return const LoadingView();
          if (vm.failed) {
            return ErrorView(message: l10n.groupsLoadFailed, onRetry: vm.load);
          }
          if (group == null) {
            return EmptyView(
              icon: Icons.group_off_outlined,
              title: l10n.groupMissing,
            );
          }
          final theme = Theme.of(context);
          final me = widget.session.session?.uid;
          return PageBody(
            topPadding: AppSpacing.xs,
            children: [
              PageHeader(
                title: group.name,
                subtitle:
                    '${groupCategoryLabel(context, group.category)} · '
                    '${l10n.groupsMemberCount(group.memberCount)}',
              ),
              if (group.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(group.description, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (!vm.isMember)
                group.isFull
                    ? InlineMessage(
                        tone: InlineMessageTone.info,
                        message: l10n.groupFull,
                      )
                    : AppButton(
                        label: l10n.groupJoin,
                        isLoading: vm.isBusy,
                        onPressed: _join,
                      )
              else ...[
                AppButton(
                  label: l10n.groupOpenChat,
                  onPressed: () =>
                      context.go('${AppRoutes.groups}/${group.id}/chat'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.groupLeave,
                  variant: AppButtonVariant.secondary,
                  isLoading: vm.isBusy,
                  onPressed: _leave,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.groupMembers,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (!vm.isMember)
                Text(
                  l10n.groupMembersPrivate,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final member in vm.members)
                        ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.displayName.isEmpty
                                  ? '?'
                                  : member.displayName.characters.first
                                        .toUpperCase(),
                            ),
                          ),
                          title: Text(member.displayName),
                          subtitle: member.uid == me
                              ? Text(l10n.groupYouBadge)
                              : member.role == MemberRole.moderator
                              ? Text(l10n.groupModeratorBadge)
                              : null,
                          trailing: member.uid == me
                              ? null
                              : const Icon(Icons.more_horiz),
                          onTap: member.uid == me
                              ? null
                              : () => _memberActions(member),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
