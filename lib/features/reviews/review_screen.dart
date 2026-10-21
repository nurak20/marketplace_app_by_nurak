import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review this deal')),
    body: FutureBuilder<Product>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
          ],
        );
      },
    ),
  );

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }
}
