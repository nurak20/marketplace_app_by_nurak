import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/components/localized_builder.dart';
import '../core/singleton.dart';

const _destinations = <_AppNavigationDestination>[
  _AppNavigationDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'nav.home',
    location: '/',
  ),
  _AppNavigationDestination(
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
    label: 'nav.favorite',
    location: '/saved',
  ),
  _AppNavigationDestination(
    icon: Icons.add_box_outlined,
    selectedIcon: Icons.add_box_rounded,
    label: 'nav.create',
    location: '/sell',
  ),
  _AppNavigationDestination(
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    label: 'nav.message',
    location: '/chats',
  ),
  _AppNavigationDestination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'nav.user',
    location: '/me',
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    context.watchLocale();
    final canSell = context.select<Singleton, bool>(
      (state) => state.account?.canSell ?? true,
    );
    final destinations = canSell
        ? _destinations
        : _destinations.where((item) => item.location != '/sell').toList();
    final location = this.location;
    final selectedLocation = switch (location) {
      '/saved' => '/saved',
      '/sell' => '/sell',
      '/chats' => '/chats',
      '/me' => '/me',
      _ when location.startsWith('/chats/') => '/chats',
      _ => '/',
    };
    final selectedIndex = destinations.indexWhere(
      (destination) => destination.location == selectedLocation,
    );
    final safeSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;

    final isConversation = location.startsWith('/chats/');
    final isManagement =
        location == '/management' || location.startsWith('/management/');
    final isPayroll = location == '/payroll' || location == '/me/payslips';
    final isReports = location == '/reports';
    final isChangePassword = location == '/me/change-password';
    // Derived only from the current location and the keyboard state so the bar
    // can never get stuck hidden after a page is closed or replaced.
    final showBar =
        location != '/search' &&
        !isConversation &&
        !isManagement &&
        !isPayroll &&
        !isReports &&
        !isChangePassword &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    // Let each page scaffold handle the status-bar inset; applying it
    // around the whole scaffold shifts page content down a second time.
    final pageBody = SafeArea(top: false, bottom: false, child: child);

    return Scaffold(
      extendBody: false,
      body: ClipRect(child: pageBody),
      backgroundColor: Colors.white,
      bottomNavigationBar: showBar
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(40),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < destinations.length;
                          index++
                        )
                          Expanded(
                            child: _BottomNavigationItem(
                              destination: destinations[index],
                              selected: safeSelectedIndex == index,
                              onTap: () =>
                                  context.go(destinations[index].location),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
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
      label: destination.label.tr(),
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
                          destination.label.tr(),
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
