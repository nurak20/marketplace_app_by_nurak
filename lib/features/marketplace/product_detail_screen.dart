import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/app_theme.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/product_card.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
import '../../core/l10n_labels.dart';
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
  final _commentComposer = TextEditingController();
  Product? _product;
  MarketplacePost? _post;
  bool _isLoading = true;
  Object? _loadError;
  int _loadGeneration = 0;
  PostComment? _replyTo;
  bool? _savedOverride;
  bool? _likedOverride;
  int? _likeCountOverride;
  bool _saving = false;
  bool _liking = false;
  bool _updatingStatus = false;
  bool _sendingComment = false;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _imageIndex = 0;
    _likedOverride = null;
    _likeCountOverride = null;
    _post = null;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    final postId = widget.postId;
    if (postId != null) unawaited(_loadPost(postId, generation));
    try {
      final product = await api.product(widget.productId, postId: postId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPost(int postId, int generation) async {
    try {
      final post = await api.post(postId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _post = post);
    } catch (_) {
      // Related listings are optional; keep the product detail available.
    }
  }

  Future<void> _sendComment() async {
    final postId = widget.postId;
    final content = _commentComposer.text.trim();
    if (postId == null || content.isEmpty || _sendingComment) return;

    setState(() => _sendingComment = true);
    try {
      await api.addProductPostComment(
        postId,
        widget.productId,
        content,
        parentId: _replyTo?.id,
      );
      if (!mounted) return;
      _commentComposer.clear();
      setState(() => _replyTo = null);
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _toggleSaved(Product product) async {
    final productId = product.id;
    if (_saving || productId == null) return;
    final wasSaved = _savedOverride ?? product.isSaved == true;
    setState(() {
      _saving = true;
      _savedOverride = !wasSaved;
    });
    try {
      if (wasSaved) {
        await api.removeSavedProduct(productId);
      } else {
        await api.saveProduct(productId);
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

  Future<void> _toggleLike(Product product) async {
    final postId = widget.postId;
    final productId = product.id;
    if (postId == null || productId == null || _liking) return;
    final wasLiked = _likedOverride ?? product.hasLiked == true;
    final count = _likeCountOverride ?? product.totalLike ?? 0;
    setState(() {
      _liking = true;
      _likedOverride = !wasLiked;
      _likeCountOverride = count + (wasLiked ? -1 : 1);
    });
    try {
      if (wasLiked) {
        await api.unreactToPostProduct(postId, productId);
      } else {
        await api.reactToPostProduct(postId, productId);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _likedOverride = wasLiked;
          _likeCountOverride = count;
        });
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _markSold(Product product) async {
    final productId = product.id;
    if (productId == null) return;
    setState(() => _updatingStatus = true);
    try {
      await api.setProductStatus(productId, 'SOLD');
      if (mounted) await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _writeReview(int productId) async {
    final added = await context.push<bool>('/reviews/$productId');
    if (added == true && mounted) await _load();
  }

  Widget _sellerAvatar(UserProfile? seller) {
    final avatar = seller?.avatar;
    final avatarUrl = avatar?.url;
    final hasAvatar = avatarUrl?.isNotEmpty == true;
    return CircleAvatar(
      radius: 26,
      backgroundColor: StyleColor.canvas,
      backgroundImage: hasAvatar
          ? NetworkImage(api.resolveUrl(avatarUrl!))
          : null,
      onBackgroundImageError: hasAvatar ? (_, _) {} : null,
      child: hasAvatar
          ? null
          : const Icon(Icons.person_outline, color: StyleColor.ink),
    );
  }

  Widget _reviewSection(Product product) {
    final reviews = product.reviews ?? const <Review>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'product.reviewsTitle'.tr(namedArgs: {'count': '${reviews.length}'}),
        ),
        if (reviews.isEmpty)
          _SectionMessage('product.noReviews'.tr())
        else
          ...reviews.map(
            (review) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < (review.rating ?? 0)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: StyleColor.iconSize,
                            color: StyleColor.accent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'product.buyerFallback'.tr(
                            namedArgs: {'id': '${review.buyerId}'},
                          ),
                          style: const TextStyle(color: StyleColor.muted),
                        ),
                      ],
                    ),
                    if (review.comment?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(review.comment!),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _commentTile(PostComment comment) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: StyleColor.canvas,
                  backgroundImage: comment.avatar?.url?.isNotEmpty == true
                      ? NetworkImage(api.resolveUrl(comment.avatar!.url!))
                      : null,
                  child: comment.avatar?.url?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person_outline_rounded, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content ?? ''),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _replyTo = comment),
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: Text('product.reply'.tr()),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (comment.replies?.isNotEmpty == true)
          Container(
            margin: const EdgeInsets.only(left: 16, top: 7),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: StyleColor.muted.withValues(alpha: .25),
                ),
              ),
            ),
            child: Column(
              children: (comment.replies ?? const <PostComment>[])
                  .map(_commentTile)
                  .toList(),
            ),
          ),
      ],
    ),
  );

  Widget _postProductsSection() {
    final post = _post;
    if (post == null) return const SizedBox.shrink();
    final products = post.products ?? const <Product>[];
    final others = products
        .where((item) => item.id != widget.productId)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    final content = post.content?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'product.otherItemsTitle'.tr(
            namedArgs: {'count': '${products.length}'},
          ),
        ),
        if (content != null && content.isNotEmpty) ...[
          Text(content, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: others.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = others[index];
              return SizedBox(
                width: 172,
                child: ProductCard(
                  product: item,
                  onTap: () => context.push(
                    '/products/${item.id ?? ''}?postId=${widget.postId}',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _commentsSection(Product product) {
    final comments = product.comments ?? const <PostComment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'product.commentsTitle'.tr(
            namedArgs: {'count': '${product.totalComment ?? 0}'},
          ),
        ),
        if (widget.postId == null)
          _SectionMessage('product.openFromListing'.tr())
        else if (comments.isEmpty)
          _SectionMessage('product.noComments'.tr())
        else
          ...comments.map(_commentTile),
        if (widget.postId != null) ...[
          if (_replyTo != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'product.replyingTo'.tr(
                      namedArgs: {'name': _replyTo!.displayName},
                    ),
                    style: const TextStyle(color: StyleColor.muted),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _replyTo = null),
                  tooltip: 'product.cancelReply'.tr(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MKTextFormField(
                  controller: _commentComposer,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (_) => _sendComment(),
                  decoration: InputDecoration(
                    hintText: _replyTo == null
                        ? 'product.addComment'.tr()
                        : 'product.writeReply'.tr(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendingComment ? null : _sendComment,
                tooltip: 'product.postComment'.tr(),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _productContent(Product product) {
    final seller = product.seller;
    final currentUserId = Singleton.instance.account?.profile?.id;
    final ownProduct = currentUserId == product.sellerId;
    final chatRoute =
        '/chats/${product.sellerId ?? ''}?productId=${product.id ?? ''}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
      children: [
        _ProductImageGallery(
          product: product,
          currentIndex: _imageIndex,
          onPageChanged: (index) => setState(() => _imageIndex = index),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                '\$${(product.price ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: StyleFont.largeSize,
                  fontWeight: FontWeight.w400,
                  color: StyleColor.ink,
                ),
              ),
            ),
            IconButton(
              onPressed: _saving ? null : () => _toggleSaved(product),
              tooltip: (_savedOverride ?? product.isSaved == true)
                  ? 'postCard.removeSaved'.tr()
                  : 'postCard.saveItem'.tr(),
              icon: Icon(
                (_savedOverride ?? product.isSaved == true)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: (_savedOverride ?? product.isSaved == true)
                    ? StyleColor.accent
                    : StyleColor.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          product.title ?? '',
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
            _Tag(text: conditionLabel(product.condition)),
            if (product.category?.isNotEmpty == true)
              _Tag(text: product.category!),
            _Tag(
              text: switch (product.status) {
                'AVAILABLE' => 'product.statusAvailable'.tr(),
                'SOLD' => 'product.statusSold'.tr(),
                _ => product.status?.replaceAll('_', ' ') ?? '',
              },
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
              Flexible(
                child: Text(
                  product.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: StyleColor.muted),
                ),
              ),
            ],
          ),
        ],
        if (product.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Text(product.description!, style: const TextStyle(height: 1.45)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (widget.postId != null)
              TextButton.icon(
                onPressed: _liking ? null : () => _toggleLike(product),
                icon: Icon(
                  (_likedOverride ?? product.hasLiked == true)
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_up_outlined,
                  size: 18,
                  color: (_likedOverride ?? product.hasLiked == true)
                      ? StyleColor.teal
                      : StyleColor.muted,
                ),
                label: Text(
                  'product.likesCount'.tr(
                    namedArgs: {
                      'count':
                          '${_likeCountOverride ?? product.totalLike ?? 0}',
                    },
                  ),
                  style: const TextStyle(color: StyleColor.muted),
                ),
              )
            else ...[
              const Icon(
                Icons.thumb_up_outlined,
                size: 18,
                color: StyleColor.muted,
              ),
              const SizedBox(width: 5),
              Text(
                'product.likesCount'.tr(
                  namedArgs: {'count': '${product.totalLike}'},
                ),
                style: const TextStyle(color: StyleColor.muted),
              ),
            ],
            const SizedBox(width: 16),
            const Icon(
              Icons.mode_comment_outlined,
              size: 18,
              color: StyleColor.muted,
            ),
            const SizedBox(width: 5),
            Text(
              'postCard.commentsCount'.tr(
                namedArgs: {'count': '${product.totalComment}'},
              ),
              style: const TextStyle(color: StyleColor.muted),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _postProductsSection(),
        Card(
          child: ListTile(
            leading: _sellerAvatar(seller),
            title: Text(
              seller?.displayName ??
                  'postCard.sellerFallback'.tr(
                    namedArgs: {'id': '${product.sellerId}'},
                  ),
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
                    label: Text('product.chat'.tr()),
                  ),
            onTap: ownProduct ? null : () => context.push(chatRoute),
          ),
        ),
        const SizedBox(height: 12),
        if (ownProduct && product.status == 'AVAILABLE')
          PrimaryButton(
            label: 'product.markSold'.tr(),
            busy: _updatingStatus,
            onPressed: () => _markSold(product),
          )
        else if (!ownProduct && product.status == 'SOLD')
          PrimaryButton(
            label: 'product.writeReview'.tr(),
            onPressed: product.id == null
                ? null
                : () => _writeReview(product.id!),
          )
        else if (!ownProduct)
          PrimaryButton(
            label: 'product.messageSeller'.tr(),
            onPressed: () => context.push(chatRoute),
          ),
        const SizedBox(height: 12),
        _reviewSection(product),
        const SizedBox(height: 14),
        _commentsSection(product),
        const SizedBox(height: StyleSpacing.bottomContentClearance),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'product.details'.tr(),
        showNotifications: false,
        showProfileAvatar: false,
      ).build(context),
      body: Material(
        type: MaterialType.transparency,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _loadError != null
            ? ErrorRetryPanel(
                error: _loadError!,
                onRetry: () => unawaited(_load()),
              )
            : _productContent(_product!),
      ),
    ),
  );

  @override
  void dispose() {
    _commentComposer.dispose();
    super.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: StyleFont.mediumSize,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(message, style: const TextStyle(color: StyleColor.muted)),
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
          : StyleColor.surfaceVariant,
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
    final images = product.images ?? const <MarketplaceImage>[];
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
