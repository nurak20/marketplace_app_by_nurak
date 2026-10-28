import 'package:flutter/material.dart';

/// A 12-column row that stacks its children on narrow screens.
class ResponsiveColumn {
  const ResponsiveColumn.span({required this.child, this.span = 12});

  final Widget child;
  final int span;
}

class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({super.key, required this.children});

  final List<ResponsiveColumn> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final column in children)
            SizedBox(
              width: compact
                  ? constraints.maxWidth
                  : constraints.maxWidth * column.span / 12 - 10,
              child: column.child,
            ),
        ],
      );
    },
  );
}
