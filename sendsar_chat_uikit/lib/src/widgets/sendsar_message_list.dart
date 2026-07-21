import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../config/sendsar_config.dart';
import '../services/sendsar_chat_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../theme/sendsar_styles.dart';
import '../utils/format_time.dart';
import '../utils/message_parts.dart';
import '../utils/room_thread_cache.dart';
import '../utils/user_directory.dart';
import 'sendsar_call_log_bubble.dart';
import 'sendsar_message_text.dart';

const _quickReactions = ['👍', '❤️', '😂', '🎉'];

class SendsarMessageList extends StatefulWidget {
  const SendsarMessageList({
    super.key,
    required this.roomId,
    required this.users,
    this.isGroup = false,
    this.chatSettings,
    this.onActivity,
    this.style,
    this.bubbleBuilder,
    this.onCallRedial,
  });

  final String roomId;
  final List<UserDirectoryEntry> users;
  final bool isGroup;
  final TenantChatSettings? chatSettings;
  final VoidCallback? onActivity;
  final SendsarMessageListStyle? style;
  final SendsarMessageBubbleBuilder? bubbleBuilder;

  /// Called when a call-log bubble is tapped (redial with the same type).
  final void Function(CallType type)? onCallRedial;

  @override
  State<SendsarMessageList> createState() => _SendsarMessageListState();
}

