import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/product_artwork.dart';
import '../../core/components/show_error.dart';
import '../../core/components/user_avatar.dart';
import '../../core/models.dart';
import '../../core/notification_hub.dart';
import '../../core/singleton.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<List<_ChatThread>> _inbox;
  final Map<int, UserProfile> _contacts = {};
  StreamSubscription<MarketplaceMessage>? _messages;

  @override
  void initState() {
    super.initState();
    _load();
    _messages = NotificationHub.instance.messageEvents.listen((_) {
      if (mounted) setState(_load);
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  void _load() {
    _inbox = _fetchInbox();
  }

  Future<List<_ChatThread>> _fetchInbox() async {
    final messages = await api.inbox();
    final currentUserId = Singleton.instance.account?.profile.id ?? -1;
    final threads = <int, MarketplaceMessage>{};
    for (final message in messages) {
      final id = message.senderId == currentUserId
          ? message.receiverId
          : message.senderId;
      threads.putIfAbsent(id, () => message);
    }
    return Future.wait(
      threads.entries.map((entry) async {
        final contact =
            entry.value.contactFor(currentUserId) ??
            _contacts[entry.key] ??
            await _profile(entry.key);
        if (contact != null) _contacts[entry.key] = contact;
        return _ChatThread(
          userId: entry.key,
          message: entry.value,
          contact: contact,
        );
      }),
    );
  }

  Future<UserProfile?> _profile(int userId) async {
    try {
      return UserProfile.fromJson(await api.profile(userId, silent: true));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(title: 'chat.title'.tr()).build(context),

      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<_ChatThread>>(
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
                final threads = snapshot.data!;
                if (threads.isEmpty) {
                  return EmptyState(
                    title: 'chat.emptyTitle'.tr(),
                    message: 'chat.emptyMessage'.tr(),
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
                    final thread = threads[index];
                    final profile = thread.contact;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: UserAvatar(profile: profile),
                        title: Text(
                          profile?.displayName ??
                              'chat.memberFallback'.tr(
                                namedArgs: {'id': '${thread.userId}'},
                              ),
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                        subtitle: Text(
                          thread.message.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/chats/${thread.userId}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
  StreamSubscription<MarketplaceMessage>? _messagesSub;
  Account? _account;
  UserProfile? _contact;
  List<MarketplaceMessage> _messages = const [];
  final List<MarketplaceMessage> _pending = [];
  final Set<int> _inflight = {};
  int _nextPendingId = -1;
  Product? _product;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _messagesSub = NotificationHub.instance.messageEvents.listen(_onMessage);
  }

  Future<void> _load() async {
    final account = Singleton.instance.account;
    if (account == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = StateError('chat.accountUnavailable'.tr());
      });
      return;
    }
    try {
      final fetched = (await api.conversation(
        widget.userId,
        silent: true,
      )).items.toList()..sort((a, b) => a.id.compareTo(b.id));
      if (!mounted) return;
      final merged = _merge(fetched);
      UserProfile? peer = _contact;
      if (peer == null) {
        try {
          peer = UserProfile.fromJson(
            await api.profile(widget.userId, silent: true),
          );
        } catch (_) {
          peer = _contactOf(merged, account.profile.id);
        }
        if (!mounted) return;
      }
      setState(() {
        _settlePending(fetched);
        _account = account;
        _messages = merged;
        _contact = peer;
        _product = _productOf(merged);
        _error = null;
        _loading = false;
      });
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _account = account;
        _error = error;
        _loading = false;
      });
    }
  }

  /// Keeps messages that arrived over the socket after the request started.
  List<MarketplaceMessage> _merge(List<MarketplaceMessage> fetched) {
    final ids = fetched.map((message) => message.id).toSet();
    final merged = [
      ...fetched,
      ..._messages.where((message) => !ids.contains(message.id)),
    ];
    merged.sort((a, b) => a.id.compareTo(b.id));
    return merged;
  }

  UserProfile? _contactOf(
    List<MarketplaceMessage> messages,
    int currentUserId,
  ) {
    if (_contact != null) return _contact;
    for (final message in messages.reversed) {
      final contact = message.contactFor(currentUserId);
      if (contact != null) return contact;
    }
    return null;
  }

  Product? _productOf(List<MarketplaceMessage> messages) {
    if (_product != null) return _product;
    for (final message in messages.reversed) {
      if (message.product != null) return message.product;
    }
    return null;
  }

  void _onMessage(MarketplaceMessage message) {
    final me = _account?.profile.id;
    if (me == null) return;
    final fromPeer =
        message.senderId == widget.userId && message.receiverId == me;
    final toPeer =
        message.senderId == me && message.receiverId == widget.userId;
    if (!fromPeer && !toPeer) return;
    if (_messages.any((item) => item.id == message.id)) return;
    final wasAtBottom = _isAtBottom();
    setState(() {
      _settlePending([message]);
      _messages = [..._messages, message];
      _product = _product ?? message.product;
    });
    if (wasAtBottom || toPeer) _scrollToLatest(animate: true);
  }

  /// Drops optimistic copies once the server-confirmed message arrives.
  void _settlePending(Iterable<MarketplaceMessage> received) {
    final me = _account?.profile.id;
    if (me == null) return;
    for (final message in received) {
      if (message.senderId != me || message.id < 0) continue;
      final index = _pending.indexWhere(
        (item) => item.content == message.content,
      );
      if (index < 0) continue;
      _inflight.remove(_pending[index].id);
      _pending.removeAt(index);
    }
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 80;
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    final account = _account;
    if (content.isEmpty || account == null) return;
    final draft = MarketplaceMessage(
      id: _nextPendingId--,
      senderId: account.profile.id,
      receiverId: widget.userId,
      productId: widget.productId,
      content: content,
      sender: account.profile,
    );
    setState(() {
      _pending.add(draft);
      _inflight.add(draft.id);
      _composer.clear();
    });
    _scrollToLatest(animate: true);
    try {
      await api.sendMessage(
        widget.userId,
        content,
        productId: widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _inflight.remove(draft.id);
      });
      // The socket echo normally settles the draft; this covers a dropped socket.
      unawaited(_load());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((item) => item.id == draft.id);
        _inflight.remove(draft.id);
        if (_composer.text.isEmpty) _composer.text = content;
      });
      showError(context, error);
    }
  }

  void _scrollToLatest({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) {
      final contact = _contact;
      return Scaffold(
        appBar: MarketplaceAppBar(
          title: 'chat.conversationTitle'.tr(),
          titleContent: contact == null
              ? null
              : _ChatPeerTitle(profile: contact),
          showNotifications: false,
          showProfileAvatar: false,
        ).build(context),
        body: Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(child: _buildConversation(context)),
        ),
      );
    },
  );

  Widget _buildConversation(BuildContext context) {
    final account = _account;
    final error = _error;
    if (account == null) {
      if (error == null || _loading) return const SizedBox.shrink();
      return _ErrorRetry(error: error, onRetry: _load);
    }
    final messages = [..._messages, ..._pending];
    final product = _product;
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
              ? EmptyState(
                  title: 'chat.greetingTitle'.tr(),
                  message: 'chat.greetingMessage'.tr(),
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
                    return _MessageBubble(
                      message: message,
                      account: account,
                      contact: _contact,
                      inflight: _inflight.contains(message.id),
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
                  child: MKTextFormField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'chat.composerHint'.tr(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  tooltip: 'chat.sendTooltip'.tr(),
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
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ChatThread {
  const _ChatThread({
    required this.userId,
    required this.message,
    this.contact,
  });

  final int userId;
  final MarketplaceMessage message;
  final UserProfile? contact;
}

class _ChatPeerTitle extends StatelessWidget {
  const _ChatPeerTitle({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      UserAvatar(profile: profile, size: 32),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.account,
    required this.contact,
    this.inflight = false,
  });

  final MarketplaceMessage message;
  final Account account;
  final UserProfile? contact;
  final bool inflight;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == account.profile.id;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            UserAvatar(profile: contact, radius: 14),
            const SizedBox(width: 7),
          ],
          if (inflight) ...[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: StyleColor.ink,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .68,
            ),
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? StyleColor.ink : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(17),
                topRight: const Radius.circular(17),
                bottomLeft: Radius.circular(mine ? 17 : 4),
                bottomRight: Radius.circular(mine ? 4 : 17),
              ),
            ),
            child: Text(
              message.content,
              style: TextStyle(color: mine ? Colors.white : StyleColor.ink),
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 7),
            UserAvatar(profile: account.profile, radius: 14),
          ],
        ],
      ),
    );
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
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    ),
  );
}
