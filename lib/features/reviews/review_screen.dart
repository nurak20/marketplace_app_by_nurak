import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/app_theme.dart';
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
  Product? _product;
  bool _isLoading = true;
  Object? _loadError;
  int _loadGeneration = 0;
  int _rating = 5;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final product = await api.product(widget.productId);
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

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await api.addReview(widget.productId, _rating, _comment.text.trim());
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _reviewForm(Product product) => ListView(
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
            product.title ?? '',
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
          subtitle: Text(
            'reviews.soldBy'.tr(namedArgs: {'id': '${product.sellerId}'}),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'reviews.yourRating'.tr(),
        style: const TextStyle(
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
            tooltip: 'reviews.starsTooltip'.tr(namedArgs: {'count': '$value'}),
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
      MKTextFormField(
        controller: _comment,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: 'reviews.commentOptional'.tr(),
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 22),
      PrimaryButton(
        label: 'reviews.submitReview'.tr(),
        busy: _busy,
        onPressed: _submit,
      ),
      const SizedBox(height: StyleSpacing.bottomContentClearance),
    ],
  );

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'reviews.writeReview'.tr(),
        showNotifications: false,
        showProfileAvatar: false,
      ).build(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _loadError != null
          ? ErrorRetryPanel(
              error: _loadError!,
              onRetry: () => unawaited(_load()),
            )
          : _reviewForm(_product!),
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
  List<Review> _reviews = const [];
  bool _isLoading = true;
  Object? _loadError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final page = await api.reviews(widget.productId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _reviews = page.items ?? const <Review>[];
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

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'reviews.title'.tr(),
        showNotifications: false,
        showProfileAvatar: false,
      ).build(context),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _loadError != null
                ? ErrorRetryPanel(
                    error: _loadError!,
                    onRetry: () => unawaited(_load()),
                  )
                : _reviews.isEmpty
                ? EmptyState(
                    title: 'reviews.noReviews'.tr(),
                    message: 'reviews.noReviewsMessage'.tr(),
                    icon: Icons.star_outline_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _reviews.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      if (index == _reviews.length) {
                        return const SizedBox(
                          height: StyleSpacing.bottomContentClearance,
                        );
                      }
                      final review = _reviews[index];
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
                                      star < (review.rating ?? 0)
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: StyleColor.iconSize,
                                      color: StyleColor.accent,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'reviews.buyer'.tr(
                                      namedArgs: {'id': '${review.buyerId}'},
                                    ),
                                    style: const TextStyle(
                                      color: StyleColor.muted,
                                    ),
                                  ),
                                ],
                              ),
                              if (review.comment?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 7),
                                Text(review.comment!),
                              ],
                            ],
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
