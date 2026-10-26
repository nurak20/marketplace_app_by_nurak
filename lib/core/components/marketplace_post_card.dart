import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';
import '../models.dart';
import 'product_artwork.dart';

class MarketplacePostCard extends StatelessWidget {
  const MarketplacePostCard({
    super.key,
    required this.post,
    required this.isLiked,
    required this.likeCount,
    required this.isLiking,
    required this.onLike,
    required this.onComment,
    required this.isSaved,
    required this.onSave,
    required this.onProductTap,
  });

  final MarketplacePost post;
  final bool Function(MarketplacePost, Product) isLiked;
  final int Function(MarketplacePost, Product) likeCount;
  final bool Function(MarketplacePost, Product) isLiking;
  final void Function(MarketplacePost, Product) onLike;
  final void Function(MarketplacePost, Product) onComment;
  final bool Function(Product) isSaved;
  final ValueChanged<Product> onSave;
  final void Function(MarketplacePost, Product) onProductTap;

  @override
  Widget build(BuildContext context) {
    final items = post.products.map((product) => (post, product)).toList();
    final sellerId = post.userId;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Builder(
              builder: (context) {
                final seller = post.seller;
                final avatar = seller?.avatar;
                final hasAvatar = avatar?.url.isNotEmpty == true;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: StyleColor.canvas,
                      backgroundImage: hasAvatar
                          ? NetworkImage(api.resolveUrl(avatar!.url))
                          : null,
                      onBackgroundImageError: hasAvatar ? (_, _) {} : null,
                      child: hasAvatar
                          ? null
                          : const Icon(
                              Icons.person_outline_rounded,
                              color: StyleColor.ink,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller?.displayName ?? 'Seller #$sellerId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: StyleFont.mediumSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            _dateLabel(post.createdAt),
                            style: const TextStyle(
                              fontSize: StyleFont.mediumSize,
                              color: StyleColor.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_showContent(items.map((item) => item.$2)))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                post.content!.trim(),
                style: const TextStyle(fontSize: StyleFont.mediumSize),
              ),
            ),
          SizedBox(
            height: 330,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final (post, product) = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: SizedBox(
                    width: 260,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      color: StyleColor.canvas,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              InkWell(
                                onTap: () => onProductTap(post, product),
                                child: ProductArtwork(
                                  category: product.category,
                                  height: 164,
                                  image: product.primaryImage,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton.filledTonal(
                                  onPressed: () => onSave(product),
                                  tooltip: isSaved(product)
                                      ? 'Remove from saved'
                                      : 'Save item',
                                  style: IconButton.styleFrom(
                                    iconSize: StyleColor.iconSize,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: .94,
                                    ),
                                  ),
                                  icon: Icon(
                                    isSaved(product)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => onProductTap(post, product),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(11, 8, 11, 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: StyleFont.mediumSize,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '\$${product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: StyleFont.mediumSize,
                                      color: StyleColor.ink,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(11, 0, 11, 5),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: StyleColor.iconSize,
                                  color: StyleColor.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${likeCount(post, product)}',
                                  style: const TextStyle(
                                    fontSize: StyleFont.mediumSize,
                                    color: StyleColor.muted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${post.engagementFor(product).commentCount} comments',
                                  style: const TextStyle(
                                    fontSize: StyleFont.mediumSize,
                                    color: StyleColor.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 8, endIndent: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: isLiking(post, product)
                                        ? null
                                        : () => onLike(post, product),
                                    icon: Icon(
                                      isLiked(post, product)
                                          ? Icons.thumb_up_rounded
                                          : Icons.thumb_up_outlined,
                                      color: isLiked(post, product)
                                          ? StyleColor.teal
                                          : StyleColor.muted,
                                      size: StyleColor.iconSize,
                                    ),
                                    label: Text(
                                      'Like',
                                      style: TextStyle(
                                        fontSize: StyleFont.mediumSize,
                                        color: isLiked(post, product)
                                            ? StyleColor.teal
                                            : StyleColor.muted,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => onComment(post, product),
                                    icon: const Icon(
                                      Icons.mode_comment_outlined,
                                      color: StyleColor.muted,
                                      size: StyleColor.iconSize,
                                    ),
                                    label: const Text('Comment'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _showContent(Iterable<Product> products) =>
      post.content?.trim().isNotEmpty == true &&
      !products.any((product) => product.title == post.content?.trim());

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Date unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${months[value.month - 1]} ${value.day}, ${value.year} · $hour:$minute $period';
  }
}
