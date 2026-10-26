import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/adaptive_safe_body.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/mk_button.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';
import '../../core/singleton.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, this.postId});
  final int productId;
  final int? postId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Product> _product;
  bool? _savedOverride;
  bool _saving = false;
  bool _updatingStatus = false;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _imageIndex = 0;
    _product = _loadProduct();
  }

  Future<Product> _loadProduct() async {
    final postId = widget.postId;
    if (postId == null) return api.product(widget.productId);

    final post = await api.post(postId);
    for (final product in post.products) {
      if (product.id == widget.productId) return product;
    }
    throw StateError('Product is no longer part of this listing.');
  }

  Future<void> _toggleSaved(Product product) async {
    if (_saving) return;
    final wasSaved = _savedOverride ?? product.isSaved;
    setState(() {
      _saving = true;
      _savedOverride = !wasSaved;
    });
    try {
      if (wasSaved) {
        await api.removeSavedProduct(product.id);
      } else {
        await api.saveProduct(product.id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _savedOverride = wasSaved);
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markSold(Product product) async {
    setState(() => _updatingStatus = true);
    try {
      await api.setProductStatus(product.id, 'SOLD');
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Widget _sellerAvatar(UserProfile? seller) {
    final avatar = seller?.avatar;
    final hasAvatar = avatar?.url.isNotEmpty == true;
    return CircleAvatar(
      radius: 26,
      backgroundColor: StyleColor.canvas,
      backgroundImage: hasAvatar
          ? NetworkImage(api.resolveUrl(avatar!.url))
          : null,
      onBackgroundImageError: hasAvatar ? (_, _) {} : null,
      child: hasAvatar
          ? null
          : const Icon(Icons.person_outline, color: StyleColor.ink),
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(
      title: 'Product details',
      showNotifications: false,
      showProfileAvatar: false,
    ).build(context),
    body: AdaptiveSafeBody(
      child: FutureBuilder<Product>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return ErrorRetryPanel(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }

          final product = snapshot.data!;
          final seller = product.seller;
          final currentUserId = Singleton.instance.account?.profile.id;
          final ownProduct = currentUserId == product.sellerId;
          final chatRoute =
              '/chats/${product.sellerId}?productId=${product.id}';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
            children: [
              _ProductImageGallery(
                product: product,
                currentIndex: _imageIndex,
                onPageChanged: (index) => setState(() => _imageIndex = index),
              ),
              const SizedBox(height: 18),
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: StyleFont.largeSize,
                  fontWeight: FontWeight.w400,
                  color: StyleColor.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.title,
                style: const TextStyle(
                  fontSize: StyleFont.largeSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _Tag(text: product.condition.replaceAll('_', ' ')),
                  if (product.category?.isNotEmpty == true)
                    _Tag(text: product.category!),
                  _Tag(
                    text: product.status.replaceAll('_', ' '),
                    highlight: product.status == 'SOLD',
                  ),
                ],
              ),
              if (product.location?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: StyleColor.iconSize,
                      color: StyleColor.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      product.location!,
                      style: const TextStyle(color: StyleColor.muted),
                    ),
                  ],
                ),
              ],
              if (product.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  product.description!,
                  style: const TextStyle(height: 1.45),
                ),
              ],
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: _sellerAvatar(seller),
                  title: Text(
                    seller?.displayName ?? 'Seller #${product.sellerId}',
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                  subtitle: seller?.location?.isNotEmpty == true
                      ? Text(seller!.location!)
                      : null,
                  trailing: ownProduct
                      ? null
                      : TextButton.icon(
                          onPressed: () => context.push(chatRoute),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Chat'),
                        ),
                  onTap: ownProduct ? null : () => context.push(chatRoute),
                ),
              ),
              const SizedBox(height: 12),
              if (ownProduct && product.status == 'AVAILABLE')
                PrimaryButton(
                  label: 'Mark as sold',
                  busy: _updatingStatus,
                  onPressed: () => _markSold(product),
                )
              else if (!ownProduct && product.status == 'SOLD')
                PrimaryButton(
                  label: 'Write a review',
                  onPressed: () => context.push('/reviews/${product.id}'),
                )
              else if (!ownProduct)
                PrimaryButton(
                  label: 'Message seller',
                  onPressed: () => context.push(chatRoute),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/products/${product.id}/reviews'),
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text('View reviews'),
              ),
              if (widget.postId != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/posts/${widget.postId}/products/${product.id}/comments',
                  ),
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: const Text('View comments'),
                ),
              ],
              const SizedBox(height: StyleSpacing.bottomContentClearance),
            ],
          );
        },
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: highlight
          ? StyleColor.accent.withValues(alpha: .25)
          : Colors.white,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: StyleFont.mediumSize,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

class _ProductImageGallery extends StatelessWidget {
  const _ProductImageGallery({
    required this.product,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final Product product;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final images = product.images;
    final imageCount = images.isEmpty ? 1 : images.length;

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: imageCount,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) => ProductArtwork(
                key: ValueKey((product.id, index)),
                category: product.category,
                image: images.isEmpty ? null : images[index],
                height: 260,
              ),
            ),
            if (imageCount > 1) ...[
              Positioned(
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    child: Text(
                      '${currentIndex + 1} / $imageCount',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    imageCount,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: currentIndex == index ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: currentIndex == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
