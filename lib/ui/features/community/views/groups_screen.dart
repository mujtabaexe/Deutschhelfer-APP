import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/community.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/state_views.dart';

String groupCategoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    'admissions' => l10n.categoryAdmissions,
    'visa' => l10n.categoryVisa,
    'ielts' => l10n.categoryIelts,
    'living' => l10n.categoryLiving,
    _ => l10n.categoryGeneral,
  };
}

class GroupsViewModel extends ChangeNotifier {
  GroupsViewModel({required this._repository, required this.uid});

  final GroupRepository _repository;
  final String uid;

  List<Group> _groups = const [];
  Map<String, MemberRole> _memberships = const {};
  bool _loading = false;
  bool _failed = false;
  bool _disposed = false;

  bool get isLoading => _loading;
  bool get failed => _failed;
  List<Group> get mine =>
      _groups.where((g) => _memberships.containsKey(g.id)).toList();
  List<Group> get discover =>
      _groups.where((g) => !_memberships.containsKey(g.id)).toList();

  Future<void> load() async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      final results = await Future.wait([
        _repository.listGroups(),
        _repository.myMemberships(uid),
      ]);
      _groups = results[0] as List<Group>;
      _memberships = results[1] as Map<String, MemberRole>;
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
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

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({
    super.key,
    required this.repository,
    required this.uid,
    this.canCreate = false,
  });

  final GroupRepository repository;
  final String uid;

  /// Shows the owner's "New group" button. The rules decide who may create.
  final bool canCreate;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupsViewModel _viewModel = GroupsViewModel(
    repository: widget.repository,
    uid: widget.uid,
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

  Future<void> _create() async {
    final id = await context.push<String>(AppRoutes.createGroup);
    if (id == null || !mounted) return;
    await _viewModel.load();
    if (mounted) context.go('${AppRoutes.groups}/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsTitle)),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.groupsCreate),
            )
          : null,
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final vm = _viewModel;
          if (vm.isLoading && vm.mine.isEmpty && vm.discover.isEmpty) {
            return const LoadingView();
          }
          if (vm.failed) {
            return ErrorView(message: l10n.groupsLoadFailed, onRetry: vm.load);
          }
          if (vm.mine.isEmpty && vm.discover.isEmpty) {
            return EmptyView(
              icon: Icons.groups_outlined,
              title: l10n.groupsEmptyTitle,
              message: l10n.groupsEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: vm.load,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (vm.mine.isNotEmpty) ...[
                  _Heading(l10n.groupsYours),
                  for (final group in vm.mine)
                    _GroupCard(
                      group: group,
                      onTap: () =>
                          context.go('${AppRoutes.groups}/${group.id}/chat'),
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (vm.discover.isNotEmpty) ...[
                  _Heading(l10n.groupsDiscover),
                  for (final group in vm.discover)
                    _GroupCard(
                      group: group,
                      onTap: () =>
                          context.go('${AppRoutes.groups}/${group.id}'),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      Icons.groups_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${groupCategoryLabel(context, group.category)} · '
                        '${l10n.groupsMemberCount(group.memberCount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (group.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          group.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
