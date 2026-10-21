import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';
import '../models.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.radius = 22});

  final UserProfile? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final avatarUrl = profile?.avatarUrl?.trim();
    final name = profile?.displayName.trim() ?? '';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final fallback = initials.isEmpty
        ? Icon(
            Icons.person_outline_rounded,
            size: StyleColor.iconSize,
            color: StyleColor.ink,
          )
        : Text(
            initials,
            style: TextStyle(
              color: StyleColor.ink,
              fontSize: radius < 18
                  ? StyleFont.mediumSize
                  : StyleFont.largeSize,
              fontWeight: FontWeight.w400,
            ),
          );

    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: StyleColor.softMint,
        shape: BoxShape.circle,
      ),
      child: avatarUrl?.isNotEmpty == true
          ? Image.network(
              api.resolveUrl(avatarUrl!),
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, sync) =>
                  frame == null && !sync ? fallback : child,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}
