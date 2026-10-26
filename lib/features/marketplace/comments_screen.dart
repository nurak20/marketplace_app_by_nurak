import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/adaptive_safe_body.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/error_retry_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/show_error.dart';
import '../../core/models.dart';

class ProductCommentsScreen extends StatefulWidget {
  const ProductCommentsScreen({
    super.key,
    required this.postId,
    required this.productId,
  });

  final int postId;
  final int productId;

  @override
  State<ProductCommentsScreen> createState() => _ProductCommentsScreenState();
}

class _ProductCommentsScreenState extends State<ProductCommentsScreen> {
  final _composer = TextEditingController();
  late Future<ApiPage<PostComment>> _comments;
  PostComment? _replyTo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _comments = api.productPostComments(widget.postId, widget.productId);
  }

  Future<void> _sendComment() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await api.addProductPostComment(
        widget.postId,
        widget.productId,
        content,
        parentId: _replyTo?.id,
      );
      if (!mounted) return;
      _composer.clear();
      setState(() {
        _replyTo = null;
        _load();
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _avatar(PostComment comment) {
    final avatar = comment.avatar;
    final hasAvatar = avatar?.url.isNotEmpty == true;
    return CircleAvatar(
      radius: 20,
      backgroundColor: StyleColor.canvas,
      backgroundImage: hasAvatar
          ? NetworkImage(api.resolveUrl(avatar!.url))
          : null,
      onBackgroundImageError: hasAvatar ? (_, _) {} : null,
      child: hasAvatar
          ? null
          : const Icon(Icons.person_outline_rounded, color: StyleColor.ink),
    );
  }

  Widget _commentTile(PostComment comment) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(comment),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _replyTo = comment),
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Reply'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (comment.replies.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 16, top: 7),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: StyleColor.muted.withValues(alpha: .25),
                ),
              ),
            ),
            child: Column(children: comment.replies.map(_commentTile).toList()),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: const MarketplaceAppBar(
      title: 'Comments',
      showNotifications: false,
      showProfileAvatar: false,
    ).build(context),
    body: AdaptiveSafeBody(
      child: FutureBuilder<ApiPage<PostComment>>(
        future: _comments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return ErrorRetryPanel(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }
          final comments = snapshot.data?.items ?? const <PostComment>[];
          return Column(
            children: [
              Expanded(
                child: comments.isEmpty
                    ? const EmptyState(
                        title: 'No comments yet',
                        message: 'Start the conversation about this listing.',
                        icon: Icons.mode_comment_outlined,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          14,
                          14,
                          StyleSpacing.bottomContentClearance,
                        ),
                        children: comments.map(_commentTile).toList(),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Column(
                    children: [
                      if (_replyTo != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${_replyTo!.displayName}',
                                style: const TextStyle(color: StyleColor.muted),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _replyTo = null),
                              tooltip: 'Cancel reply',
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _composer,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendComment(),
                              decoration: InputDecoration(
                                hintText: _replyTo == null
                                    ? 'Add a comment'
                                    : 'Reply to ${_replyTo!.displayName}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sending ? null : _sendComment,
                            tooltip: 'Post comment',
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }
}
