import 'package:flutter/material.dart';

import '../../../app/session_controller.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../domain/models/auth_session.dart';
import '../../../domain/models/community.dart';
import '../../core/l10n_extensions.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/state_views.dart';
import '../community/widgets/report_sheet.dart';

/// Loads and acts on the moderation queues.
///
/// The owner sees pending links across all groups. Student-admins see them
/// for the groups they moderate. The server enforces both.
class ModerationViewModel extends ChangeNotifier {
  ModerationViewModel({
    required this._groups,
    required this._reports,
    required this._accounts,
    required this.uid,
    required this.role,
  });

  final GroupRepository _groups;
  final ReportRepository _reports;
  final AccountRepository _accounts;
  final String uid;
  final UserRole role;

  List<PendingItem> _pending = const [];
  List<Report> _open = const [];
  List<Suspension> _suspended = const [];
  bool _loading = true;
  bool _failed = false;
  bool _disposed = false;

  List<PendingItem> get pending => _pending;
  List<Report> get reports => _open;
  List<Suspension> get suspended => _suspended;
  bool get isLoading => _loading;
  bool get failed => _failed;

  Future<void> load() async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      _pending = await _loadPending();
      _open = await _reports.openReports();
      _suspended = await _reports.suspendedAccounts();
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<List<PendingItem>> _loadPending() async {
    if (role == UserRole.owner) return _groups.pendingAcrossGroups();
    final memberships = await _groups.myMemberships(uid);
    final moderated = [
      for (final entry in memberships.entries)
        if (entry.value == MemberRole.moderator) entry.key,
    ];
    final pages = await Future.wait(moderated.map(_groups.pendingForGroup));
    return [for (final page in pages) ...page]..sort(
      (a, b) => (a.message.createdAt ?? DateTime(0)).compareTo(
        b.message.createdAt ?? DateTime(0),
      ),
    );
  }

  Future<bool> decide(PendingItem item, {required bool approve}) async {
    try {
      await _groups.moderate(
        groupId: item.groupId,
        messageId: item.message.id,
        moderatorId: uid,
        approve: approve,
      );
      _pending = [..._pending]..remove(item);
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resolve(
    Report report, {
    required bool actioned,
    String note = '',
  }) async {
    try {
      await _reports.resolve(
        reportId: report.id,
        staffId: uid,
        actioned: actioned,
        resolution: note,
      );
      _open = [..._open]..remove(report);
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lifting goes through a function that checks the caller's role and
  /// writes the audit log.
  Future<LiftOutcome> lift(Suspension suspension) async {
    try {
      await _accounts.liftSuspension(suspension.uid);
    } on AccountException catch (error) {
      return error.failure == AccountFailure.notAllowed
          ? LiftOutcome.notAllowed
          : LiftOutcome.failed;
    } catch (_) {
      return LiftOutcome.failed;
    }
    _suspended = [..._suspended]..remove(suspension);
    _notify();
    return LiftOutcome.lifted;
  }

  Future<bool> suspendAndResolve(Report report, String reason) async {
    try {
      await _reports.suspend(
        userId: report.targetUserId,
        staffId: uid,
        reason: reason,
      );
    } catch (_) {
      return false;
    }
    final ok = await resolve(report, actioned: true, note: reason);
    if (ok) {
      // Show the new suspension without a full reload.
      try {
        _suspended = await _reports.suspendedAccounts();
        _notify();
      } catch (_) {}
    }
    return ok;
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

enum LiftOutcome { lifted, notAllowed, failed }

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({
    super.key,
    required this.session,
    required this.groups,
    required this.reports,
    required this.accounts,
  });

  final SessionController session;
  final GroupRepository groups;
  final ReportRepository reports;
  final AccountRepository accounts;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  late final ModerationViewModel _viewModel = ModerationViewModel(
    groups: widget.groups,
    reports: widget.reports,
    accounts: widget.accounts,
    uid: widget.session.session?.uid ?? '',
    role: widget.session.session?.role ?? UserRole.student,
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

  void _toast(bool ok) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.moderationDone : l10n.moderationFailed)),
    );
  }

  Future<void> _suspend(Report report) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _SuspendDialog(),
    );
    if (reason == null || reason.isEmpty) return;
    final ok = await _viewModel.suspendAndResolve(report, reason);
    if (mounted) _toast(ok);
  }

