import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Product> _saved = const [];
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
      final page = await api.wishlist();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _saved = page.items ?? const <Product>[];
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

  Future<void> _remove(int id) async {
    try {
      await api.removeSavedProduct(id);
      if (mounted) {
        setState(
          () => _saved = _saved.where((product) => product.id != id).toList(),
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _openProduct(int id) async {
    await context.push('/products/$id');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'nav.favorite'.tr(),
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
                : _saved.isEmpty
                ? EmptyState(
                    title: 'saved.emptyTitle'.tr(),
                    message: 'saved.emptyMessage'.tr(),
                    icon: Icons.favorite_border_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _saved.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == _saved.length) {
                        return const SizedBox(
                          height: StyleSpacing.bottomContentClearance,
                        );
                      }
                      final product = _saved[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: SizedBox(
                            width: 72,
                            height: 72,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ProductArtwork(
                                category: product.category,
                                height: 72,
                                image: product.primaryImage,
                              ),
                            ),
                          ),
                          title: Text(
                            product.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                          subtitle: Text(
                            '\$${(product.price ?? 0).toStringAsFixed(2)}  ·  ${(product.status ?? '').toLowerCase()}',
                            style: const TextStyle(color: StyleColor.muted),
                          ),
                          trailing: IconButton(
                            onPressed: product.id == null
                                ? null
                                : () => _remove(product.id!),
                            tooltip: 'postCard.removeSaved'.tr(),
                            icon: const Icon(
                              Icons.favorite,
                              color: StyleColor.ink,
                            ),
                          ),
                          onTap: product.id == null
                              ? null
                              : () => _openProduct(product.id!),
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
