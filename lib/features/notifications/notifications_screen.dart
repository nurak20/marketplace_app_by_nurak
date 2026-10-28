import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';
import '../../core/notification_hub.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationHub.instance.refresh();
    });
  }

  Future<void> _readAll() async {
    try {
      await NotificationHub.instance.markAllRead();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _open(MarketplaceNotification item) async {
    if (!item.isRead) {
      try {
        await NotificationHub.instance.markRead(item.id);
      } catch (_) {
        // Navigation should still work if the read receipt fails.
      }
    }
    if (!mounted) return;
    switch (item.type) {
      case 'POST':
      case 'COMMENT':
      case 'LIKE':
      case 'REVIEW':
        final productId = item.productId;
        if (productId == null) return;
        final postId = item.postId;
        await context.push(
          '/products/$productId${postId == null ? '' : '?postId=$postId'}',
        );
      case 'MESSAGE':
        final actorId = item.actorId;
        if (actorId == null) return;
        await context.push('/chats/$actorId');
      case 'PASSWORD_CHANGE':
        await context.push('/me/change-password');
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) {
      final hub = context.watch<NotificationHub>();
      return Scaffold(
        appBar: MarketplaceAppBar(
          title: 'profile.notifications'.tr(),
          showNotifications: false,
          showProfileAvatar: false,
          actions: [
            if (hub.unreadCount > 0)
              TextButton(
                onPressed: _readAll,
                child: Text('notifications.readAll'.tr()),
              ),
          ],
        ).build(context),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: hub.refresh,
                  child: _body(context, hub),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _body(BuildContext context, NotificationHub hub) {
    if (hub.isLoading && hub.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hub.error != null && hub.items.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * .2),
          _NotificationError(error: hub.error!, onRetry: () => hub.refresh()),
        ],
      );
    }
    final items = hub.items;
    if (items.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * .14),
          EmptyState(
            title: 'notifications.emptyTitle'.tr(),
            message: 'notifications.emptyMessage'.tr(),
            icon: Icons.notifications_none_rounded,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return const SizedBox(height: StyleSpacing.bottomContentClearance);
        }
        return _NotificationCard(
          item: items[index],
          onTap: () => _open(items[index]),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final MarketplaceNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actor = item.actor;
    final avatarUrl = actor?.avatarUrl?.trim();
    return Card(
      margin: EdgeInsets.zero,
      color: item.isRead ? Colors.white : StyleColor.unreadSurface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: StyleColor.accent.withValues(alpha: .28),
                foregroundImage: avatarUrl?.isNotEmpty == true
                    ? NetworkImage(api.resolveUrl(avatarUrl!))
                    : null,
                child: avatarUrl?.isNotEmpty == true
                    ? null
                    : actor != null
                    ? Text(
                        actor.initial,
                        style: const TextStyle(
                          color: StyleColor.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Icon(_iconFor(item.type), color: StyleColor.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            actor?.displayName ?? _labelFor(item.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: StyleColor.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (item.createdAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel(item.createdAt!),
                            style: const TextStyle(
                              color: StyleColor.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _labelFor(item.type),
                      style: const TextStyle(
                        color: StyleColor.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (item.message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        if (item.itemCount > 0)
                          _MetaLine(
                            icon: Icons.inventory_2_outlined,
                            label: 'notifications.itemCount'.tr(
                              namedArgs: {'count': '${item.itemCount}'},
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: StyleColor.muted),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'POST' => Icons.sell_outlined,
    'MESSAGE' => Icons.chat_bubble_outline_rounded,
    'FRIEND_REQUEST' => Icons.person_add_alt_1_rounded,
    'REVIEW' => Icons.star_outline_rounded,
    'LIKE' => Icons.favorite_border_rounded,
    'COMMENT' => Icons.mode_comment_outlined,
    'PASSWORD_CHANGE' => Icons.lock_outline_rounded,
    'PAYROLL' => Icons.payments_outlined,
    _ => Icons.notifications_none_rounded,
  };

  static String _labelFor(String type) => switch (type) {
    'POST' => 'notifications.type.post'.tr(),
    'MESSAGE' => 'notifications.type.message'.tr(),
    'FRIEND_REQUEST' => 'notifications.type.friendRequest'.tr(),
    'REVIEW' => 'notifications.type.review'.tr(),
    'LIKE' => 'notifications.type.like'.tr(),
    'COMMENT' => 'notifications.type.comment'.tr(),
    'PASSWORD_CHANGE' => 'notifications.type.passwordChange'.tr(),
    'PAYROLL' => 'notifications.type.payroll'.tr(),
    _ => type.replaceAll('_', ' ').toLowerCase(),
  };

  static String _timeLabel(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'notifications.justNow'.tr();
    if (difference.inMinutes < 60) {
      return 'notifications.minutesAgo'.tr(
        namedArgs: {'count': '${difference.inMinutes}'},
      );
    }
    if (difference.inHours < 24) {
      return 'notifications.hoursAgo'.tr(
        namedArgs: {'count': '${difference.inHours}'},
      );
    }
    if (difference.inDays < 7) {
      return 'notifications.daysAgo'.tr(
        namedArgs: {'count': '${difference.inDays}'},
      );
    }
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: StyleColor.muted),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(color: StyleColor.muted, fontSize: 12),
      ),
    ],
  );
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          size: StyleColor.iconSize,
          color: StyleColor.muted,
        ),
        const SizedBox(height: 10),
        Text(Api.errorMessage(error)),
        TextButton(onPressed: onRetry, child: Text('common.retry'.tr())),
      ],
    ),
  );
}