class _SendsarMessageListState extends State<SendsarMessageList> {
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _loading = false;
  bool _loadingOlder = false;
  String? _nextCursor;
  String? _peerLastReadAt;
  String? _error;
  String? _editingId;
  final _editController = TextEditingController();
  RoomSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _bindRoom();
  }

  @override
  void didUpdateWidget(covariant SendsarMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _bindRoom();
    }
  }

  @override
  void dispose() {
    _subscription?.destroy();
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _bindRoom() {
    _subscription?.destroy();

    final roomId = widget.roomId;
    final cached = roomId.isNotEmpty ? getCachedRoomThread(roomId) : null;

    setState(() {
      if (cached != null) {
        _messages = cached.messages;
        _nextCursor = cached.nextCursor;
        _peerLastReadAt = cached.peerLastReadAt;
        _loading = false;
      } else {
        _messages = <Message>[];
        _nextCursor = null;
        _peerLastReadAt = null;
        _loading = true;
      }
      _error = null;
      _editingId = null;
      _editController.clear();
    });

    final session = context.read<SendsarSessionService>();
    final client = session.client;
    final userId = session.session?.chatUserId;
    if (client == null || userId == null || roomId.isEmpty) return;

    _subscription = createRoomSubscription(
      client,
      RoomSubscriptionOptions(
        roomId: roomId,
        userId: userId,
        onInitialMessages: (msgs, peerLastReadAt, [nextCursor]) {
          if (!mounted || widget.roomId != roomId) return;
          setState(() {
            _messages = _mergeMessages(_messages, msgs);
            _peerLastReadAt = peerLastReadAt;
            _nextCursor ??= nextCursor;
            _loading = false;
          });
          _persistThreadCache();
          if (cached == null) {
            _scrollToBottom(animate: true);
          }
        },
        onMessage: (msg) {
          if (!mounted || widget.roomId != roomId) return;
          setState(() {
            _messages = _mergeMessages(_messages, [msg]);
          });
          _persistThreadCache();
          widget.onActivity?.call();
          _scrollToBottom();
        },
        onMessageUpdated: (msg) {
          if (!mounted || widget.roomId != roomId) return;
          setState(() {
            _messages = _messages
                .map((m) => m.id == msg.id ? msg : m)
                .toList(growable: false);
          });
          _persistThreadCache();
          widget.onActivity?.call();
        },
        onPeerLastReadAt: (lastReadAt) {
          if (!mounted || widget.roomId != roomId) return;
          setState(() => _peerLastReadAt = lastReadAt);
          _persistThreadCache();
        },
      ),
    );

    if (cached != null) {
      _scrollToBottom(animate: false);
    }
  }

  void _persistThreadCache() {
    if (widget.roomId.isEmpty) return;
    setCachedRoomThread(
      widget.roomId,
      CachedRoomThread(
        messages: _messages,
        nextCursor: _nextCursor,
        peerLastReadAt: _peerLastReadAt,
      ),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  bool _isSelf(Message message) {
    final userId = context.read<SendsarSessionService>().session?.chatUserId;
    return userId != null && message.senderId == userId;
  }

  String _preview(Message message) {
    return messagePreview(
      message,
      deletedPlaceholder:
          widget.chatSettings?.deletedMessagePlaceholder ?? 'Message deleted',
      selfUserId: context.read<SendsarSessionService>().session?.chatUserId,
    );
  }

  Future<void> _loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingOlder) return;

    final prevHeight = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() => _loadingOlder = true);
    try {
      final chat = context.read<SendsarChatService>();
      final result = await chat.getMessages(
        widget.roomId,
        ListMessagesParams(cursor: cursor, limit: 50),
      );
      if (!mounted) return;
      final chronological = result.messages.reversed.toList();
      setState(() {
        _messages = _mergeMessages(chronological, _messages);
        _nextCursor = result.nextCursor;
      });
      _persistThreadCache();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final newHeight = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(newHeight - prevHeight);
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to load older';
      });
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _react(Message message, String emoji) async {
    try {
      final chat = context.read<SendsarChatService>();
      await chat.toggleReaction(
        widget.roomId,
        message.id,
        ToggleReactionParams(emoji: emoji),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to react';
      });
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final chat = context.read<SendsarChatService>();
      await chat.deleteMessage(widget.roomId, message.id);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to delete';
      });
    }
  }

  Future<void> _saveEdit(Message message) async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    try {
      final chat = context.read<SendsarChatService>();
      await chat.updateMessage(
        widget.roomId,
        message.id,
        UpdateMessageParams(parts: [MessagePart(type: 'text', text: text)]),
      );
      if (!mounted) return;
      setState(() {
        _editingId = null;
        _editController.clear();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to edit';
      });
    }
  }

  List<Message> _mergeMessages(List<Message> a, List<Message> b) {
    final byId = {for (final m in a) m.id: m};
    for (final m in b) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList();
    merged.sort((x, y) {
      final xt = DateTime.tryParse(x.createdAt)?.millisecondsSinceEpoch ?? 0;
      final yt = DateTime.tryParse(y.createdAt)?.millisecondsSinceEpoch ?? 0;
      return xt.compareTo(yt);
    });
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final userMap = userDirectoryMap(widget.users);
    final theme = context.sendsarTheme;
    final animatedEmoji = context.read<SendsarConfig>().animatedEmoji;

    return ColoredBox(
      color: theme.surface,
      child: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: TextStyle(color: theme.error)),
            ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (_, __) => const _SkeletonBubble(),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_nextCursor != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_nextCursor != null && index == 0) {
                        return Center(
                          child: TextButton(
                            onPressed: _loadingOlder ? null : _loadOlder,
                            child: _loadingOlder
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Load older messages'),
                          ),
                        );
                      }
                      final msgIndex = _nextCursor != null ? index - 1 : index;
                      final message = _messages[msgIndex];
                      final isSelf = _isSelf(message);
                      final callLog = message.deletedAt == null
                          ? parseCallLogPart(message.parts)
                          : null;
                      if (callLog != null) {
                        final selfUserId = context
                                .read<SendsarSessionService>()
                                .session
                                ?.chatUserId ??
                            '';
                        return _CallLogRow(
                          theme: theme,
                          data: callLog,
                          selfUserId: selfUserId,
                          createdAt: message.createdAt,
                          onRedial: widget.onCallRedial,
                        );
                      }
                      final editing = _editingId == message.id;
                      final defaultBubble = _MessageBubble(
                        theme: theme,
                        listStyle: widget.style,
                        animatedEmoji: animatedEmoji,
                        message: message,
                        isSelf: isSelf,
                        isGroup: widget.isGroup,
                        preview: _preview(message),
                        senderName: displayNameFor(message.senderId, userMap),
                        isRead: isMessageReadByPeer(
                          messageCreatedAt: message.createdAt,
                          messageSenderId: message.senderId,
                          messageDeletedAt: message.deletedAt,
                          selfUserId: context
                                  .read<SendsarSessionService>()
                                  .session
                                  ?.chatUserId ??
                              '',
                          peerLastReadAt: _peerLastReadAt,
                        ),
                        editing: editing,
                        editController: _editController,
                        onStartEdit: isSelf && message.deletedAt == null
                            ? () => setState(() {
                                  _editingId = message.id;
                                  _editController.text =
                                      textFromMessageParts(message.parts);
                                })
                            : null,
                        onCancelEdit: () => setState(() {
                          _editingId = null;
                          _editController.clear();
                        }),
                        onSaveEdit: () => _saveEdit(message),
                        onDelete: isSelf && message.deletedAt == null
                            ? () => _deleteMessage(message)
                            : null,
                        onReact: (emoji) => _react(message, emoji),
                      );
                      if (widget.bubbleBuilder != null) {
                        return widget.bubbleBuilder!(
                          context,
                          message,
                          isSelf,
                          defaultBubble,
                        );
                      }
                      return defaultBubble;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CallLogRow extends StatelessWidget {
  const _CallLogRow({
    required this.theme,
    required this.data,
    required this.selfUserId,
    required this.createdAt,
    this.onRedial,
  });

  final SendsarChatTheme theme;
  final CallLogData data;
  final String selfUserId;
  final String createdAt;
  final void Function(CallType type)? onRedial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Center(
            child: SendsarCallLogBubble(
              data: data,
              selfUserId: selfUserId,
              onRedial: onRedial,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              formatMessageTime(createdAt),
              style: TextStyle(fontSize: 11, color: theme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.theme,
    required this.listStyle,
    required this.animatedEmoji,
    required this.message,
    required this.isSelf,
    required this.isGroup,
    required this.preview,
    required this.senderName,
    required this.isRead,
    required this.editing,
    required this.editController,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
    required this.onReact,
  });

  final SendsarChatTheme theme;
  final SendsarMessageListStyle? listStyle;
  final bool animatedEmoji;
  final Message message;
  final bool isSelf;
  final bool isGroup;
  final String preview;
  final String senderName;
  final bool isRead;
  final bool editing;
  final TextEditingController editController;
  final VoidCallback? onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String> onReact;

  void _showMessageActions(BuildContext context) {
    if (editing || message.deletedAt != null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in _quickReactions)
                      IconButton(
                        tooltip: 'React with $emoji',
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          onReact(emoji);
                        },
                        icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (onStartEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onStartEdit!();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: theme.error),
                  title: Text('Delete', style: TextStyle(color: theme.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onDelete!();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final align = isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isSelf
        ? (listStyle?.selfBubbleColor ?? theme.bubbleSelf)
        : (listStyle?.peerBubbleColor ?? theme.bubblePeer);
    final fg = isSelf ? theme.bubbleSelfText : theme.bubblePeerText;
    final radius = listStyle?.bubbleRadius ?? 12.0;

    final reactions = <String, int>{};
    for (final r in message.reactions ?? const []) {
      reactions[r.emoji] = (reactions[r.emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (isGroup && !isSelf)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSelf)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.accentSoft,
                  child: Text(
                    initialsFor(senderName),
                    style: TextStyle(fontSize: 10, color: theme.accent),
                  ),
                ),
              if (!isSelf) const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onLongPress: editing ? null : () => _showMessageActions(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: editing
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: editController,
                                maxLines: 4,
                                style: TextStyle(color: fg),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: onCancelEdit,
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: onSaveEdit,
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (preview.isNotEmpty)
                                SendsarMessageText(
                                  text: preview,
                                  style: TextStyle(color: fg),
                                  animatedEmoji: animatedEmoji,
                                ),
                              ..._attachmentWidgets(message, fg),
                              if (isSelf)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      isRead ? '✓✓' : '✓',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1,
                                        color: isRead
                                            ? theme.bubbleSelfText
                                                .withValues(alpha: 0.85)
                                            : theme.bubbleSelfText
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isSelf ? 0 : 36,
                right: isSelf ? 4 : 0,
              ),
              child: Align(
                alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                child: Wrap(
                  spacing: 4,
                  children: [
                    for (final entry in reactions.entries)
                      Material(
                        color: theme.surface,
                        shape: StadiumBorder(side: BorderSide(color: theme.border)),
                        child: InkWell(
                          onTap: () => onReact(entry.key),
                          customBorder: const StadiumBorder(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              '${entry.key} ${entry.value}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _attachmentWidgets(Message message, Color fg) {
    final imageHeight = listStyle?.imageHeight ?? 160.0;
    final widgets = <Widget>[];
    for (final part in fileParts(message.parts)) {
      final url = part.accessUrl ?? part.url;
      if (isImagePart(part) && url != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: url,
                height: imageHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => SizedBox(
                  height: imageHeight,
                  child: ColoredBox(color: theme.skeletonMuted),
                ),
                errorWidget: (_, __, ___) => SizedBox(
                  height: imageHeight,
                  child: ColoredBox(color: theme.skeleton),
                ),
              ),
            ),
          ),
        );
      } else if (url != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              part.filename ?? 'Attachment',
              style: TextStyle(
                color: fg,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble();

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 180,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.skeletonMuted,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}
