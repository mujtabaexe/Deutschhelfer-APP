import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';

import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/community.dart';
import '../../../../domain/validation/input_validators.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/page_layout.dart';
import '../../../core/widgets/state_views.dart';
import 'groups_screen.dart';

class CreateGroupViewModel extends ChangeNotifier {
  CreateGroupViewModel({required this._repository, required this.ownerId});

  final GroupRepository _repository;
  final String ownerId;

  String _category = CommunityLimits.groupCategories.first;
  bool _submitting = false;
  bool _failed = false;
  bool _disposed = false;

  String get category => _category;
  bool get isSubmitting => _submitting;
  bool get failed => _failed;

  set category(String value) {
    if (!CommunityLimits.groupCategories.contains(value)) return;
    _category = value;
    _notify();
  }

  /// Returns the new group's id, or null on failure.
  Future<String?> submit({
    required String name,
    required String description,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _failed = false;
    _notify();
    try {
      return await _repository.createGroup(
        ownerId: ownerId,
        name: name,
        description: description,
        category: _category,
      );
    } catch (_) {
      _failed = true;
      return null;
    } finally {
      _submitting = false;
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

/// Owner only. The route guard hides it from others and the rules refuse
/// anyone else's write.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({
    super.key,
    required this.repository,
    required this.ownerId,
  });

  final GroupRepository repository;
  final String ownerId;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  late final CreateGroupViewModel _viewModel = CreateGroupViewModel(
    repository: widget.repository,
    ownerId: widget.ownerId,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final id = await _viewModel.submit(
      name: _name.text,
      description: _description.text,
    );
    if (id == null || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.groupCreated)));
    // Opened from the groups list, which reloads and then opens the new
    // group. Reached any other way (a deep link, or a router refresh that
    // rebuilt the stack, seen on the Android emulator), there is nothing to
    // pop, so go to the group directly.
    if (context.canPop()) {
      context.pop(id);
    } else {
      context.go('${AppRoutes.groups}/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupCreateTitle)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final busy = _viewModel.isSubmitting;
          return PageBody(
            topPadding: AppSpacing.xs,
            children: [
              Text(
                l10n.groupCreateIntro,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_viewModel.failed) ...[
                InlineMessage(message: l10n.groupCreateFailed),
                const SizedBox(height: AppSpacing.md),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _name,
                      label: l10n.groupCreateName,
                      prefixIcon: Icons.groups_outlined,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !busy,
                      maxLength: CommunityLimits.groupNameMaxLength,
                      validator: localizedValidator(
                        context,
                        InputValidators.groupName,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _viewModel.category,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.groupCreateCategory,
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                      items: [
                        for (final category in CommunityLimits.groupCategories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(groupCategoryLabel(context, category)),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) _viewModel.category = value;
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _description,
                      label: l10n.groupCreateDescription,
                      prefixIcon: Icons.notes_outlined,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      enabled: !busy,
                      maxLength: CommunityLimits.groupDescriptionMaxLength,
                      validator: localizedValidator(
                        context,
                        InputValidators.groupDescription,
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.groupCreateSubmit,
                isLoading: busy,
                onPressed: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}
