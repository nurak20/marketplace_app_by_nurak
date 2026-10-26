import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import 'product_artwork.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onSave,
    this.isSaved = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final bool isSaved;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ProductArtwork(
                category: product.category,
                height: 150,
                image: product.primaryImage,
              ),
              if (onSave != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton.filledTonal(
                    onPressed: onSave,
                    tooltip: isSaved ? 'Remove from saved' : 'Save item',
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                    ),
                    style: IconButton.styleFrom(
                      iconSize: StyleColor.iconSize,
                      backgroundColor: Colors.white.withValues(alpha: .92),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: StyleColor.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: StyleFont.mediumSize,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${product.location ?? 'Cambodia'}  ·  ${product.condition.replaceAll('_', ' ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StyleColor.muted,
                    fontSize: StyleFont.mediumSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
