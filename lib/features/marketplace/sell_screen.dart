import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/choose_image_bottom_sheet.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
import '../../core/l10n_labels.dart';
import '../../core/models.dart';
import 'marketplace_options.dart';

typedef _Photo = ({XFile file, Uint8List bytes});

class _ProductDraft {
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final location = TextEditingController(text: 'Phnom Penh');
  String category = 'Electronics';
  String condition = 'GOOD';
  final photos = <_Photo>[];

  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    location.dispose();
  }
}

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});
  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caption = TextEditingController();
  final List<_ProductDraft> _products = [_ProductDraft()];
  bool _busy = false;
  bool _optionsLoading = true;

  // Built once so the text fields always get the 0.5 / 1 border theme,
  // even when the adaptive scaffold does not pass the Material theme down.
  final ThemeData _theme = buildAppTheme();
  List<String> _categories = marketplaceCategories.skip(1).toList();
  List<String> _conditions = productConditions;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await api.marketplaceOptions();
      if (!mounted) return;
      setState(() {
        _categories = options.categories;
        _conditions = options.conditions;
        for (final product in _products) {
          if (!_categories.contains(product.category)) {
            product.category = _categories.isEmpty ? '' : _categories.first;
          }
          if (!_conditions.contains(product.condition)) {
            product.condition = _conditions.isEmpty ? '' : _conditions.first;
          }
        }
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    for (final product in _products) {
      product.dispose();
    }
    super.dispose();
  }

  _ProductDraft _newProductDraft() {
    final product = _ProductDraft();
    if (!_categories.contains(product.category)) {
      product.category = _categories.isEmpty ? '' : _categories.first;
    }
    if (!_conditions.contains(product.condition)) {
      product.condition = _conditions.isEmpty ? '' : _conditions.first;
    }
    return product;
  }

  void _addProduct() => setState(() => _products.add(_newProductDraft()));

  void _removeProduct(_ProductDraft product) {
    if (_products.length == 1) return;
    setState(() => _products.remove(product));
    product.dispose();
  }

  Future<void> _pickPhotos(_ProductDraft product) async {
    final remaining = 5 - product.photos.length;
    if (remaining <= 0) return;
    if (!await showChooseImageBottomSheet(context) || !mounted) return;
    try {
      final selected = await ImagePicker().pickMultiImage(
        limit: remaining,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selected.isEmpty || !mounted) return;
      final photos = await Future.wait(
        selected
            .take(remaining)
            .map((file) async => (file: file, bytes: await file.readAsBytes())),
      );
      if (mounted) setState(() => product.photos.addAll(photos));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  void _removePhoto(_ProductDraft product, int index) =>
      setState(() => product.photos.removeAt(index));

  JsonMap _productBody(_ProductDraft draft) => {
    'title': draft.title.text.trim(),
    'description': draft.description.text.trim(),
    'price': double.parse(draft.price.text),
    'category': draft.category.isEmpty ? null : draft.category,
    'condition': draft.condition,
    'location': draft.location.text.trim(),
  };

  String _postContent(List<String> titles) {
    final caption = _caption.text.trim();
    if (caption.isNotEmpty) return caption;
    if (titles.length == 1) return titles.first;
    return 'sell.postFallback'.tr(namedArgs: {'titles': titles.join(', ')});
  }

  Future<void> _publish() async {
    if (_optionsLoading) return;
    if (_conditions.isEmpty) {
      showError(context, StateError('sell.noConditionsError'.tr()));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final images = <({String name, Uint8List bytes})>[];
      final products = <JsonMap>[];
      for (final draft in _products) {
        final imageIndexes = <int>[];
        for (final photo in draft.photos) {
          imageIndexes.add(images.length);
          images.add((name: photo.file.name, bytes: photo.bytes));
        }
        products.add({..._productBody(draft), 'imageIndexes': imageIndexes});
      }

      final post = await api.createListing({
        'content': _postContent(
          _products.map((draft) => draft.title.text.trim()).toList(),
        ),
        'products': products,
      }, images);

      if (!mounted) return;
      if (post.products.isEmpty) {
        throw StateError('sell.missingProductsError'.tr());
      }
      final firstProduct = post.products.first;
      context.go('/products/${firstProduct.id}?postId=${post.id}');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photoPicker(_ProductDraft product) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'sell.productPhotos'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
          TextButton.icon(
            onPressed: product.photos.length < 5
                ? () => _pickPhotos(product)
                : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('${product.photos.length}/5'),
          ),
        ],
      ),
      SizedBox(
        height: 112,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < product.photos.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _PhotoTile(
                  bytes: product.photos[i].bytes,
                  onRemove: () => _removePhoto(product, i),
                ),
              ),
            if (product.photos.length < 5)
              _AddPhotoTile(onTap: () => _pickPhotos(product)),
          ],
        ),
      ),
    ],
  );

  Widget _productEditor(_ProductDraft product, int index) => Card(
    key: ObjectKey(product),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'sell.productNumber'.tr(namedArgs: {'index': '${index + 1}'}),
                  style: const TextStyle(
                    fontSize: StyleFont.largeSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (_products.length > 1)
                IconButton(
                  onPressed: () => _removeProduct(product),
                  tooltip: 'sell.removeProduct'.tr(),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          _photoPicker(product),
          const SizedBox(height: 10),
          MKTextFormField(
            controller: product.title,
            decoration: InputDecoration(labelText: 'sell.productTitle'.tr()),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'sell.titleRequired'.tr()
                : null,
          ),
          const SizedBox(height: 12),
          MKTextFormField(
            controller: product.description,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'sell.description'.tr(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          MKTextFormField(
            controller: product.price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'sell.priceUsd'.tr(),
              prefixText: '\$ ',
            ),
            validator: (value) {
              final amount = double.tryParse(value ?? '');
              return amount == null || amount <= 0
                  ? 'sell.priceInvalid'.tr()
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categories.contains(product.category)
                ? product.category
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'sell.category'.tr(),
              hintText: _categories.isEmpty
                  ? 'sell.noActiveCategories'.tr()
                  : null,
            ),
            items: _categories
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(categoryLabel(value)),
                  ),
                )
                .toList(),
            onChanged: _categories.isEmpty
                ? null
                : (value) => setState(
                    () => product.category = value ?? product.category,
                  ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _conditions.contains(product.condition)
                ? product.condition
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'sell.condition'.tr(),
              hintText: _conditions.isEmpty
                  ? 'sell.noActiveConditions'.tr()
                  : null,
            ),
            items: _conditions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(conditionLabel(value)),
                  ),
                )
                .toList(),
            onChanged: _conditions.isEmpty
                ? null
                : (value) => setState(
                    () => product.condition = value ?? product.condition,
                  ),
          ),
          const SizedBox(height: 12),
          MKTextFormField(
            controller: product.location,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'sell.location'.tr(),
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'sell.locationRequired'.tr()
                : null,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'sell.title'.tr(),
        showNotifications: false,
        showProfileAvatar: false,
      ).build(context),
      body: Theme(
        data: _theme,
        child: Material(
          type: MaterialType.transparency,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                if (!_optionsLoading && _categories.isEmpty)
                  _OptionsNotice(
                    icon: Icons.category_outlined,
                    message: 'sell.noCategoriesNotice'.tr(),
                  ),
                if (!_optionsLoading && _conditions.isEmpty)
                  _OptionsNotice(
                    icon: Icons.fact_check_outlined,
                    message: 'sell.conditionsUnavailableNotice'.tr(),
                  ),
                AbsorbPointer(
                  absorbing: _busy || _optionsLoading,
                  child: Column(
                    children: [
                      MKTextFormField(
                        controller: _caption,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'sell.postMessageOptional'.tr(),
                          hintText: 'sell.postMessageHint'.tr(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _products.length; i++) ...[
                        _productEditor(_products[i], i),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: Text('sell.addAnotherProduct'.tr()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _products.length == 1
                      ? 'sell.publishOne'.tr()
                      : 'sell.publishMany'.tr(
                          namedArgs: {'count': '${_products.length}'},
                        ),
                  busy: _busy || _optionsLoading,
                  onPressed: _publish,
                ),
                const SizedBox(height: StyleSpacing.bottomContentClearance),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      children: [
        Image.memory(bytes, width: 112, height: 112, fit: BoxFit.cover),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filled(
            onPressed: onRemove,
            tooltip: 'sell.removePhoto'.tr(),
            icon: const Icon(Icons.close, size: StyleColor.iconSize),
            style: IconButton.styleFrom(
              iconSize: StyleColor.iconSize,
              minimumSize: const Size(30, 30),
              padding: const EdgeInsets.all(6),
              backgroundColor: Colors.white.withValues(alpha: .9),
              foregroundColor: StyleColor.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OptionsNotice extends StatelessWidget {
  const _OptionsNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      color: const Color(0xFFFFF8E9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: StyleColor.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: StyleColor.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: StyleColor.softMint,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: const SizedBox(
        width: 112,
        height: 112,
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: StyleColor.iconSize,
          color: StyleColor.ink,
        ),
      ),
    ),
  );
}
