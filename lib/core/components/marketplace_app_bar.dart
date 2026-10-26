import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Same name and constructor as before. Because [AdaptiveAppBar] is a config
/// object (not a widget), call [build] to get it and pass it to
/// [AdaptiveScaffold]:
///
/// ```dart
/// AdaptiveScaffold(
///   appBar: const MarketplaceAppBar(title: 'Home').build(context),
///   body: ...,
/// )
/// ```
class MarketplaceAppBar {
  const MarketplaceAppBar({
    this.title = '',
    this.actions = const [],
    this.titleContent,
    this.showNotifications = true,
    this.showProfileAvatar = true,
  });

  final String title;
  final List<AdaptiveAppBarAction> actions;
  final Widget? titleContent;
  final bool showNotifications;
  final bool showProfileAvatar;

  AdaptiveAppBar build(BuildContext context) => AdaptiveAppBar(
    useNativeToolbar: true,
    leading: InkWell(
      onTap: () => context.go('/'),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'lib/assets/logo/mk27_app_logo.png',
          width: 34,
          height: 34,
          fit: BoxFit.cover,
        ),
      ),
    ),
    // Title stays hidden, as before:
    // titleContent ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)
    actions: [
      ...actions,
      if (showNotifications)
        AdaptiveAppBarAction(
          iosSymbol: 'bell',
          icon: Icons.notifications_none_rounded,
          label: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
      // if (showProfileAvatar)
      AdaptiveAppBarAction(
        iosSymbol: 'person.crop.circle',
        icon: Icons.account_circle_outlined,
        label: 'Profile',
        onPressed: () => context.go('/me'),
      ),
    ],
  );
}

/// Keeps a page's content clear of the floating iOS 26+ Liquid Glass toolbar
/// and tab bar.
///
/// Wrap the `body` of every [AdaptiveScaffold] with it:
///
/// ```dart
/// AdaptiveScaffold(
///   appBar: const MarketplaceAppBar().build(context),
///   body: AdaptiveSafeBody(
///     child: ListView(padding: const EdgeInsets.all(16), children: [...]),
///   ),
/// )
/// ```
///
/// It is a normal [SafeArea]. The package already insets MediaQuery by the
/// toolbar height, and the `minimum` values below only apply when that inset
/// is smaller (SafeArea takes the larger value, so nothing is added twice).
