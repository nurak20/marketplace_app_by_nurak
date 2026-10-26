import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
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
  late Future<ApiPage<Product>> _saved;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _saved = api.wishlist();
  }

  Future<void> _remove(int id) async {
    try {
      final page = await _saved;
      await api.removeSavedProduct(id);
      if (mounted) {
        setState(() {
          _saved = Future.value(
            page.withItems(
              page.items.where((product) => product.id != id).toList(),
            ),
          );
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _openProduct(int id) async {
    await context.push('/products/$id');
    if (mounted) {
      setState(() {
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const MarketplaceAppBar(title: 'Saved items'),
    body: FutureBuilder<ApiPage<Product>>(
      future: _saved,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return ErrorRetryPanel(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _load();
            }),
          );
        }
        final products = snapshot.data?.items ?? const <Product>[];
        if (products.isEmpty) {
          return const EmptyState(
            title: 'Nothing saved yet',
            message: 'Tap the heart on a listing to keep it close.',
            icon: Icons.favorite_border_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final product = products[index];
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
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Text(
                  '\$${product.price.toStringAsFixed(2)}  ·  ${product.status.toLowerCase()}',
                  style: const TextStyle(color: StyleColor.muted),
                ),
                trailing: IconButton(
                  onPressed: () => _remove(product.id),
                  tooltip: 'Remove saved item',
                  icon: const Icon(Icons.favorite, color: StyleColor.ink),
                ),
                onTap: () => _openProduct(product.id),
              ),
            );
          },
        );
      },
    ),
  );
}
