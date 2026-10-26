import 'package:flutter/material.dart';

/// Applies the safe-area inset supplied by AdaptiveScaffold and gives page
/// content a Material ancestor for Material controls.
class AdaptiveSafeBody extends StatelessWidget {
  const AdaptiveSafeBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Material(type: MaterialType.transparency, child: child),
  );
}
