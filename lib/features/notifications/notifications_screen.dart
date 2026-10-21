import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<ApiPage<MarketplaceNotification>> _notifications;
  final Set<int> _marking = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _notifications = api.notifications();
  }

  Future<void> _markRead(int id) async {
    setState(() => _marking.add(id));
    try {
      await api.markNotificationRead(id);
      if (mounted) {
        setState(() {
          _load();
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _marking.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<ApiPage<MarketplaceNotification>>(
      future: _notifications,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _NotificationError(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _load();
            }),
          );
        }
        final items = snapshot.data?.items ?? const <MarketplaceNotification>[];
        if (items.isEmpty) {
          return const EmptyState(
            title: 'You are all caught up',
            message:
                'We will let you know when something needs your attention.',
            icon: Icons.notifications_none_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              color: item.isRead ? Colors.white : StyleColor.unreadSurface,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: StyleColor.accent.withValues(alpha: .25),
                  child: Icon(_iconFor(item.type), color: StyleColor.ink),
                ),
                title: Text(
                  item.message,
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Text(
                  item.type.replaceAll('_', ' ').toLowerCase(),
                  style: const TextStyle(color: StyleColor.muted),
                ),
                trailing: item.isRead
                    ? null
                    : IconButton(
                        tooltip: 'Mark as read',
                        onPressed: _marking.contains(item.id)
                            ? null
                            : () => _markRead(item.id),
                        icon: const Icon(Icons.done_rounded),
                      ),
              ),
            );
          },
        );
      },
    ),
  );

  IconData _iconFor(String type) => switch (type) {
    'MESSAGE' => Icons.chat_bubble_outline_rounded,
    'FRIEND_REQUEST' => Icons.person_add_alt_1_rounded,
    'REVIEW' => Icons.star_outline_rounded,
    'LIKE' => Icons.favorite_border_rounded,
    'COMMENT' => Icons.mode_comment_outlined,
    _ => Icons.notifications_none_rounded,
  };
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
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
