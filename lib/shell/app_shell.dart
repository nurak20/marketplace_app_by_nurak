import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/app_theme.dart';
import '../core/models.dart';
import '../core/profile_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Future<Account?> _account;

  static const _tabs = ['/', '/saved', '/sell', '/chats', '/me'];

  static const _items = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    (label: 'Saved', icon: Icons.favorite_border, selectedIcon: Icons.favorite),
    (
      label: 'Sell',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
    ),
    (
      label: 'Chats',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _account = _loadAccount();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location &&
        (oldWidget.location == '/me' || widget.location == '/me')) {
      _account = _loadAccount();
    }
  }

  Future<Account?> _loadAccount() async {
    try {
      return await api.me();
    } catch (_) {
      return null;
    }
  }

  String _profileLabel(UserProfile? user) {
    if (user == null) return 'Profile';
    final fullName = user.fullName?.trim();
    if (fullName?.isNotEmpty == true) return fullName!;
    final username = user.username.trim();
    return username.isNotEmpty ? username : 'Profile';
  }

  /// Avatar with the same footprint as the other tab icons.
  Widget _profileIcon(UserProfile? user, Color color, bool selected) {
    final avatarUrl = user?.avatarUrl;
    final fallback = Icon(
      Icons.person_rounded,
      size: StyleColor.iconSize * .7,
      color: color,
    );

    return Container(
      width: StyleColor.iconSize,
      height: StyleColor.iconSize,
      decoration: BoxDecoration(
        color: StyleColor.softMint,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: selected ? 2 : 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: avatarUrl?.isNotEmpty == true
          ? Image.network(
              api.resolveUrl(avatarUrl!),
              width: StyleColor.iconSize,
              height: StyleColor.iconSize,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, sync) =>
                  frame == null && !sync ? fallback : child,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }

  /// One tab. Every tab, including profile, uses the same layout and size.
  Widget _navigationItem({
    required int index,
    required String label,
    required Widget icon,
    required bool selected,
    required Color color,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () => context.go(_tabs[index]),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: StyleColor.iconSize,
                  height: StyleColor.iconSize,
                  child: icon,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: StyleFont.mediumSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabIndex = _tabs.indexOf(widget.location);

    final selectedColor = scheme.primary;
    final unselectedColor = scheme.onSurfaceVariant;

    return Scaffold(
      extendBody: false,
      body: widget.child,
      bottomNavigationBar: tabIndex < 0
          ? null
          : ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedBuilder(
                  animation: profileProvider,
                  builder: (context, _) => FutureBuilder<Account?>(
                    future: _account,
                    builder: (context, snapshot) {
                      final profile =
                          profileProvider.profile ?? snapshot.data?.profile;

                      return Container(
                        color: scheme.surface.withValues(alpha: 0.8),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: List.generate(_tabs.length, (index) {
                                final selected = tabIndex == index;
                                final color = selected
                                    ? selectedColor
                                    : unselectedColor;

                                if (index == _tabs.length - 1) {
                                  return _navigationItem(
                                    index: index,
                                    label: _profileLabel(profile),
                                    icon: _profileIcon(
                                      profile,
                                      color,
                                      selected,
                                    ),
                                    selected: selected,
                                    color: color,
                                  );
                                }

                                final item = _items[index];
                                return _navigationItem(
                                  index: index,
                                  label: item.label,
                                  icon: Icon(
                                    selected ? item.selectedIcon : item.icon,
                                    size: StyleColor.iconSize,
                                    color: color,
                                  ),
                                  selected: selected,
                                  color: color,
                                );
                              }),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
