import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/choose_image_bottom_sheet.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/form_dialog.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/language_button.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/marketplace_post_card.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';
import '../../core/session_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Account? _account;
  List<MarketplacePost> _listings = const [];
  bool _loading = true;
  Object? _error;
  final Map<int, bool> _savedOverrides = {};
  final Set<(int, int)> _likingIds = {};
  final Map<(int, int), bool> _likedOverrides = {};
  final Map<(int, int), int> _likeCountOverrides = {};
  int? _savingId;
  @override
  void initState() {
    super.initState();
    _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final (account, listings) = await _fetch();
      if (!mounted) return;
      setState(() {
        _account = account;
        _listings = listings;
        _loading = false;
        _error = null;
        _savedOverrides.clear();
        _likedOverrides.clear();
        _likeCountOverrides.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
      if (_account != null) showError(context, error);
    }
  }

  Future<(Account, List<MarketplacePost>)> _fetch() async {
    final account = await api.me();
    final posts = await api.posts(userId: account.profile.id);
    final ownPosts = posts.items
        .where((post) => post.userId == account.profile.id)
        .toList();
    return (account, ownPosts);
  }

  Future<void> _logout() async {
    final shouldLogout = await GlobalPopupDialog.yesNoPrompt(
      context,
      title: 'profile.logoutTitle'.tr(),
      message: 'profile.logoutMessage'.tr(),
      yesText: 'profile.logout'.tr(),
      noText: 'common.cancel'.tr(),
    );
    if (shouldLogout != true || !mounted) return;
    await SessionStore.instance.clear();
    if (mounted) context.go('/login');
  }

  Future<void> _toggleSaved(Product product) async {
    if (_savingId != null) return;
    final wasSaved = _savedOverrides[product.id] ?? product.isSaved;
    setState(() {
      _savingId = product.id;
      _savedOverrides[product.id] = !wasSaved;
    });
    try {
      if (wasSaved) {
        await api.removeSavedProduct(product.id);
      } else {
        await api.saveProduct(product.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _savedOverrides[product.id] = wasSaved);
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _toggleLike(MarketplacePost post, Product product) async {
    final key = (post.id, product.id);
    if (_likingIds.contains(key)) return;
    final engagement = post.engagementFor(product);
    final wasLiked = _likedOverrides[key] ?? engagement.hasReacted;
    final count = _likeCountOverrides[key] ?? engagement.reactionCount;
    setState(() {
      _likingIds.add(key);
      _likedOverrides[key] = !wasLiked;
      _likeCountOverrides[key] = count + (wasLiked ? -1 : 1);
    });
    try {
      if (wasLiked) {
        await api.unreactToPostProduct(post.id, product.id);
      } else {
        await api.reactToPostProduct(post.id, product.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _likedOverrides[key] = wasLiked;
          _likeCountOverrides[key] = count;
        });
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _likingIds.remove(key));
    }
  }

  Future<void> _openProduct(MarketplacePost post, Product product) async {
    await context.push('/products/${product.id}?postId=${post.id}');
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _openComments(MarketplacePost post, Product product) async {
    await context.push('/posts/${post.id}/products/${product.id}/comments');
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _chooseAvatar() async {
    if (!await showChooseImageBottomSheet(context) || !mounted) return;

    XFile? image;
    try {
      image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
    } catch (error) {
      if (mounted) showError(context, error);
      return;
    }
    if (image == null || !mounted) return;

    try {
      final updated = await GlobalPopupDialog.withLoading(
        context,
        () => api.uploadAvatar(image!),
        message: 'profile.uploadingPhoto'.tr(),
      );
      if (!mounted) return;
      setState(() {
        _account = updated;
      });
      await GlobalPopupDialog.success(
        context,
        message: 'profile.photoUpdated'.tr(),
      );
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    }
  }

  Future<void> _editProfile(Account account) async {
    final formKey = GlobalKey<FormState>();
    final firstName = TextEditingController(
      text: account.profile.firstNameText,
    );
    final lastName = TextEditingController(text: account.profile.lastNameText);
    final email = TextEditingController(text: account.email ?? '');
    final phone = TextEditingController(text: account.phone ?? '');

    final updated = await showMarketplaceFormDialog<Account>(
      context: context,
      title: 'profile.edit'.tr(),
      formKey: formKey,
      submitLabel: 'common.saveChanges'.tr(),
      submitIcon: Icons.save_outlined,
      onClosed: () {
        firstName.dispose();
        lastName.dispose();
        email.dispose();
        phone.dispose();
      },
      content: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          MKTextFormField(
            controller: firstName,
            maxLength: 50,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: InputDecoration(
              labelText: 'profile.firstName'.tr(),
              counterText: '',
            ),
          ),
          MKTextFormField(
            controller: lastName,
            maxLength: 50,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            decoration: InputDecoration(
              labelText: 'profile.lastName'.tr(),
              counterText: '',
            ),
          ),
          MKTextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: 'profile.email'.tr()),
            validator: _validateEmail,
          ),
          MKTextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'profile.phone'.tr(),
              hintText: 'profile.optional'.tr(),
              counterText: '',
            ),
            validator: _validatePhone,
          ),
        ],
      ),
      onSubmit: (_) {
        final first = firstName.text.trim();
        final last = lastName.text.trim();
        if (first.isEmpty && last.isEmpty) {
          throw _ProfileMessage('profile.nameRequired'.tr());
        }
        return api.updateProfile(
          firstName: first,
          lastName: last,
          email: email.text.trim(),
          phone: phone.text.trim(),
        );
      },
    );
    if (updated == null || !mounted) return;
    setState(() {
      _account = updated;
    });
    await GlobalPopupDialog.success(context, message: 'profile.updated'.tr());
  }

  static String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'profile.emailRequired'.tr();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : 'profile.emailInvalid'.tr();
  }

  static String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return RegExp(r'^\+?[0-9 ()\-]{6,19}$').hasMatch(text)
        ? null
        : 'profile.phoneInvalid'.tr();
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'profile.title'.tr(),
        showNotifications: false,
        showProfileAvatar: false,
      ).build(context),
      body: _buildBody(context),
    ),
  );

  Widget _buildBody(BuildContext context) {
    final account = _account;
    if (account == null) {
      if (_loading) return const SizedBox.shrink();
      return _ProfileError(
        error: _error ?? StateError('profile.unavailable'.tr()),
        onRetry: () => _load(),
      );
    }
    final listings = _listings;
    final user = account.profile;
    final position = _positionName(account.roles);
    final listingCount = listings.fold<int>(
      0,
      (total, post) => total + post.products.length,
    );
    final avatarUrl = user.avatar?.url;
    final name = user.displayName;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: StyleColor.accent,
                            child: avatarUrl?.isNotEmpty == true
                                ? ClipOval(
                                    child: Image.network(
                                      api.resolveUrl(avatarUrl!),
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _AvatarInitials(initials),
                                    ),
                                  )
                                : _AvatarInitials(initials),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: StyleColor.ink,
                              shape: const CircleBorder(),
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: _chooseAvatar,
                                  tooltip: 'profile.choosePhoto'.tr(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: StyleColor.iconSize,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: StyleFont.largeSize,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                position,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: StyleColor.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          if (user.location?.isNotEmpty == true) user.location!,
                          if (account.email?.isNotEmpty == true) account.email!,
                          if (account.phone?.isNotEmpty == true) account.phone!,
                        ].join('  ·  '),
                        style: const TextStyle(color: StyleColor.muted),
                      ),
                      if (user.bio?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(user.bio!),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _editProfile(account),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text('profile.edit'.tr()),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/me/change-password'),
                              icon: const Icon(Icons.lock_reset_rounded),
                              label: Text('profile.changePassword'.tr()),
                            ),
                            OutlinedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded),
                              label: Text('profile.logout'.tr()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatCard(
                            label: 'profile.listings'.tr(),
                            value: '$listingCount',
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            label: 'profile.member'.tr(),
                            value: 'profile.active'.tr(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const LanguageButton(),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/me/payslips'),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text('profile.myPayslips'.tr()),
                          ),
                          if (account.canViewReports)
                            FilledButton.icon(
                              onPressed: () => context.push('/reports'),
                              icon: const Icon(
                                Icons.insert_chart_outlined_rounded,
                              ),
                              label: Text('profile.reports'.tr()),
                            ),
                          if (account.canAccessPayroll)
                            FilledButton.icon(
                              onPressed: () => context.push('/payroll'),
                              icon: const Icon(Icons.payments_outlined),
                              label: Text('profile.payrollWorkspace'.tr()),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'profile.yourListings'.tr(),
                        style: const TextStyle(
                          fontSize: StyleFont.largeSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (listings.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  title: 'profile.noListings'.tr(),
                  message: 'profile.noListingsMessage'.tr(),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final post = listings[index];
                return MarketplacePostCard(
                  key: ValueKey('profile-post-${post.id}'),
                  post: post,
                  isLiked: (post, product) =>
                      _likedOverrides[(post.id, product.id)] ??
                      post.engagementFor(product).hasReacted,
                  likeCount: (post, product) =>
                      _likeCountOverrides[(post.id, product.id)] ??
                      post.engagementFor(product).reactionCount,
                  isLiking: (post, product) =>
                      _likingIds.contains((post.id, product.id)),
                  onLike: _toggleLike,
                  onComment: _openComments,
                  isSaved: (product) =>
                      _savedOverrides[product.id] ?? product.isSaved,
                  onSave: _toggleSaved,
                  onProductTap: _openProduct,
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  String _positionName(List<String> roles) {
    const knownNames = {
      'ROLE_SUPER_ADMIN': 'profile.roleSuperAdmin',
      'ROLE_ADMIN': 'profile.roleAdmin',
      'ROLE_MANAGER': 'profile.roleManager',
      'ROLE_HR': 'profile.roleHr',
      'ROLE_EMPLOYEE': 'profile.roleEmployee',
      'ROLE_USER': 'profile.roleUser',
    };
    const priority = [
      'ROLE_SUPER_ADMIN',
      'ROLE_ADMIN',
      'ROLE_MANAGER',
      'ROLE_HR',
      'ROLE_EMPLOYEE',
      'ROLE_USER',
    ];
    final roleSet = roles.map((role) => role.toUpperCase()).toSet();
    for (final role in priority) {
      if (roleSet.contains(role)) return knownNames[role]!.tr();
    }
    final role = roleSet.isEmpty ? null : roleSet.first;
    if (role == null) return 'profile.roleUser'.tr();
    return role
        .replaceFirst('ROLE_', '')
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0]}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials(this.initials);
  final String initials;

  @override
  Widget build(BuildContext context) => Text(
    initials,
    style: const TextStyle(
      fontSize: StyleFont.largeSize,
      fontWeight: FontWeight.w400,
      color: StyleColor.ink,
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: StyleFont.largeSize,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: StyleColor.muted,
                fontSize: StyleFont.mediumSize,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          size: StyleColor.iconSize,
          color: StyleColor.muted,
        ),
        const SizedBox(height: 10),
        Text(Api.errorMessage(error)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text('profile.tryAgain'.tr()),
        ),
      ],
    ),
  );
}

class _ProfileMessage implements Exception {
  const _ProfileMessage(this.message);

  final String message;

  @override
  String toString() => message;
}
