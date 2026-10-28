import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds its subtree when the app locale changes.
///
/// Pages use this instead of depending on a build context of their own, so
/// every `.tr()` string refreshes immediately when the language is switched
/// while the page state (scroll position, forms, loaded data) is preserved.
class LocalizedBuilder extends StatelessWidget {
  const LocalizedBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context);
    return builder(context);
  }
}

extension LocaleRebuild on BuildContext {
  /// Subscribes the calling widget to locale changes.
  void watchLocale() {
    EasyLocalization.of(this);
  }
}
