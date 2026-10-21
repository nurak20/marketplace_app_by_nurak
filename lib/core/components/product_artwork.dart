import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';

class ProductArtwork extends StatelessWidget {
  const ProductArtwork({
    super.key,
    this.category,
    this.height = 180,
    this.imageUrl,
    this.productId,
  });

  final String? category;
  final double height;
  final String? imageUrl;
  final int? productId;

  @override
  Widget build(BuildContext context) {
    if (imageUrl?.isNotEmpty == true) return _networkImage(imageUrl!);
    if (productId != null) {
      return FutureBuilder<String?>(
        future: api.primaryProductImage(productId!),
        builder: (context, snapshot) => snapshot.data?.isNotEmpty == true
            ? _networkImage(snapshot.data!)
            : _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _networkImage(String url) => Image.network(
    api.resolveUrl(url),
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _placeholder(),
  );

  Widget _placeholder() => Container(
    height: height,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [StyleColor.softMint, StyleColor.sand],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: Icon(_icon, size: StyleColor.iconSize, color: StyleColor.ink),
  );

  IconData get _icon {
    final value = category?.toLowerCase() ?? '';
    if (value.contains('elect')) return Icons.devices_other_rounded;
    if (value.contains('fashion')) return Icons.checkroom_rounded;
    if (value.contains('furniture') || value.contains('home')) {
      return Icons.chair_alt_rounded;
    }
    if (value.contains('vehicle')) return Icons.directions_bike_rounded;
    if (value.contains('book')) return Icons.menu_book_rounded;
    return Icons.storefront_rounded;
  }
}
