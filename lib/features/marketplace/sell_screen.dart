import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/primary_button.dart';
import '../../core/components/show_error.dart';
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

  @override
  void dispose() {
    _caption.dispose();
    for (final product in _products) {
      product.dispose();
    }
    super.dispose();
  }

  void _addProduct() => setState(() => _products.add(_ProductDraft()));

  void _removeProduct(_ProductDraft product) {
    if (_products.length == 1) return;
    setState(() => _products.remove(product));
    product.dispose();
  }

  Future<void> _pickPhotos(_ProductDraft product) async {
    final remaining = 5 - product.photos.length;
    if (remaining <= 0) return;
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
    'category': draft.category,
    'condition': draft.condition,
    'location': draft.location.text.trim(),
  };

  String _postContent(List<Product> products) {
    final caption = _caption.text.trim();
    if (caption.isNotEmpty) return caption;
    if (products.length == 1) return products.first.title;
    return 'For sale: ${products.map((product) => product.title).join(', ')}';
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final created = <Product>[];
    Object? createError;
    Object? photoError;
    try {
      for (final draft in _products) {
        try {
          final product = await api.createProduct(_productBody(draft));
          created.add(product);
          for (final photo in draft.photos) {
            try {
              await api.uploadProductImage(product.id, photo.file);
            } catch (error) {
              photoError ??= error;
            }
          }
        } catch (error) {
          createError = error;
          break;
        }
      }

      if (created.isEmpty) {
        if (createError != null) throw createError;
        return;
      }

      await api.createListingPost(
        created.map((product) => product.id).toList(),
        _postContent(created),
      );

      if (!mounted) return;
      if (createError != null || photoError != null) {
        final details = <String>[
          if (createError != null)
            'Some products could not be created: ${Api.errorMessage(createError)}',
          if (photoError != null)
            'A product image could not be uploaded: ${Api.errorMessage(photoError)}',
        ].join(' ');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('The post is live. $details')));
      }
      context.go('/products/${created.first.id}');
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
          const Expanded(
            child: Text(
              'Product photos',
              style: TextStyle(fontWeight: FontWeight.w400),
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
                  'Product ${index + 1}',
                  style: const TextStyle(
                    fontSize: StyleFont.largeSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (_products.length > 1)
                IconButton(
                  onPressed: () => _removeProduct(product),
                  tooltip: 'Remove product',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          _photoPicker(product),
          const SizedBox(height: 10),
          TextFormField(
            controller: product.title,
            decoration: const InputDecoration(labelText: 'Product title'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Add a title' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: product.description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: product.price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price in USD',
              prefixText: '\$ ',
            ),
            validator: (value) {
              final amount = double.tryParse(value ?? '');
              return amount == null || amount <= 0
                  ? 'Enter a price greater than zero'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: product.category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: marketplaceCategories
                .skip(1)
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => product.category = value ?? product.category),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: product.condition,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: productConditions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => product.condition = value ?? product.condition),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: product.location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Location',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Add your location'
                : null,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create a post')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          AbsorbPointer(
            absorbing: _busy,
            child: Column(
              children: [
                TextFormField(
                  controller: _caption,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Post message (optional)',
                    hintText: 'Write a message for these products',
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
                  label: const Text('Add another product'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label:
                'Publish ${_products.length} product${_products.length == 1 ? '' : 's'} in one post',
            busy: _busy,
            onPressed: _publish,
          ),
        ],
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
            tooltip: 'Remove photo',
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
