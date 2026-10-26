import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    label: 'Create product',
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
      extendBody: false,
      body: widget.child,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: Colors.white.withValues(alpha: 0.7), // 70% opacity
            child: SafeArea(
              top: false,
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
    final color = selected ? StyleColor.ink : StyleColor.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label, // kept for screen readers, just not shown
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: ExcludeSemantics(
            child: Center(
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: StyleColor.iconSize,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
