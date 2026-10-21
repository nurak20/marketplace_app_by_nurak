import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/show_error.dart';
import '../../core/components/user_avatar.dart';
import '../../core/models.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<(Account, List<MarketplaceMessage>, Map<int, UserProfile>)>
  _inbox;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _inbox = _fetchInbox();
  }

  Future<(Account, List<MarketplaceMessage>, Map<int, UserProfile>)>
  _fetchInbox() async {
    final account = await api.me();
    final messages = await api.inbox();
    final userIds = messages
        .map(
          (message) => message.senderId == account.profile.id
              ? message.receiverId
              : message.senderId,
        )
        .toSet();
    final profiles = <int, UserProfile>{};
    await Future.wait(
      userIds.map((id) async {
        try {
          profiles[id] = UserProfile.fromJson(await api.profile(id));
        } catch (_) {}
      }),
    );
    return (account, messages, profiles);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chats')),
    body: FutureBuilder<(Account, List<MarketplaceMessage>, Map<int, UserProfile>)>(
      future: _inbox,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorRetry(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _load();
            }),
          );
        }
        final (account, messages, profiles) = snapshot.data!;
        final threads = <int, MarketplaceMessage>{};
        for (final message in messages) {
          final id = message.senderId == account.profile.id
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
          itemCount: threads.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final userId = threads.keys.elementAt(index);
            final message = threads[userId]!;
            final profile = profiles[userId];
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
    final account = await api.me();
    await api.markConversationRead(widget.userId);
    final results = await Future.wait([
      api.conversation(widget.userId),
      api
          .profile(widget.userId)
          .then<UserProfile?>((json) => UserProfile.fromJson(json))
          .catchError((_) => null),
      if (widget.productId != null)
        api.product(widget.productId!).then<Product?>((product) => product)
      else
        Future<Product?>.value(null),
    ]);
    final messages = (results[0] as ApiPage<MarketplaceMessage>).items.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return (
      account,
      results[1] as UserProfile?,
      messages,
      results[2] as Product?,
    );
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    Set<int> previousMessageIds = {};
    int? currentUserId;
    try {
      final loadedConversation = await _conversation;
      previousMessageIds = loadedConversation.$3
          .map((message) => message.id)
          .toSet();
      currentUserId = loadedConversation.$1.profile.id;
      await api.sendMessage(
        widget.userId,
        content,
        productId: widget.productId,
      );
      _composer.clear();
      if (mounted) _reloadAndScrollToLatest();
    } catch (error) {
      final saved =
          currentUserId != null &&
          await _messageWasSaved(content, previousMessageIds, currentUserId);
      if (!mounted) return;
      if (saved) {
        _composer.clear();
        _reloadAndScrollToLatest();
        await GlobalPopupDialog.success(context, message: 'Message sent.');
      } else {
        showError(context, error);
      }
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

  Future<bool> _messageWasSaved(
    String content,
    Set<int> previousMessageIds,
    int currentUserId,
  ) async {
    try {
      final latest = await api.conversation(widget.userId);
      return latest.items.any(
        (message) =>
            !previousMessageIds.contains(message.id) &&
            message.senderId == currentUserId &&
            message.receiverId == widget.userId &&
            message.content == content &&
            message.productId == widget.productId,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title:
          FutureBuilder<
            (Account, UserProfile?, List<MarketplaceMessage>, Product?)
          >(
            future: _conversation,
            builder: (context, snapshot) {
              final profile = snapshot.data?.$2;
              return Row(
                children: [
                  UserAvatar(profile: profile, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile?.displayName ?? 'Member #${widget.userId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
    ),
    body:
        FutureBuilder<
          (Account, UserProfile?, List<MarketplaceMessage>, Product?)
        >(
          future: _conversation,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
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
