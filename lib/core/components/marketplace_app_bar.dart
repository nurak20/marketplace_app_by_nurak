import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../notification_hub.dart';
import '../singleton.dart';

/// Shared Material app bar used by every screen.
///
/// Layout: [ logo ]  Title  [ actions ] [ bell ] [ management ] [ profile ]
///
/// ```dart
/// Scaffold(
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
    this.showManagement = true,
    this.showProfileAvatar = true,
  });

  final String title;
  final List<Widget> actions;
  final Widget? titleContent;
  final bool showNotifications;
  final bool showManagement;
  final bool showProfileAvatar;

  AppBar build(BuildContext context) => AppBar(
    titleSpacing: 0,
    leadingWidth: 56,
    leading: IconButton(
      tooltip: 'nav.home'.tr(),
      onPressed: () => context.go('/'),
      icon: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'lib/assets/logo/mk27_app_logo.png',
          width: 26,
          height: 26,
          fit: BoxFit.cover,
        ),
      ),
    ),
    title: titleContent ?? (title.isEmpty ? null : Text(title)),
    actions: [
      ...actions,
      if (showNotifications)
        Consumer<NotificationHub>(
          builder: (context, hub, _) => IconButton(
            tooltip: 'profile.notifications'.tr(),
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: hub.unreadCount > 0,
              label: Text(hub.unreadCount > 99 ? '99+' : '${hub.unreadCount}'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ),
      if (showManagement &&
          Singleton.instance.account?.canAccessManagement == true)
        IconButton(
          tooltip: 'profile.management'.tr(),
          onPressed: () => context.go('/management'),
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
      if (showProfileAvatar)
        IconButton(
          tooltip: 'profile.title'.tr(),
          onPressed: () => context.go('/me'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
      const SizedBox(width: 4),
    ],
  );
}
