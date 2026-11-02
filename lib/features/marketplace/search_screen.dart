import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/app_theme.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/product_artwork.dart';
import '../../core/l10n_labels.dart';
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
  List<Product> _results = const [];
  bool _isLoading = true;
  Object? _loadError;
  int _requestGeneration = 0;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    unawaited(_search());
  }

  List<MarketplaceCategory> get _categoryItems {
    final names = api.marketplaceCategoryNames;
    return marketplaceItemsForCategories(
      names ?? marketplaceCategories.skip(1),
    );
  }

  void _scheduleSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_search()),
    );
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    final keyword = _controller.text.trim();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final page = await api.products(
        keyword: keyword.isEmpty ? null : keyword,
        category: _category,
        status: 'AVAILABLE',
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = page.items ?? const <Product>[];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
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
      itemCount: _categoryItems.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final category = _categoryItems[index].name;
        return ChoiceChip(
          label: Text(categoryLabel(category)),
          selected: _category == category,
          onSelected: (_) {
            setState(() => _category = category);
            unawaited(_search());
          },
        );
      },
    ),
  );

  Widget _resultList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_loadError != null) {
      return ErrorRetryPanel(
        error: _loadError!,
        onRetry: () => unawaited(_search()),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'common.noResults'.tr(),
          style: const TextStyle(color: StyleColor.muted),
        ),
      );
    }
    return Column(
      children: [
        for (final product in _results)
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
                  product.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Text(
                  [
                    if (product.category?.isNotEmpty == true) product.category!,
                    conditionLabel(product.condition),
                    product.location ?? 'productCard.defaultLocation'.tr(),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '\$${(product.price ?? 0).toStringAsFixed(2)}',
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
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'search.title'.tr()),
    body: Material(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                MKTextFormField(
                  controller: _controller,

                  textInputAction: TextInputAction.search,
                  onChanged: _scheduleSearch,
                  onFieldSubmitted: (_) => unawaited(_search()),
                  decoration: InputDecoration(
                    hintText: 'search.hint'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _clearSearch,
                            tooltip: 'search.clear'.tr(),
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
        ],
      ),
    ),
  );
}
