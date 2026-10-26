import 'package:flutter/material.dart';

import '../app_theme.dart';

class MKButton extends StatelessWidget {
  const MKButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.iconOnly = false,
  });

  final String title;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool selected;
  final bool iconOnly;

  static const double wideLayoutBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final showTitle =
        !iconOnly && MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
    final color = selected ? StyleColor.ink : StyleColor.muted;
    final background = selected
        ? StyleColor.softMint.withValues(alpha: .65)
        : Colors.transparent;

    if (showTitle) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(title),
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: onPressed,
      tooltip: title,
      icon: icon,
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
