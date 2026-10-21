import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';

typedef ProductDetails = (
  Product,
  List<ProductImage>,
  List<Review>,
  int?,
  List<PostComment>,
  UserProfile?,
);

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.showComments = false,
    this.postId,
  });
  final int productId;
  final bool showComments;
  final int? postId;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _commentController = TextEditingController();
  late Future<ProductDetails> _detail;
  bool _saved = false;
  bool _saving = false;
  bool _savedChecked = false;
  bool _updatingStatus = false;
  bool _postingComment = false;
  bool _scrolledToComments = false;
  final _commentsSectionKey = GlobalKey();
  int _currentUserId = -1;
  PostComment? _replyTarget;

  @override
  void initState() {
    super.initState();
    _load();
    _checkSaved();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final account = await api.me();
      if (mounted) setState(() => _currentUserId = account.profile.id);
    } catch (_) {}
  }

  void _load() {
    _detail = _fetchDetail();
  }

  Future<ProductDetails> _fetchDetail() async {
    final product = await api.product(widget.productId);
    final values = await Future.wait<Object?>([
      api.images(widget.productId),
      api.reviews(widget.productId),
      widget.postId == null
          ? api.postIdForProduct(product.id, product.sellerId)
          : Future<int?>.value(widget.postId),
      api
          .profile(product.sellerId)
          .then<UserProfile?>((json) => UserProfile.fromJson(json))
          .catchError((_) => null),
    ]);
    final postId = values[2] as int?;
    final comments = postId == null
        ? <PostComment>[]
        : (await api.productPostComments(postId, product.id)).items;
    return (
      product,
      values[0] as List<ProductImage>,
      (values[1] as ApiPage<Review>).items,
      postId,
      comments,
      values[3] as UserProfile?,
    );
  }

  Future<void> _postComment(int postId) async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _postingComment) return;
    setState(() => _postingComment = true);
    try {
      await api.addProductPostComment(
        postId,
        widget.productId,
        content,
        parentId: _replyTarget?.id,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _postingComment = false);
        showError(context, error);
      }
      return;
    }
    if (!mounted) return;
    _commentController.clear();
    _replyTarget = null;
    setState(() {
      _postingComment = false;
      _load();
    });
  }

  Future<void> _checkSaved() async {
    try {
      final result = await api.wishlist();
      if (mounted) {
        setState(() {
          _saved = result.items.any((item) => item.id == widget.productId);
          _savedChecked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _savedChecked = true);
    }
  }

  Future<void> _toggleSaved() async {
    setState(() => _saving = true);
    try {
      if (_saved) {
        await api.removeSavedProduct(widget.productId);
      } else {
        await api.saveProduct(widget.productId);
      }
      if (mounted) setState(() => _saved = !_saved);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markSold() async {
    setState(() => _updatingStatus = true);
    try {
      await api.setProductStatus(widget.productId, 'SOLD');
      if (mounted) {
        setState(() {
          _load();
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _writeReview(int productId) async {
    await context.push('/reviews/$productId');
    if (mounted) {
      setState(() {
        _load();
      });
    }
  }

  int _commentCount(List<PostComment> comments) => comments.fold(
    0,
    (count, comment) => count + 1 + _commentCount(comment.replies),
  );

  Widget _personAvatar(String? avatarUrl, {double radius = 22}) {
    final hasAvatar = avatarUrl?.isNotEmpty == true;
    return CircleAvatar(
      radius: radius,
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

  Widget _commentTile(PostComment comment, int postId) => Column(
    children: [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _personAvatar(comment.avatarUrl, radius: 21),
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
                    Text(comment.content),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _replyTarget = comment),
                        icon: const Icon(
                          Icons.reply_rounded,
                          size: StyleColor.iconSize,
                        ),
                        label: const Text('Reply'),
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
      if (comment.replies.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(left: 16, top: 7),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: StyleColor.muted.withValues(alpha: .25)),
            ),
          ),
          child: Column(
            children: comment.replies
                .map((reply) => _commentTile(reply, postId))
                .toList(),
          ),
        ),
      const SizedBox(height: 8),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Product details'),
      actions: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          onPressed: _savedChecked && !_saving ? _toggleSaved : null,
          tooltip: 'Save item',
          icon: Icon(_saved ? Icons.favorite : Icons.favorite_border),
        ),
      ],
    ),
    body: FutureBuilder<ProductDetails>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorRetryPanel(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _load();
            }),
          );
        }
        final (product, images, reviews, postId, comments, seller) =
            snapshot.data!;
        if (widget.showComments && !_scrolledToComments) {
          _scrolledToComments = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final target = _commentsSectionKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 280),
                alignment: .12,
              );
            }
          });
        }
        final ownProduct = product.sellerId == _currentUserId;
        final primary = images.where((image) => image.primary).isNotEmpty
            ? images.firstWhere((image) => image.primary)
            : (images.isNotEmpty ? images.first : null);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ProductArtwork(
                category: product.category,
                imageUrl: primary?.url,
                height: 240,
              ),
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
                _Tag(text: product.category ?? 'Other'),
                _Tag(
                  text: product.status.replaceAll('_', ' '),
                  highlight: product.status == 'SOLD',
                ),
              ],
            ),
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
                  product.location ?? 'Cambodia',
                  style: const TextStyle(color: StyleColor.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              product.description?.isNotEmpty == true
                  ? product.description!
                  : 'No description provided.',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: _personAvatar(seller?.avatarUrl, radius: 26),
                title: Text(
                  seller?.displayName ?? 'Seller #${product.sellerId}',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Text(
                  seller?.location?.isNotEmpty == true
                      ? seller!.location!
                      : 'Marketplace member',
                ),
                trailing: ownProduct
                    ? null
                    : TextButton.icon(
                        onPressed: () => context.push(
                          '/chats/${product.sellerId}?productId=${product.id}',
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Chat'),
                      ),
                onTap: ownProduct
                    ? null
                    : () => context.push(
                        '/chats/${product.sellerId}?productId=${product.id}',
                      ),
              ),
            ),
            const SizedBox(height: 18),
            if (ownProduct && product.status == 'AVAILABLE')
              PrimaryButton(
                label: 'Mark as sold',
                busy: _updatingStatus,
                onPressed: _markSold,
              )
            else if (!ownProduct && product.status == 'SOLD')
              PrimaryButton(
                label: 'Write a review',
                onPressed: () => _writeReview(product.id),
              )
            else if (!ownProduct)
              PrimaryButton(
                label: 'Message seller',
                onPressed: () => context.push(
                  '/chats/${product.sellerId}?productId=${product.id}',
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: StyleFont.largeSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  '${reviews.length}',
                  style: const TextStyle(color: StyleColor.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'No reviews yet.',
                  style: TextStyle(color: StyleColor.muted),
                ),
              )
            else
              ...reviews.map(
                (review) => Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (index) => Icon(
                                index < review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: StyleColor.iconSize,
                                color: StyleColor.accent,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Buyer #${review.buyerId}',
                              style: const TextStyle(
                                fontSize: StyleFont.mediumSize,
                                color: StyleColor.muted,
                              ),
                            ),
                          ],
                        ),
                        if (review.comment?.isNotEmpty == true) ...[
                          const SizedBox(height: 7),
                          Text(review.comment!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 22),
            Row(
              key: _commentsSectionKey,
              children: [
                const Expanded(
                  child: Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: StyleFont.largeSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  '${_commentCount(comments)}',
                  style: const TextStyle(color: StyleColor.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  postId == null
                      ? 'Comments are not available for this listing yet.'
                      : 'Start the conversation about this listing.',
                  style: const TextStyle(color: StyleColor.muted),
                ),
              )
            else
              ...comments.map((comment) => _commentTile(comment, postId!)),
            if (postId != null) ...[
              const SizedBox(height: 6),
              if (_replyTarget != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to ${_replyTarget!.displayName}',
                          style: const TextStyle(color: StyleColor.muted),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _replyTarget = null),
                        tooltip: 'Cancel reply',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _commentController,
                autofocus: widget.showComments,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postComment(postId),
                decoration: InputDecoration(
                  hintText: _replyTarget == null
                      ? 'Add a comment'
                      : 'Reply to ${_replyTarget!.displayName}',
                  suffixIcon: IconButton(
                    onPressed: _postingComment
                        ? null
                        : () => _postComment(postId),
                    tooltip: 'Post comment',
                    icon: _postingComment
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
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
