import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_theme.dart';

/// App-wide adaptive app-bar configuration for [AdaptiveScaffold].
///
/// Layout (iOS 26+ Liquid Glass, like the package template):
///
///   [ logo ]            Title            [ bell ]  [ profile ]
///    left capsule     centered title     separate right capsules
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
    title: title.isEmpty ? null : title,
    titleWidget: titleContent,
    tintColor: StyleColor.ink,
    actions: [
      // Left capsule: logo -> Home. The flexible spacer pushes everything
      // after it to the right, so the title sits in the middle.
      AdaptiveAppBarAction(
        iconWidget: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'lib/assets/logo/mk27_app_logo.png',
            width: 26,
            height: 26,
            fit: BoxFit.cover,
          ),
        ),
        iosSymbol: 'house', // fallback symbol
        icon: Icons.home_outlined,
        label: 'Home',
        onPressed: () => context.go('/'),
        spacerAfter: ToolbarSpacerType.flexible,
      ),

      // Right side: each action in its own capsule (fixed gap between them).
      ...actions,
      // if (showNotifications)
      //   AdaptiveAppBarAction(
      //     iosSymbol: 'bell',
      //     icon: Icons.notifications_none_rounded,
      //     label: 'Notifications',
      //     onPressed: () => context.push('/notifications'),
      //     spacerAfter: showProfileAvatar ? ToolbarSpacerType.fixed : null,
      //   ),
      if (showProfileAvatar)
        AdaptiveAppBarAction(
          iosSymbol: 'person.crop.circle',
          icon: Icons.account_circle_outlined,
          label: 'Profile',
          onPressed: () => context.go('/me'),
        ),
    ],
  );
}
