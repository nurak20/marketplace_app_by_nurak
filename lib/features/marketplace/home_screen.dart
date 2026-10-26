import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_mobile/core/components/product_artwork.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/adaptive_safe_body.dart';
import '../../shell/bottom_navigation_visibility.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/marketplace_post_card.dart';
import '../../core/components/mk_button.dart';
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
    final ApiPage<MarketplacePost> page;
    try {
      page = await _posts;
    } catch (error) {
      if (mounted) showError(context, error);
      return;
    }
    if (!mounted) return;

    await hideBottomNavigationWhile(
      () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        builder: (sheetContext) => ProductSearchSheet(
          posts: page.items,
          onSelected: (post, product) {
            Navigator.of(sheetContext).pop();
            _openProduct(post, product);
          },
        ),
      ),
    );
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
    body: AdaptiveSafeBody(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
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
    ),
  );
}

typedef SearchEntry = (MarketplacePost post, Product product);

class ProductSearchSheet extends StatefulWidget {
  const ProductSearchSheet({
    super.key,
    required this.posts,
    required this.onSelected,
  });

  final List<MarketplacePost> posts;
  final void Function(MarketplacePost post, Product product) onSelected;

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final _controller = TextEditingController();

  late final List<SearchEntry> _all = [
    for (final post in widget.posts)
      for (final product in post.products)
        if (product.status != 'SOLD') (post, product),
  ];

  List<SearchEntry> get _results {
    final keyword = _controller.text.trim().toLowerCase();
    if (keyword.isEmpty) return _all;
    return _all.where((entry) {
      final product = entry.$2;
      return product.title.toLowerCase().contains(keyword) ||
          (product.description ?? '').toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.50;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final results = _results;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height - keyboard < 240 ? 240 : height - keyboard,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: StyleColor.muted.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search for products',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(color: StyleColor.muted),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final (post, product) = results[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => widget.onSelected(post, product),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: ProductArtwork(
                                category: product.category,
                                height: 56,
                                image: product.primaryImage,
                              ),
                            ),
                          ),
                          title: Text(
                            product.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: StyleFont.largeSize,
                            ),
                          ),
                          subtitle: Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: StyleFont.mediumSize,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
