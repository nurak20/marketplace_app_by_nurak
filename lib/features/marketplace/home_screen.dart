import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_mobile/features/chats/chat_screens.dart';
import 'package:marketplace_mobile/features/marketplace/sell_screen.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/marketplace_post_card.dart';
import '../../core/components/show_error.dart';
import '../../core/l10n_labels.dart';
import '../../core/models.dart';
import 'marketplace_options.dart';

// Move this into StyleColor if you prefer (e.g. StyleColor.darkGreen).
const _darkGreen = Color(0xFF0B5D3B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';
  late Future<ApiPage<MarketplacePost>> _posts;
  final Map<int, bool> _savedOverrides = {};
  final Set<(int, int)> _likingIds = {};
  final Map<(int, int), bool> _likedOverrides = {};
  final Map<(int, int), int> _likeCountOverrides = {};
  int? _savingId;

  List<MarketplaceCategory> get _categoryItems {
    final names = api.marketplaceCategoryNames;
    return marketplaceItemsForCategories(
      names ?? marketplaceCategories.skip(1),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  void _loadPosts() {
    _savedOverrides.clear();
    _likedOverrides.clear();
    _likeCountOverrides.clear();
    _posts = api.posts();
    unawaited(_refreshCategoryItems(_posts));
  }

  Future<void> _refreshCategoryItems(
    Future<ApiPage<MarketplacePost>> request,
  ) async {
    try {
      await request;
      if (mounted) setState(() {});
    } catch (_) {
      // The page's FutureBuilder renders the request error.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadPosts();
    });
    await _posts;
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
        setState(() {
          _savedOverrides[product.id] = wasSaved;
        });
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
    if (mounted) {
      setState(() {
        _loadPosts();
      });
    }
  }

  Future<void> _openComments(MarketplacePost post, Product product) async {
    await context.push('/posts/${post.id}/products/${product.id}/comments');
    if (mounted) {
      setState(() {
        _loadPosts();
      });
    }
  }

  List<MarketplacePost> _filterPosts(List<MarketplacePost> posts) {
    return posts
        .map((post) {
          final products = post.products.where((product) {
            if (product.status == 'SOLD') return false;
            if (_category != 'All' && product.category != _category) {
              return false;
            }
            return true;
          }).toList();
          return post.withProducts(products);
        })
        .where((post) => post.isRemoved || post.products.isNotEmpty)
        .toList();
  }

  Widget _categoryTile(MarketplaceCategory item) {
    final selected = _category == item.name;
    final color = selected ? _darkGreen : StyleColor.ink;
    final label = categoryLabel(item.name);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? const BorderSide(color: _darkGreen, width: 0.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _category = item.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: StyleFont.mediumSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildProductList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  _categoryTile(_categoryItems[index]),
            ),
          ),
        ),

        FutureBuilder<ApiPage<MarketplacePost>>(
          future: _posts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              return ErrorRetryPanel(error: snapshot.error!, onRetry: _refresh);
            }
            final posts = _filterPosts(snapshot.data?.items ?? const []);
            if (posts.isEmpty) {
              return SizedBox(
                height: 260,
                child: EmptyState(
                  title: 'home.noListingsTitle'.tr(),
                  message: 'home.noListingsMessage'.tr(),
                  icon: Icons.storefront_outlined,
                ),
              );
            }
            return Column(
              children: [
                const SizedBox(height: 8),
                ...posts.map(
                  (e) => MarketplacePostCard(
                    key: ValueKey(e.id),
                    post: e,
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
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String get _title => switch (_selectedIndex) {
    0 => 'mk27 Management System',
    1 => 'nav.message'.tr(),
    2 => 'nav.create'.tr(),
    _ => 'nav.user'.tr(),
  };

  int _selectedIndex = 0;
  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(
      title: _title,
      actions: [
        AdaptiveAppBarAction(
          onPressed: () async {
            await context.pushNamed('notifications');
          },
          iosSymbol: 'bell', // SF Symbol, used on iOS 26+
          icon: Icons.notifications_outlined, // fallback
        ),
        AdaptiveAppBarAction(
          onPressed: () async {
            await context.pushNamed('search');
          },
          iosSymbol: 'magnifyingglass', // SF Symbol name, used on iOS 26+
          icon: Icons.search, // used on older iOS / fallback
          // androidIcon: Icons.search,         // used on Android (if your version has it)
        ),
      ],
    ),
    body: Material(
      color: Colors.white,
      child: ListView(
        children: [
          SizedBox(
            child: Column(
              children: [
                switch (_selectedIndex) {
                  0 => buildProductList(),
                  1 => const ChatsScreen(),
                  _ => const SellScreen(),
                },
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: AdaptiveBottomNavigationBar(
      useNativeBottomBar: true,

      selectedIndex: _selectedIndex,
      onTap: (index) {
        if (index == 3) {
          context.pushNamed('profile');
        } else if (mounted) {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      items: [
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'house.fill'
              : Icons.home_rounded,
          label: 'nav.home'.tr(),
        ),
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'bubble.left.fill'
              : Icons.chat_bubble_rounded,
          label: 'nav.message'.tr(),
        ),
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'plus.app.fill'
              : Icons.add_box_rounded,
          label: 'nav.create'.tr(),
        ),
        AdaptiveNavigationDestination(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'person.fill'
              : Icons.person_rounded,
          label: 'nav.user'.tr(),
        ),
      ],
    ),
  );
}
