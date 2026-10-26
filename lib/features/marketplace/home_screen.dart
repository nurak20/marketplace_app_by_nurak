import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../shell/bottom_navigation_visibility.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/marketplace_post_card.dart';
import '../../core/components/show_error.dart';
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

  Future<void> _openSearch() async {
    await hideBottomNavigationWhile(() => context.push<void>('/search'));
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
        .where((post) => post.products.isNotEmpty)
        .toList();
  }

  Widget _categoryTile(MarketplaceCategory item) {
    final selected = _category == item.name;
    final color = selected ? _darkGreen : StyleColor.ink;

    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
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
                  item.name,
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

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: MarketplaceAppBar(
      title: 'Nurak MK27',
      actions: [
        AdaptiveAppBarAction(
          iosSymbol: 'magnifyingglass',
          icon: Icons.search_rounded,
          label: 'Search',
          onPressed: _openSearch,
        ),
      ],
    ).build(context),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 110),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: marketplaceCategoryItems.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) =>
                          _categoryTile(marketplaceCategoryItems[index]),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),

          FutureBuilder<ApiPage<MarketplacePost>>(
            future: _posts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: ErrorRetryPanel(
                    error: snapshot.error!,
                    onRetry: _refresh,
                  ),
                );
              }
              final posts = _filterPosts(snapshot.data?.items ?? const []);
              if (posts.isEmpty) {
                return const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 260,
                    child: EmptyState(
                      title: 'No listings yet',
                      message:
                          'Try another category or be the first to list something.',
                      icon: Icons.storefront_outlined,
                    ),
                  ),
                );
              }
              return SliverList.separated(
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 5),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return MarketplacePostCard(
                    key: ValueKey(post.id),
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
              );
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: StyleSpacing.bottomContentClearance),
          ),
        ],
      ),
    ),
  );
}
