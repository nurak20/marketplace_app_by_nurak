import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Label/value line used in detail sheets and summary cards.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: StyleColor.muted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: emphasize ? 16 : null,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}
