import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/adaptive_safe_body.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.productId});
  final int productId;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _comment = TextEditingController();
  late Future<Product> _product;
  int _rating = 5;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _product = api.product(widget.productId);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await api.addReview(widget.productId, _rating, _comment.text.trim());
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(
      title: 'Write a review',
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
            return Center(child: Text(Api.errorMessage(snapshot.error!)));
          }
          final product = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ProductArtwork(
                        category: product.category,
                        height: 64,
                        image: product.primaryImage,
                      ),
                    ),
                  ),
                  title: Text(
                    product.title,
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                  subtitle: Text('Sold by member #${product.sellerId}'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your rating',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: StyleFont.mediumSize,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => _rating = value),
                    tooltip: '$value stars',
                    iconSize: StyleColor.iconSize,
                    color: StyleColor.accent,
                    icon: Icon(
                      value <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Submit review',
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: StyleSpacing.bottomContentClearance),
            ],
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }
}

class ProductReviewsScreen extends StatefulWidget {
  const ProductReviewsScreen({super.key, required this.productId});
  final int productId;

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  late Future<ApiPage<Review>> _reviews;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _reviews = api.reviews(widget.productId);
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(
      title: 'Reviews',
      showNotifications: false,
      showProfileAvatar: false,
    ).build(context),
    body: AdaptiveSafeBody(
      child: FutureBuilder<ApiPage<Review>>(
        future: _reviews,
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
          final reviews = snapshot.data?.items ?? const <Review>[];
          if (reviews.isEmpty) {
            return const EmptyState(
              title: 'No reviews yet',
              message: 'Reviews will appear here after a completed sale.',
              icon: Icons.star_outline_rounded,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: reviews.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              if (index == reviews.length) {
                return const SizedBox(
                  height: StyleSpacing.bottomContentClearance,
                );
              }
              final review = reviews[index];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (star) => Icon(
                              star < review.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: StyleColor.iconSize,
                              color: StyleColor.accent,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Buyer #${review.buyerId}',
                            style: const TextStyle(color: StyleColor.muted),
                          ),
                        ],
                      ),
                      if (review.comment?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 7),
                        Text(review.comment!),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
