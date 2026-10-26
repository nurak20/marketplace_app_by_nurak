import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_mobile/core/components/adaptive_safe_body.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/choose_image_bottom_sheet.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/mk_button.dart';
import '../../core/components/product_card.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';
import '../../core/singleton.dart';
import '../../core/session_store.dart';

typedef _Listing = ({MarketplacePost post, Product product});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<(Account, List<_Listing>)> _profile;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = _fetch();
  }

  Future<(Account, List<_Listing>)> _fetch() async {
    final account = Singleton.instance.account;
    if (account == null) {
      throw StateError('The signed-in account is unavailable.');
    }
    final posts = await api.posts(userId: account.profile.id);
    final listings = [
      for (final post in posts.items)
        for (final product in post.products) (post: post, product: product),
    ];
    return (account, listings);
  }

  Future<void> _logout() async {
    final shouldLogout = await GlobalPopupDialog.yesNoPrompt(
      context,
      title: 'Log out?',
      message: 'Are you sure you want to log out?',
      yesText: 'Log out',
      noText: 'Cancel',
    );
    if (shouldLogout != true || !mounted) return;
    await SessionStore.instance.clear();
    if (mounted) context.go('/login');
  }

  Future<void> _openProduct(int id, int postId) async {
    await context.push('/products/$id?postId=$postId');
    if (mounted) {
      setState(() {
        _load();
      });
    }
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
      final previous = await _profile;
      if (!mounted) return;
      final updated = await GlobalPopupDialog.withLoading(
        context,
        () => api.uploadAvatar(image!),
        message: 'Uploading profile photo...',
      );
      if (!mounted) return;
      setState(() {
        _profile = Future.value((updated, previous.$2));
      });
      await GlobalPopupDialog.success(
        context,
        message: 'Profile photo updated.',
      );
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(
      title: 'Chat',
      showNotifications: false,
      showProfileAvatar: false,
    ).build(context),
    body: AdaptiveSafeBody(
      child: FutureBuilder<(Account, List<_Listing>)>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return _ProfileError(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }
          final (account, listings) = snapshot.data!;
          final user = account.profile;
          final avatarUrl = user.avatar?.url;
          final name = user.displayName;
          final initials = name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
              .join();
          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _profile;
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [
                                StyleColor.ink,
                                StyleColor.teal,
                                StyleColor.accent,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -36),
                          child: Row(
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
                                          tooltip: 'Choose profile photo',
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
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: StyleFont.largeSize,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  if (user.location?.isNotEmpty == true)
                                    user.location!,
                                  if (account.email?.isNotEmpty == true)
                                    account.email!,
                                ].join('  ·  '),
                                style: const TextStyle(color: StyleColor.muted),
                              ),
                              if (user.bio?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(user.bio!),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _StatCard(
                                    label: 'Listings',
                                    value: '${listings.length}',
                                  ),
                                  const SizedBox(width: 10),
                                  _StatCard(label: 'Member', value: 'Active'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Your listings',
                                style: TextStyle(
                                  fontSize: StyleFont.largeSize,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (listings.isEmpty)
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: EmptyState(
                        title: 'No products yet',
                        message: 'Your listings will show up here.',
                        icon: Icons.storefront_outlined,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
                    sliver: SliverGrid.builder(
                      itemCount: listings.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: .74,
                          ),
                      itemBuilder: (context, index) => ProductCard(
                        product: listings[index].product,
                        onTap: () => _openProduct(
                          listings[index].product.id,
                          listings[index].post.id,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: StyleSpacing.bottomContentClearance),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
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
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
