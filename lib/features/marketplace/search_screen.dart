import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/product_artwork.dart';
import '../../core/models.dart';
import 'marketplace_options.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<ApiPage<Product>>? _results;
  String _category = 'All';

  void _scheduleSearch(String _) {
    _debounce?.cancel();
    final keyword = _controller.text.trim();
    if (keyword.isEmpty && _category == 'All') {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _search() {
    _debounce?.cancel();
    final keyword = _controller.text.trim();
    if (keyword.isEmpty && _category == 'All') {
      setState(() => _results = null);
      return;
    }
    setState(() {
      _results = api.products(
        keyword: keyword.isEmpty ? null : keyword,
        category: _category,
        status: 'AVAILABLE',
      );
    });
  }

  void _clearSearch() {
    _controller.clear();
    _scheduleSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _filters() => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: marketplaceCategoryItems.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final category = marketplaceCategoryItems[index].name;
        return ChoiceChip(
          label: Text(category),
          selected: _category == category,
          onSelected: (_) {
            setState(() => _category = category);
            _search();
          },
        );
      },
    ),
  );

  Widget _resultList() {
    final future = _results;
    if (future == null) {
      return const Center(
        child: Text(
          'Search by product name or choose a category.',
          textAlign: TextAlign.center,
          style: TextStyle(color: StyleColor.muted),
        ),
      );
    }

    return FutureBuilder<ApiPage<Product>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (snapshot.hasError) {
          return ErrorRetryPanel(error: snapshot.error!, onRetry: _search);
        }
        final products = snapshot.data?.items ?? const <Product>[];
        if (products.isEmpty) {
          return const Center(
            child: Text(
              'No products found.',
              style: TextStyle(color: StyleColor.muted),
            ),
          );
        }
        return Column(
          children: [
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    onTap: () => context.push<void>('/products/${product.id}'),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: ProductArtwork(
                          category: product.category,
                          image: product.primaryImage,
                          height: 58,
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
                      [
                        if (product.category?.isNotEmpty == true)
                          product.category!,
                        product.condition.replaceAll('_', ' '),
                        product.location ?? 'Cambodia',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: StyleColor.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const AdaptiveAppBar(
      title: 'Search products',
      useNativeToolbar: false,
      tintColor: StyleColor.ink,
    ),
    body: Material(
      type: MaterialType.transparency,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _scheduleSearch,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search by product name',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 12),
          _resultList(),
        ],
      ),
    ),
  );
}
