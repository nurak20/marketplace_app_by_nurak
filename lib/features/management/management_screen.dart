import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/form_dialog.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/management_data_grid.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/management_panel.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/components/responsive_row.dart';
import '../../core/components/show_error.dart';
import '../../core/components/user_avatar.dart';
import '../../core/models.dart';
import '../../core/singleton.dart';

enum _ManagementSection { users, categories, conditions, posts }

class _SectionSpec {
  const _SectionSpec(this.section, this.labelKey, this.icon, this.permission);

  final _ManagementSection section;
  final String labelKey;
  final IconData icon;
  final String permission;
}

const _sectionSpecs = [
  _SectionSpec(
    _ManagementSection.users,
    'manage.users',
    Icons.people_alt_outlined,
    'user:manage',
  ),
  _SectionSpec(
    _ManagementSection.categories,
    'manage.categories',
    Icons.category_outlined,
    'category:manage',
  ),
  _SectionSpec(
    _ManagementSection.conditions,
    'manage.conditions',
    Icons.fact_check_outlined,
    'condition:manage',
  ),
  _SectionSpec(
    _ManagementSection.posts,
    'manage.posts',
    Icons.article_outlined,
    'post:moderate',
  ),
];

const _managementRoleOptions = <(String, String)>[
  ('ROLE_USER', 'profile.roleUser'),
  ('ROLE_HR', 'profile.roleHr'),
  ('ROLE_EMPLOYEE', 'profile.roleEmployee'),
  ('ROLE_MANAGER', 'profile.roleManager'),
  ('ROLE_SUPER_ADMIN', 'profile.roleSuperAdmin'),
];

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  final _categoryController = TextEditingController();
  final _conditionController = TextEditingController();
  _ManagementSection? _selected;
  bool _loading = false;
  Object? _error;
  final Set<String> _busyKeys = {};
  List<Account> _users = [];
  List<ManagementCategory> _categories = [];
  List<ManagementCondition> _conditions = [];
  List<ManagementPost> _posts = [];

  Account? get _account => Singleton.instance.account;

  List<_SectionSpec> get _availableSections => _sectionSpecs
      .where((spec) => _account?.permissions.contains(spec.permission) == true)
      .toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selected == null) {
      final available = _availableSections;
      if (available.isNotEmpty) {
        _selected = available.first.section;
        _loadSection(_selected!);
      }
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _loadSection(_ManagementSection section) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (section) {
        case _ManagementSection.users:
          final page = await api.managementUsers();
          if (mounted) setState(() => _users = page.items);
        case _ManagementSection.categories:
          final result = await api.managementCategories();
          if (mounted) {
            setState(() => _categories = result);
            _syncCategoryCache();
          }
        case _ManagementSection.conditions:
          final result = await api.managementConditions();
          if (mounted) {
            setState(() => _conditions = result);
            _syncConditionCache();
          }
        case _ManagementSection.posts:
          final page = await api.managementPosts();
          if (mounted) setState(() => _posts = page.items);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(_ManagementSection section) async {
    if (_selected == section) return;
    setState(() => _selected = section);
    await _loadSection(section);
  }

  Future<void> _refresh() =>
      _selected == null ? Future<void>.value() : _loadSection(_selected!);

  void _setBusy(String key, bool value) {
    setState(() {
      if (value) {
        _busyKeys.add(key);
      } else {
        _busyKeys.remove(key);
      }
    });
  }

  void _syncCategoryCache() => api.updateMarketplaceCategoryNames(
    _categories
        .where((category) => category.active)
        .map((category) => category.name),
  );

  Future<void> _updateUser(Account user, {bool? canSell, bool? active}) async {
    final key =
        'user-${user.profile.id}-${canSell == null ? 'active' : 'sell'}';
    if (_busyKeys.contains(key)) return;
    _setBusy(key, true);
    try {
      final updated = canSell == null
          ? await api.setUserActive(user.profile.id, active!)
          : await api.setUserSelling(user.profile.id, canSell);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere(
          (item) => item.profile.id == updated.profile.id,
        );
        if (index >= 0) _users[index] = updated;
      });
      if (_account?.profile.id == updated.profile.id) {
        Singleton.instance.setAccount(updated);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _updateUserRole(Account user, String roleName) async {
    final key = 'user-${user.profile.id}-role';
    if (_busyKeys.contains(key)) return;
    _setBusy(key, true);
    try {
      final updated = await api.setUserStaffRole(user.profile.id, roleName);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere(
          (item) => item.profile.id == updated.profile.id,
        );
        if (index >= 0) _users[index] = updated;
      });
      if (_account?.profile.id == updated.profile.id) {
        Singleton.instance.setAccount(updated);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _createManagedUser() async {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var selectedRole = 'ROLE_USER';

    final created = await showMarketplaceFormDialog<Account>(
      context: context,
      title: 'manage.createUser'.tr(),
      formKey: formKey,
      submitLabel: 'manage.createUser'.tr(),
      submitIcon: Icons.person_add_alt_1_rounded,
      onClosed: () {
        fullNameController.dispose();
        usernameController.dispose();
        emailController.dispose();
        passwordController.dispose();
      },
      content: (_) => StatefulBuilder(
        builder: (context, setFieldState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MKTextFormField(
              controller: fullNameController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'manage.fullName'.tr(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            MKTextFormField(
              controller: usernameController,
              maxLength: 50,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'manage.username'.tr(),
                counterText: '',
              ),
              validator: (value) {
                final username = value?.trim() ?? '';
                if (username.length < 3) {
                  return 'manage.usernameTooShort'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            MKTextFormField(
              controller: emailController,
              maxLength: 100,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'common.email'.tr(),
                counterText: '',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'manage.invalidEmail'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            MKTextFormField(
              controller: passwordController,
              maxLength: 72,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'manage.temporaryPassword'.tr(),
                helperText: 'manage.passwordHelper'.tr(),
                counterText: '',
              ),
              validator: (value) => (value?.length ?? 0) < 8
                  ? 'manage.passwordTooShort'.tr()
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'manage.role'.tr()),
              items: [
                for (final option in _managementRoleOptions)
                  DropdownMenuItem(
                    value: option.$1,
                    child: Text(option.$2.tr()),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setFieldState(() => selectedRole = value);
              },
            ),
          ],
        ),
      ),
      onSubmit: (_) => api.createManagementUser(
        username: usernameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        fullName: fullNameController.text.trim(),
        roleName: selectedRole,
      ),
    );
    if (created != null && mounted) {
      setState(() => _users.insert(0, created));
    }
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty || _busyKeys.contains('category-create')) return;
    _setBusy('category-create', true);
    try {
      final category = await api.createManagementCategory(name);
      if (!mounted) return;
      setState(() {
        _categories = [
          ..._categories,
          category,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _categoryController.clear();
      });
      _syncCategoryCache();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy('category-create', false);
    }
  }

  Future<void> _editCategory(ManagementCategory category) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: category.name);
    final name = await showMarketplaceFormDialog<String>(
      context: context,
      title: 'manage.renameCategory'.tr(),
      formKey: formKey,
      onClosed: controller.dispose,
      content: (dialogContext) => MKTextFormField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(labelText: 'manage.categoryName'.tr()),
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'manage.categoryNameRequired'.tr()
            : null,
        onFieldSubmitted: (value) {
          if (formKey.currentState?.validate() ?? false) {
            Navigator.of(dialogContext).pop(value.trim());
          }
        },
      ),
      onSubmit: (_) async => controller.text.trim(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final key = 'category-${category.id}';
    _setBusy(key, true);
    try {
      final updated = await api.renameManagementCategory(category.id, name);
      if (mounted) {
        setState(() {
          final index = _categories.indexWhere((item) => item.id == updated.id);
          if (index >= 0) _categories[index] = updated;
        });
        _syncCategoryCache();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _setCategoryActive(
    ManagementCategory category,
    bool active,
  ) async {
    final key = 'category-${category.id}';
    _setBusy(key, true);
    try {
      final updated = await api.setManagementCategoryActive(
        category.id,
        active,
      );
      if (mounted) {
        setState(() {
          final index = _categories.indexWhere((item) => item.id == updated.id);
          if (index >= 0) _categories[index] = updated;
        });
        _syncCategoryCache();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _archiveCategory(ManagementCategory category) async {
    final confirmed = await _confirmArchive(
      'manage.archiveCategoryTitle'.tr(),
      'manage.archiveCategoryMessage'.tr(namedArgs: {'name': category.name}),
    );
    if (!confirmed || !mounted) return;
    final key = 'category-${category.id}';
    _setBusy(key, true);
    try {
      final updated = await api.archiveManagementCategory(category.id);
      if (mounted) {
        setState(() {
          final index = _categories.indexWhere((item) => item.id == updated.id);
          if (index >= 0) _categories[index] = updated;
        });
        _syncCategoryCache();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _addCondition() async {
    final name = _conditionController.text.trim();
    if (name.isEmpty || _busyKeys.contains('condition-create')) return;
    _setBusy('condition-create', true);
    try {
      final condition = await api.createManagementCondition(name);
      if (!mounted) return;
      setState(() {
        _conditions = [..._conditions, condition]
          ..sort((a, b) => a.code.compareTo(b.code));
        _conditionController.clear();
      });
      _syncConditionCache();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy('condition-create', false);
    }
  }

  Future<void> _editCondition(ManagementCondition condition) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: _conditionName(condition.code),
    );
    final name = await showMarketplaceFormDialog<String>(
      context: context,
      title: 'manage.renameCondition'.tr(),
      formKey: formKey,
      onClosed: controller.dispose,
      content: (dialogContext) => MKTextFormField(
        controller: controller,
        autofocus: true,
        maxLength: 30,
        decoration: InputDecoration(labelText: 'manage.conditionName'.tr()),
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'manage.conditionNameRequired'.tr()
            : null,
        onFieldSubmitted: (value) {
          if (formKey.currentState?.validate() ?? false) {
            Navigator.of(dialogContext).pop(value.trim());
          }
        },
      ),
      onSubmit: (_) async => controller.text.trim(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final key = 'condition-${condition.code}';
    _setBusy(key, true);
    try {
      final updated = await api.renameManagementCondition(condition.code, name);
      if (mounted) {
        setState(() {
          final index = _conditions.indexWhere(
            (item) => item.code == condition.code,
          );
          if (index >= 0) _conditions[index] = updated;
          _conditions.sort((a, b) => a.code.compareTo(b.code));
        });
        _syncConditionCache();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _setConditionActive(
    ManagementCondition condition,
    bool active,
  ) async {
    final key = 'condition-${condition.code}';
    _setBusy(key, true);
    try {
      final updated = await api.setManagementConditionActive(
        condition.code,
        active,
      );
      if (mounted) {
        setState(() {
          final index = _conditions.indexWhere(
            (item) => item.code == updated.code,
          );
          if (index >= 0) _conditions[index] = updated;
        });
        _syncConditionCache();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<void> _archiveCondition(ManagementCondition condition) async {
    final confirmed = await _confirmArchive(
      'manage.archiveConditionTitle'.tr(),
      'manage.archiveConditionMessage'.tr(
        namedArgs: {'name': _conditionName(condition.code)},
      ),
    );
    if (!confirmed || !mounted) return;
    final key = 'condition-${condition.code}';
    _setBusy(key, true);
    try {
      final updated = await api.archiveManagementCondition(condition.code);
      if (mounted) {
        setState(() {
          final index = _conditions.indexWhere(
            (item) => item.code == condition.code,
          );
          if (index >= 0) _conditions[index] = updated;
        });
        _syncConditionCache();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  Future<bool> _confirmArchive(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('manage.archive'.tr()),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _setPostAvailable(ManagementPost post, bool available) async {
    final key = 'post-${post.id}';
    _setBusy(key, true);
    try {
      final updated = await api.setManagementPostAvailable(post.id, available);
      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((item) => item.id == updated.id);
          if (index >= 0) _posts[index] = updated;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) _setBusy(key, false);
    }
  }

  void _moveSection(int offset) {
    final sections = _availableSections;
    if (sections.isEmpty || _selected == null) return;
    final index = sections.indexWhere((item) => item.section == _selected);
    final target = (index + offset).clamp(0, sections.length - 1);
    _select(sections[target].section);
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'profile.management'.tr(),
        showManagement: false,
        showProfileAvatar: false,
        actions: [
          if (_account?.canViewReports == true)
            IconButton(
              tooltip: 'profile.reports'.tr(),
              onPressed: () => context.push('/reports'),
              icon: const Icon(Icons.insert_chart_outlined_rounded),
            ),
          if (_account?.canAccessPayroll == true)
            IconButton(
              tooltip: 'manage.payroll'.tr(),
              onPressed: () => context.push('/payroll'),
              icon: const Icon(Icons.payments_outlined),
            ),
        ],
      ).build(context),
      body: Material(
        color: StyleColor.canvas,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final railWidth = constraints.maxWidth < 480 ? 56.0 : 68.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: railWidth,
                        child: _ManagementRail(
                          selected: _selected,
                          sections: _availableSections,
                          canAccessPayroll: _account?.canAccessPayroll == true,
                          onSelect: _select,
                          onOpenPayroll: () => context.push('/payroll'),
                        ),
                      ),
                      const VerticalDivider(width: 1, color: StyleColor.line),
                      Expanded(
                        child: _workspace(constraints.maxWidth - railWidth),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _workspace(double availableWidth) {
    if (_account?.canAccessManagement != true) {
      return _ManagementAccessRequired();
    }
    final readOnlyStaff = _account != null && _availableSections.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: readOnlyStaff
              ? _ReadOnlyOverview()
              : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _LoadError(error: _error!, onRetry: _refresh)
              : SingleChildScrollView(
                  child: SafeArea(
                    bottom: true,
                    child: Column(
                      children: [
                        SizedBox(child: _sectionContent()),
                        _ManagementFooter(
                          canGoBack: _canMove(-1),
                          canGoNext: _canMove(1),
                          saveLabel:
                              _selected == _ManagementSection.categories &&
                                  _account?.canManageCategories == true
                              ? 'manage.saveCategory'.tr()
                              : _selected == _ManagementSection.conditions &&
                                    _account?.canManageConditions == true
                              ? 'manage.saveCondition'.tr()
                              : null,
                          onBack: () => _moveSection(-1),
                          onNext: () => _moveSection(1),
                          onSave: _selected == _ManagementSection.categories
                              ? (_categoryController.text.trim().isEmpty
                                    ? null
                                    : _addCategory)
                              : _selected == _ManagementSection.conditions
                              ? (_conditionController.text.trim().isEmpty
                                    ? null
                                    : _addCondition)
                              : null,
                          saving:
                              _busyKeys.contains('category-create') ||
                              _busyKeys.contains('condition-create'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  bool _canMove(int offset) {
    final sections = _availableSections;
    if (_selected == null || sections.length < 2) return false;
    final index = sections.indexWhere((item) => item.section == _selected);
    return index + offset >= 0 && index + offset < sections.length;
  }

  Widget _sectionContent() {
    switch (_selected) {
      case _ManagementSection.users:
        return _usersView();
      case _ManagementSection.categories:
        return _categoriesView();
      case _ManagementSection.conditions:
        return _conditionsView();
      case _ManagementSection.posts:
        return _postsView();
      case null:
        return _ReadOnlyOverview();
    }
  }

  Widget _usersView() => ManagementPanel(
    title: 'manage.userView'.tr(),
    icon: Icons.people_alt_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_account?.canManageRoles == true) ...[
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _createManagedUser,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('manage.createUser'.tr()),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_users.isEmpty)
          EmptyState(
            title: 'manage.noUsersTitle'.tr(),
            message: 'manage.noUsersMessage'.tr(),
            icon: Icons.people_outline_rounded,
          )
        else
          ManagementDataGrid(
            columns: [
              ManagementGridColumn(
                name: 'user',
                label: 'manage.headerUser'.tr(),
                width: 270,
              ),
              ManagementGridColumn(
                name: 'role',
                label: 'manage.headerRole'.tr(),
                width: 220,
              ),
              ManagementGridColumn(
                name: 'account',
                label: 'manage.headerAccount'.tr(),
                width: 190,
              ),
              ManagementGridColumn(
                name: 'selling',
                label: 'manage.headerSelling'.tr(),
                width: 200,
              ),
            ],
            rows: [
              for (final user in _users)
                [
                  _userIdentity(user),
                  _roleLabel(user),
                  _switchControl(
                    key: 'user-${user.profile.id}-active',
                    value: user.active,
                    label: user.active
                        ? 'manage.active'.tr()
                        : 'manage.disabled'.tr(),
                    onChanged: (value) => _updateUser(user, active: value),
                  ),
                  _switchControl(
                    key: 'user-${user.profile.id}-sell',
                    value: user.canSell,
                    label: user.canSell
                        ? 'manage.enabled'.tr()
                        : 'manage.disabled'.tr(),
                    onChanged: (value) => _updateUser(user, canSell: value),
                  ),
                ],
            ],
          ),
      ],
    ),
  );

  Widget _userIdentity(Account user) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      UserAvatar(profile: user.profile, radius: 19),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              user.email ?? user.profile.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StyleColor.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _roleLabel(Account user) {
    final labels = user.roles
        .map((role) => role.replaceFirst('ROLE_', '').replaceAll('_', ' '))
        .join(', ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            labels.isEmpty ? 'manage.roleFallback'.tr() : labels,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StyleColor.muted, fontSize: 12),
          ),
        ),
        if (_account?.canManageRoles == true &&
            !user.roles.contains('ROLE_ADMIN'))
          PopupMenuButton<String>(
            tooltip: 'manage.assignStaffRole'.tr(),
            enabled: !_busyKeys.contains('user-${user.profile.id}-role'),
            onSelected: (roleName) => _updateUserRole(user, roleName),
            itemBuilder: (context) => [
              for (final option in _managementRoleOptions)
                PopupMenuItem(value: option.$1, child: Text(option.$2.tr())),
            ],
          ),
      ],
    );
  }

  Widget _switchControl({
    required String key,
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      Switch.adaptive(
        value: value,
        onChanged: _busyKeys.contains(key) ? null : onChanged,
        activeTrackColor: StyleColor.teal,
      ),
    ],
  );

  Widget _categoriesView() => ManagementPanel(
    title: 'manage.categoryView'.tr(),
    icon: Icons.category_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ResponsiveRow(
              children: [
                ResponsiveColumn.span(
                  span: 12,
                  child: MKTextFormField(
                    controller: _categoryController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'manage.newCategory'.tr(),
                      hintText: 'manage.newCategoryHint'.tr(),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _addCategory(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _categories.isEmpty
            ? EmptyState(
                title: 'manage.noCategoriesTitle'.tr(),
                message: 'manage.noCategoriesMessage'.tr(),
                icon: Icons.category_outlined,
              )
            : ManagementDataGrid(
                columns: [
                  ManagementGridColumn(
                    name: 'name',
                    label: 'manage.headerCategory'.tr(),
                    width: 320,
                  ),
                  ManagementGridColumn(
                    name: 'availability',
                    label: 'common.status'.tr(),
                    width: 210,
                  ),
                  ManagementGridColumn(
                    name: 'actions',
                    label: 'common.actions'.tr(),
                    width: 240,
                  ),
                ],
                rows: [
                  for (final category in _categories)
                    [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      _statusLabel(
                        category.active,
                        enabledText: 'manage.availableToSellers'.tr(),
                        disabledText: 'manage.hiddenFromNewListings'.tr(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'manage.renameCategory'.tr(),
                            onPressed:
                                _busyKeys.contains('category-${category.id}')
                                ? null
                                : () => _editCategory(category),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'manage.archiveCategory'.tr(),
                            onPressed:
                                !category.active ||
                                    _busyKeys.contains(
                                      'category-${category.id}',
                                    )
                                ? null
                                : () => _archiveCategory(category),
                            icon: const Icon(Icons.archive_outlined),
                          ),
                          _switchControl(
                            key: 'category-${category.id}',
                            value: category.active,
                            label: category.active
                                ? 'manage.on'.tr()
                                : 'manage.off'.tr(),
                            onChanged: (value) =>
                                _setCategoryActive(category, value),
                          ),
                        ],
                      ),
                    ],
                ],
              ),
      ],
    ),
  );

  Widget _conditionsView() => ManagementPanel(
    title: 'manage.conditionView'.tr(),
    icon: Icons.fact_check_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ResponsiveRow(
              children: [
                ResponsiveColumn.span(
                  span: 12,
                  child: MKTextFormField(
                    controller: _conditionController,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'manage.newCondition'.tr(),
                      hintText: 'manage.newConditionHint'.tr(),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _addCondition(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _conditions.isEmpty
            ? EmptyState(
                title: 'manage.noConditionsTitle'.tr(),
                message: 'manage.noConditionsMessage'.tr(),
                icon: Icons.fact_check_outlined,
              )
            : ManagementDataGrid(
                columns: [
                  ManagementGridColumn(
                    name: 'condition',
                    label: 'manage.headerCondition'.tr(),
                    width: 260,
                  ),
                  ManagementGridColumn(
                    name: 'status',
                    label: 'common.status'.tr(),
                    width: 210,
                  ),
                  ManagementGridColumn(
                    name: 'actions',
                    label: 'common.actions'.tr(),
                    width: 240,
                  ),
                ],
                rows: [
                  for (final condition in _conditions)
                    [
                      Text(
                        _conditionName(condition.code),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      _statusLabel(
                        condition.active,
                        enabledText: 'manage.availableToSellers'.tr(),
                        disabledText: 'manage.unavailableForListings'.tr(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'manage.renameCondition'.tr(),
                            onPressed:
                                _busyKeys.contains(
                                  'condition-${condition.code}',
                                )
                                ? null
                                : () => _editCondition(condition),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'manage.archiveCondition'.tr(),
                            onPressed:
                                !condition.active ||
                                    _busyKeys.contains(
                                      'condition-${condition.code}',
                                    )
                                ? null
                                : () => _archiveCondition(condition),
                            icon: const Icon(Icons.archive_outlined),
                          ),
                          _switchControl(
                            key: 'condition-${condition.code}',
                            value: condition.active,
                            label: condition.active
                                ? 'manage.on'.tr()
                                : 'manage.off'.tr(),
                            onChanged: (value) =>
                                _setConditionActive(condition, value),
                          ),
                        ],
                      ),
                    ],
                ],
              ),
      ],
    ),
  );

  void _syncConditionCache() => api.updateMarketplaceConditionCodes(
    _conditions
        .where((condition) => condition.active)
        .map((condition) => condition.code),
  );

  Widget _postsView() {
    return ManagementPanel(
      title: 'manage.postView'.tr(),
      icon: Icons.article_outlined,
      child: _posts.isEmpty
          ? EmptyState(
              title: 'manage.noPostsTitle'.tr(),
              message: 'manage.noPostsMessage'.tr(),
              icon: Icons.article_outlined,
            )
          : ManagementDataGrid(
              columns: [
                ManagementGridColumn(
                  name: 'post',
                  label: 'manage.headerPost'.tr(),
                  width: 120,
                ),
                ManagementGridColumn(
                  name: 'author',
                  label: 'manage.headerAuthor'.tr(),
                  width: 130,
                ),
                ManagementGridColumn(
                  name: 'caption',
                  label: 'manage.headerCaption'.tr(),
                  width: 360,
                ),
                ManagementGridColumn(
                  name: 'date',
                  label: 'manage.headerCreated'.tr(),
                  width: 180,
                ),
                ManagementGridColumn(
                  name: 'availability',
                  label: 'manage.headerVisibility'.tr(),
                  width: 180,
                ),
              ],
              rows: [
                for (final post in _posts)
                  [
                    Text(
                      '#${post.id}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'manage.userRef'.tr(namedArgs: {'id': '${post.userId}'}),
                    ),
                    Text(
                      post.content.trim().isEmpty
                          ? 'manage.noCaption'.tr()
                          : post.content.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(_dateLabel(post.createdAt)),
                    _switchControl(
                      key: 'post-${post.id}',
                      value: !post.removed,
                      label: post.removed
                          ? 'manage.removed'.tr()
                          : 'manage.visible'.tr(),
                      onChanged: (available) =>
                          _setPostAvailable(post, available),
                    ),
                  ],
              ],
            ),
    );
  }

  Widget _statusLabel(
    bool active, {
    required String enabledText,
    required String disabledText,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        active ? Icons.check_circle_outline : Icons.pause_circle_outline,
        color: active ? StyleColor.success : StyleColor.muted,
        size: 18,
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          active ? enabledText : disabledText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? StyleColor.success : StyleColor.muted,
          ),
        ),
      ),
    ],
  );

  String _dateLabel(DateTime? value) {
    if (value == null) return 'manage.dateUnavailable'.tr();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _conditionName(String code) => switch (code) {
    'LIKE_NEW' => 'condition.LIKE_NEW'.tr(),
    _ =>
      code
          .split('_')
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0]}${part.substring(1).toLowerCase()}',
          )
          .join(' '),
  };
}

class _ManagementRail extends StatelessWidget {
  const _ManagementRail({
    required this.selected,
    required this.sections,
    required this.canAccessPayroll,
    required this.onSelect,
    required this.onOpenPayroll,
  });

  final _ManagementSection? selected;
  final List<_SectionSpec> sections;
  final bool canAccessPayroll;
  final ValueChanged<_ManagementSection> onSelect;
  final VoidCallback onOpenPayroll;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final spec in sections)
            _railItem(
              icon: spec.icon,
              tooltip: spec.labelKey.tr(),
              selected: selected == spec.section,
              onTap: () => onSelect(spec.section),
            ),
          if (sections.isEmpty && !canAccessPayroll)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.lock_outline_rounded, color: StyleColor.muted),
            ),
          if (canAccessPayroll) ...[
            const Spacer(),
            _railItem(
              icon: Icons.payments_outlined,
              tooltip: 'manage.payroll'.tr(),
              selected: false,
              onTap: onOpenPayroll,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _railItem({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: selected ? StyleColor.sand : Colors.transparent,
          foregroundColor: selected ? StyleColor.ink : StyleColor.muted,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
      ),
    ),
  );
}

class _ManagementFooter extends StatelessWidget {
  const _ManagementFooter({
    required this.canGoBack,
    required this.canGoNext,
    required this.saveLabel,
    required this.onBack,
    required this.onNext,
    required this.onSave,
    required this.saving,
  });

  final bool canGoBack;
  final bool canGoNext;
  final String? saveLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10.0),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canGoBack)
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text('common.back'.tr()),
          ),
        if (canGoNext)
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('common.next'.tr()),
          ),
        if (saveLabel != null)
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saveLabel!),
          ),
      ],
    ),
  );
}

class _ReadOnlyOverview extends StatelessWidget {
  const _ReadOnlyOverview();

  @override
  Widget build(BuildContext context) => EmptyState(
    title: 'manage.welcomeTitle'.tr(),
    message: 'manage.welcomeMessage'.tr(),
    icon: Icons.admin_panel_settings_outlined,
  );
}

class _ManagementAccessRequired extends StatelessWidget {
  const _ManagementAccessRequired();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyState(
        title: 'manage.staffAccessRequired'.tr(),
        message: 'manage.staffAccessMessage'.tr(),
        icon: Icons.lock_outline_rounded,
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: StyleColor.muted,
          ),
          const SizedBox(height: 10),
          Text(
            Api.errorMessage(error),
            textAlign: TextAlign.center,
            style: const TextStyle(color: StyleColor.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    ),
  );
}
