import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import '../core/app_theme.dart';

const _destinations = <_AppNavigationDestination>[
  _AppNavigationDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
    location: '/',
  ),
  _AppNavigationDestination(
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
    label: 'Favorite',
    location: '/saved',
  ),
  _AppNavigationDestination(
    icon: Icons.add_box_outlined,
    selectedIcon: Icons.add_box_rounded,
    label: 'Create',
    location: '/sell',
  ),
  _AppNavigationDestination(
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    label: 'Message',
    location: '/chats',
  ),
  _AppNavigationDestination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'User',
    location: '/me',
  ),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final selectedIndex = switch (location) {
      '/saved' => 1,
      '/sell' => 2,
      '/chats' => 3,
      '/me' => 4,
      _ when location.startsWith('/chats/') => 3,
      _ => 0,
    };

    return Scaffold(
      // Keep the page viewport above the navigation bar so the two never overlap.
      extendBody: false,
      body: ClipRect(child: widget.child),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: AdaptiveBlurView(
              blurStyle: BlurStyle.systemThinMaterial,
              borderRadius: BorderRadius.circular(40),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    for (var index = 0; index < _destinations.length; index++)
                      Expanded(
                        child: _BottomNavigationItem(
                          destination: _destinations[index],
                          selected: selectedIndex == index,
                          onTap: () =>
                              context.go(_destinations[index].location),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppNavigationDestination {
  const _AppNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.location,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String location;
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AppNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF2563EB);
    final color = selected ? selectedColor : const Color(0xFF25282B);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: selected ? 1.04 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Column(
                      key: ValueKey(selected),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: StyleColor.iconSize,
                          color: color,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            height: 1,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
