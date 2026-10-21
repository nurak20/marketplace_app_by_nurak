import 'package:flutter/material.dart';

import '../app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: StyleColor.iconSize, color: StyleColor.muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: StyleFont.largeSize,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StyleColor.muted),
          ),
        ],
      ),
    ),
  );
}
