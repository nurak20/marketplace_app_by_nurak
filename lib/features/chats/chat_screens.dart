import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/show_error.dart';
import '../../core/components/user_avatar.dart';
import '../../core/models.dart';
import '../../core/singleton.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<List<MarketplaceMessage>> _inbox;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _inbox = _fetchInbox();
  }

  Future<List<MarketplaceMessage>> _fetchInbox() => api.inbox();

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(title: 'Messages').build(context),

    body: FutureBuilder<List<MarketplaceMessage>>(
      future: _inbox,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return _ErrorRetry(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _load();
            }),
          );
        }
        final messages = snapshot.data!;
        final currentUserId = Singleton.instance.account?.profile.id ?? -1;
        final threads = <int, MarketplaceMessage>{};
        for (final message in messages) {
          final id = message.senderId == currentUserId
              ? message.receiverId
              : message.senderId;
          threads.putIfAbsent(id, () => message);
        }
        if (threads.isEmpty) {
          return const EmptyState(
            title: 'No chats yet',
            message:
                'Open a listing and message the seller to start a conversation.',
            icon: Icons.chat_bubble_outline_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: threads.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == threads.length) {
              return const SizedBox(
                height: StyleSpacing.bottomContentClearance,
              );
            }
            final userId = threads.keys.elementAt(index);
            final message = threads[userId]!;
            final profile = message.contactFor(currentUserId);
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: UserAvatar(profile: profile),
                title: Text(
                  profile?.displayName ?? 'Member #$userId',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                subtitle: Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/chats/$userId'),
              ),
            );
          },
        );
      },
    ),
  );
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.userId, this.productId});
  final int userId;
  final int? productId;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  late Future<(Account, UserProfile?, List<MarketplaceMessage>, Product?)>
  _conversation;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _conversation = _fetchConversation();
  }

  Future<(Account, UserProfile?, List<MarketplaceMessage>, Product?)>
  _fetchConversation() async {
    final account = Singleton.instance.account;
    if (account == null) {
      throw StateError('The signed-in account is unavailable.');
    }
    final messages = (await api.conversation(widget.userId)).items.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final contact = messages.isEmpty
        ? null
        : messages.last.contactFor(account.profile.id);
    Product? product;
    for (final message in messages) {
      if (message.product != null) {
        product = message.product;
        break;
      }
    }
    return (account, contact, messages, product);
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _conversation;
      await api.sendMessage(
        widget.userId,
        content,
        productId: widget.productId,
      );
      _composer.clear();
      if (mounted) _reloadAndScrollToLatest();
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reloadAndScrollToLatest() {
    setState(() {
      _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(
      title: 'Chat',
      showNotifications: false,
      showProfileAvatar: false,
    ).build(context),
    body:
        FutureBuilder<
          (Account, UserProfile?, List<MarketplaceMessage>, Product?)
        >(
          future: _conversation,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              return _ErrorRetry(
                error: snapshot.error!,
                onRetry: () => setState(() {
                  _load();
                }),
              );
            }
            final (account, contact, messages, product) = snapshot.data!;
            return Column(
              children: [
                if (product != null)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                    child: ListTile(
                      leading: SizedBox(
                        width: 44,
                        height: 44,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: ProductArtwork(
                            category: product.category,
                            height: 44,
                            image: product.primaryImage,
                          ),
                        ),
                      ),
                      title: Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/products/${product.id}'),
                    ),
                  ),
                Expanded(
                  child: messages.isEmpty
                      ? const EmptyState(
                          title: 'Say hello',
                          message: 'Ask a question or arrange a time to meet.',
                          icon: Icons.chat_bubble_outline_rounded,
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            14,
                            12,
                            14,
                            StyleSpacing.bottomContentClearance,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final mine = message.senderId == account.profile.id;
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!mine) ...[
                                    UserAvatar(profile: contact, radius: 14),
                                    const SizedBox(width: 7),
                                  ],
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width *
                                          .68,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? StyleColor.ink
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(17),
                                        topRight: const Radius.circular(17),
                                        bottomLeft: Radius.circular(
                                          mine ? 17 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          mine ? 4 : 17,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      message.content,
                                      style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : StyleColor.ink,
                                      ),
                                    ),
                                  ),
                                  if (mine) ...[
                                    const SizedBox(width: 7),
                                    UserAvatar(
                                      profile: account.profile,
                                      radius: 14,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _composer,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Write a message',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          tooltip: 'Send message',
                          icon: const Icon(Icons.send_rounded),
                          style: IconButton.styleFrom(
                            iconSize: StyleColor.iconSize,
                            backgroundColor: StyleColor.ink,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
  );

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: StyleColor.iconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(Api.errorMessage(error), textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
