import 'package:flutter/material.dart';

import '../../../../data/repositories/report_repository.dart';
import '../../../../domain/models/community.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/state_views.dart';

String reportReasonLabel(BuildContext context, ReportReason reason) {
  final l10n = context.l10n;
  return switch (reason) {
    ReportReason.spam => l10n.reportReasonSpam,
    ReportReason.harassment => l10n.reportReasonHarassment,
    ReportReason.scam => l10n.reportReasonScam,
    ReportReason.inappropriate => l10n.reportReasonInappropriate,
    ReportReason.other => l10n.reportReasonOther,
  };
}

/// Asks for a reason and submits the report. Shows a snackbar with the
/// outcome.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportRepository repository,
  required String reporterId,
  required ReportTarget target,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final outcome = await showModalBottomSheet<ReportOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(
      repository: repository,
      reporterId: reporterId,
      target: target,
    ),
  );
  if (outcome == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        outcome == ReportOutcome.submitted
            ? l10n.reportSent
            : l10n.reportAlready,
      ),
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.repository,
    required this.reporterId,
    required this.target,
  });

  final ReportRepository repository;
  final String reporterId;
  final ReportTarget target;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final outcome = await widget.repository.submit(
        reporterId: widget.reporterId,
        target: widget.target,
        reason: reason,
        details: _details.text,
      );
      if (mounted) Navigator.pop(context, outcome);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.reportWhy, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(reportReasonLabel(context, reason)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _details,
                maxLength: CommunityLimits.reportDetailsMaxLength,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.reportDetails),
              ),
              if (_failed) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineMessage(message: l10n.reportFailed),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.reportSubmit,
                isLoading: _busy,
                onPressed: _reason == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
