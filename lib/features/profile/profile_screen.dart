import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/product_card.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';
import '../../core/profile_provider.dart';
import '../../core/session_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<(Account, ApiPage<Product>)> _profile;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool refreshProfile = false}) {
    _profile = _fetch(refreshProfile: refreshProfile);
  }

  Future<(Account, ApiPage<Product>)> _fetch({
    bool refreshProfile = false,
  }) async {
    final account = refreshProfile || profileProvider.account == null
        ? await api.me()
        : profileProvider.account!;
    final products = await api.products(sellerId: account.profile.id);
    return (account, products);
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

  Future<void> _openProduct(int id) async {
    await context.push('/products/$id');
    if (mounted) {
      setState(() {
        _load();
      });
    }
  }

  Future<void> _chooseAvatar() async {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Me'),
      actions: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          onPressed: _logout,
          tooltip: 'Log out',
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: FutureBuilder<(Account, ApiPage<Product>)>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ProfileError(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _load(refreshProfile: true);
            }),
          );
        }
        final (account, listings) = snapshot.data!;
        final user = account.profile;
        final name = user.displayName;
        final initials = name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
            .join();
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _load(refreshProfile: true);
            });
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
                                  child: user.avatarUrl?.isNotEmpty == true
                                      ? ClipOval(
                                          child: Image.network(
                                            api.resolveUrl(user.avatarUrl!),
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
                                  value: '${listings.items.length}',
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
              if (listings.items.isEmpty)
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
                    itemCount: listings.items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: .74,
                        ),
                    itemBuilder: (context, index) => ProductCard(
                      product: listings.items[index],
                      onTap: () => _openProduct(listings.items[index].id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
