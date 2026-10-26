import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../singleton.dart';
import 'mk_button.dart';
import 'user_avatar.dart';

class MarketplaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarketplaceAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.titleContent,
    this.showNotifications = true,
    this.showProfileAvatar = true,
  });

  final String title;
  final List<Widget> actions;
  final Widget? titleContent;
  final bool showNotifications;
  final bool showProfileAvatar;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    title: InkWell(
      onTap: () => context.go('/'),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'lib/assets/logo/mk27_app_logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                titleContent ??
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
    actions: [
      ...actions,
      if (showNotifications)
        MKButton(
          title: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => context.push('/notifications'),
        ),
      if (showProfileAvatar)
        Consumer<Singleton>(
          builder: (context, singleton, _) => MKButton(
            title: 'Profile',
            icon: UserAvatar(
              profile: singleton.userProfile,
              radius: 17,
              size: 34,
            ),
            onPressed: () => context.go('/me'),
          ),
        ),
      const SizedBox(width: 4),
    ],
  );
}