  Future<void> _lift(Suspension suspension) async {
    final l10n = context.l10n;
    final name = suspension.displayName.isEmpty
        ? l10n.moderationSuspendedUnknownName
        : suspension.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.moderationLiftTitle),
        content: Text(l10n.moderationLiftBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.moderationLift),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    final outcome = await _viewModel.lift(suspension);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          LiftOutcome.lifted => l10n.moderationDone,
          LiftOutcome.notAllowed => l10n.moderationLiftNotAllowed,
          LiftOutcome.failed => l10n.moderationFailed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compactTabs =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.moderationTitle),
          bottom: TabBar(
            // Fixed tabs fit a normal phone. Small screens and large text
            // scroll instead, so labels are never cut off.
            isScrollable: compactTabs,
            tabAlignment: compactTabs ? TabAlignment.start : null,
            tabs: [
              Tab(text: l10n.moderationPendingTab),
              Tab(text: l10n.moderationReportsTab),
              Tab(text: l10n.moderationSuspendedTab),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final vm = _viewModel;
            if (vm.isLoading) return const LoadingView();
            if (vm.failed) {
              return ErrorView(
                message: l10n.moderationFailed,
                onRetry: vm.load,
              );
            }
            return TabBarView(
              children: [
                _pendingList(context),
                _reportList(context),
                _suspendedList(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pendingList(BuildContext context) {
    final l10n = context.l10n;
    final items = _viewModel.pending;
    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.verified_outlined,
        title: l10n.moderationPendingEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: _viewModel.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          return _QueueCard(
            title: l10n.moderationFrom(item.message.senderName),
            body: item.message.text,
            actions: [
              TextButton(
                onPressed: () async =>
                    _toast(await _viewModel.decide(item, approve: false)),
                child: Text(l10n.moderationRemove),
              ),
              FilledButton(
                onPressed: () async =>
                    _toast(await _viewModel.decide(item, approve: true)),
                child: Text(l10n.moderationApprove),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reportList(BuildContext context) {
    final l10n = context.l10n;
    final items = _viewModel.reports;
    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.flag_outlined,
        title: l10n.moderationReportsEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: _viewModel.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final report = items[index];
          final type = switch (report.targetType) {
            ReportTargetType.groupMessage => l10n.reportTypeGroupMessage,
            ReportTargetType.directMessage => l10n.reportTypeDirectMessage,
            ReportTargetType.user => l10n.reportTypeUser,
          };
          return _QueueCard(
            title: l10n.moderationReportLine(
              reportReasonLabel(context, report.reason),
              type,
            ),
            body: [
              if (report.excerpt.isNotEmpty) '“${report.excerpt}”',
              if (report.details.isNotEmpty) report.details,
            ].join('\n\n'),
            actions: [
              TextButton(
                onPressed: () async =>
                    _toast(await _viewModel.resolve(report, actioned: false)),
                child: Text(l10n.moderationDismiss),
              ),
              FilledButton.tonal(
                onPressed: () => _suspend(report),
                child: Text(l10n.moderationSuspend),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _suspendedList(BuildContext context) {
    final l10n = context.l10n;
    final items = _viewModel.suspended;
    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.how_to_reg_outlined,
        title: l10n.moderationSuspendedEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: _viewModel.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          return _QueueCard(
            title: item.displayName.isEmpty
                ? l10n.moderationSuspendedUnknownName
                : item.displayName,
            body: item.reason.isEmpty
                ? ''
                : l10n.moderationSuspendedReason(item.reason),
            actions: [
              FilledButton.tonal(
                onPressed: () => _lift(item),
                child: Text(l10n.moderationLift),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              // Plain text: user content is never rendered as links here.
              SelectableText(body, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog's exit
/// animation finishes.
class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog();

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.moderationSuspendTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.moderationSuspendBody),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            maxLength: 500,
            decoration: InputDecoration(labelText: l10n.moderationReason),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.moderationSuspend),
        ),
      ],
    );
  }
}
