import 'dart:async';

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
  String? _peerLastReadMessageId;
  String? _error;
  String? _editingId;
  final _editController = TextEditingController();
  RoomSubscription? _subscription;
  VoidCallback? _offRoomRead;
  VoidCallback? _offSession;

  @override
  void initState() {
    super.initState();
    _bindRoom();
    _watchSessionReady();
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
    _offSession?.call();
    _offSession = null;
    _teardownSubscription();
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _watchSessionReady() {
    final session = context.read<SendsarSessionService>();
    void onSession() {
      if (!mounted) return;
      if (_subscription == null &&
          session.client != null &&
          session.session?.chatUserId != null &&
          widget.roomId.isNotEmpty) {
        _bindRoom();
      }
    }

    session.addListener(onSession);
    _offSession = () => session.removeListener(onSession);
  }

  void _teardownSubscription() {
    _offRoomRead?.call();
    _offRoomRead = null;
    _subscription?.destroy();
    _subscription = null;
  }

  void _bindRoom() {
    _teardownSubscription();

    final roomId = widget.roomId;
    final cached = roomId.isNotEmpty ? getCachedRoomThread(roomId) : null;

    setState(() {
      if (cached != null) {
        _messages = cached.messages;
        _nextCursor = cached.nextCursor;
        _peerLastReadAt = cached.peerLastReadAt;
        _peerLastReadMessageId = cached.peerLastReadMessageId;
        _loading = false;
      } else {
        _messages = <Message>[];
        _nextCursor = null;
        _peerLastReadAt = null;
        _peerLastReadMessageId = null;
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
            // Keep the newest cursor if a live room-read arrived first.
            _peerLastReadAt =
                _laterReadAt(_peerLastReadAt, peerLastReadAt) ?? peerLastReadAt;
            _nextCursor ??= nextCursor;
            _loading = false;
          });
          _persistThreadCache();
          unawaited(_hydrateMessagesMissingUrls(msgs.map((m) => m.id)));
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
          unawaited(_hydrateMissingFileUrls(msg.id));
          _scrollToBottom();
        },
        onMessageUpdated: (msg) {
          if (!mounted || widget.roomId != roomId) return;
          setState(() {
            _messages = _messages
                .map((m) => m.id == msg.id
                    ? preserveFileAccessUrls(msg, m)
                    : m)
                .toList(growable: false);
          });
          _persistThreadCache();
          widget.onActivity?.call();
          unawaited(_hydrateMissingFileUrls(msg.id));
        },
        onPeerLastReadAt: (lastReadAt) {
          if (!mounted || widget.roomId != roomId) return;
          _applyPeerRead(lastReadAt: lastReadAt);
        },
      ),
    );

    // Prefer lastReadMessageId when present — avoids createdAt precision mismatches.
    _offRoomRead = client.on<RoomReadEvent>(SocketEvent.roomRead, (event) {
      if (!mounted || widget.roomId != roomId) return;
      if (event.roomId != roomId || event.userId == userId) return;
      _applyPeerRead(
        lastReadAt: event.lastReadAt,
        lastReadMessageId: event.lastReadMessageId,
      );
    });

    if (cached != null) {
      _scrollToBottom(animate: false);
    }
  }

  void _applyPeerRead({
    required String lastReadAt,
    String? lastReadMessageId,
  }) {
    final nextReadAt = _laterReadAt(_peerLastReadAt, lastReadAt) ?? lastReadAt;
    final nextMessageId = lastReadMessageId ?? _peerLastReadMessageId;
    if (nextReadAt == _peerLastReadAt &&
        nextMessageId == _peerLastReadMessageId) {
      return;
    }
    setState(() {
      _peerLastReadAt = nextReadAt;
      _peerLastReadMessageId = nextMessageId;
    });
    _persistThreadCache();
  }

  void _persistThreadCache() {
    if (widget.roomId.isEmpty) return;
    setCachedRoomThread(
      widget.roomId,
      CachedRoomThread(
        messages: _messages,
        nextCursor: _nextCursor,
        peerLastReadAt: _peerLastReadAt,
        peerLastReadMessageId: _peerLastReadMessageId,
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

  bool _isMessageRead(Message message) {
    final selfUserId =
        context.read<SendsarSessionService>().session?.chatUserId ?? '';
    if (selfUserId.isEmpty) return false;
    if (message.deletedAt != null) return false;
    if (message.senderId != selfUserId) return false;

    final readMessageId = _peerLastReadMessageId;
    if (readMessageId != null) {
      if (message.id == readMessageId) return true;
      final readIndex =
          _messages.indexWhere((m) => m.id == readMessageId);
      final messageIndex =
          _messages.indexWhere((m) => m.id == message.id);
      if (readIndex >= 0 && messageIndex >= 0) {
        return messageIndex <= readIndex;
      }
    }

    return _isMessageReadByPeerCursor(
      messageCreatedAt: message.createdAt,
      peerLastReadAt: _peerLastReadAt,
    );
  }

  /// Caption / body text only — attachments render separately (Angular parity).
  String _captionText(Message message) {
    if (message.deletedAt != null) {
      return widget.chatSettings?.deletedMessagePlaceholder ??
          'Message deleted';
    }
    return textFromMessageParts(message.parts);
  }

  Future<void> _hydrateMessagesMissingUrls(Iterable<String> messageIds) async {
    for (final id in messageIds) {
      await _hydrateMissingFileUrls(id);
    }
  }

  Future<void> _hydrateMissingFileUrls(String messageId) async {
    final client = context.read<SendsarSessionService>().client;
    if (client == null || !mounted) return;

    Message? current;
    for (final m in _messages) {
      if (m.id == messageId) {
        current = m;
        break;
      }
    }
    if (current == null || !messageNeedsFileHydration(current)) return;

    try {
      final hydratedList = await client.hydrateFileAccessUrls([current]);
      if (!mounted || hydratedList.isEmpty) return;
      final hydrated = mergeHydratedFileParts(current, hydratedList.first);
      if (widget.roomId != current.roomId) return;
      setState(() {
        _messages = _messages
            .map((m) => m.id == hydrated.id ? hydrated : m)
            .toList(growable: false);
      });
      _persistThreadCache();
    } catch (_) {
      // Keep local/preserved URLs; icon + filename still show without a URL.
    }
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
      unawaited(
        _hydrateMessagesMissingUrls(chronological.map((m) => m.id)),
      );
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

  Future<void> _togglePin(Message message) async {
    try {
      final chat = context.read<SendsarChatService>();
      if (message.pinnedAt == null) {
        await chat.pinMessage(widget.roomId, message.id);
      } else {
        await chat.unpinMessage(widget.roomId, message.id);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to pin';
      });
    }
  }

  Future<void> _forwardMessage(Message message) async {
    final chat = context.read<SendsarChatService>();
    final List<RoomSummary> rooms;
    try {
      final result = await chat.listRooms();
      rooms = result.rooms.where((r) => r.id != widget.roomId).toList();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to load rooms';
      });
      return;
    }
    if (!mounted) return;
    if (rooms.isEmpty) {
      setState(() => _error = 'No other rooms to forward to');
      return;
    }

    final targetRoomId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Forward to…',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(room.name ?? room.externalId ?? room.id),
                      onTap: () => Navigator.pop(sheetContext, room.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (targetRoomId == null || !mounted) return;

    try {
      await chat.forwardMessage(widget.roomId, message.id, [targetRoomId]);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to forward';
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
                      final membership = message.deletedAt == null
                          ? parseMembershipPart(message.parts)
                          : null;
                      if (membership != null) {
                        return _MembershipRow(
                          theme: theme,
                          label: formatMembershipPreview(
                            membership,
                            actorName: displayNameFor(
                              membership.actorUserId,
                              userMap,
                            ),
                            targetName: displayNameFor(
                              membership.targetUserId,
                              userMap,
                            ),
                          ),
                          createdAt: message.createdAt,
                        );
                      }
                      final editing = _editingId == message.id;
                      final caption = _captionText(message);
                      final defaultBubble = _MessageBubble(
                        theme: theme,
                        listStyle: widget.style,
                        animatedEmoji: animatedEmoji,
                        message: message,
                        isSelf: isSelf,
                        preview: caption,
                        senderName: displayNameFor(message.senderId, userMap),
                        createdAt: message.createdAt,
                        forwardedFromLabel: message.forwardedFromId == null
                            ? null
                            : message.forwardedFromSenderId != null
                                ? 'Forwarded from ${displayNameFor(message.forwardedFromSenderId!, userMap)}'
                                : 'Forwarded message',
                        isRead: _isMessageRead(message),
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
                        onTogglePin: message.deletedAt == null
                            ? () => _togglePin(message)
                            : null,
                        onForward: message.deletedAt == null
                            ? () => _forwardMessage(message)
                            : null,
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

class _MembershipRow extends StatelessWidget {
  const _MembershipRow({
    required this.theme,
    required this.label,
    required this.createdAt,
  });

  final SendsarChatTheme theme;
  final String label;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: theme.textMuted),
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
    required this.preview,
    required this.senderName,
    required this.createdAt,
    required this.forwardedFromLabel,
    required this.isRead,
    required this.editing,
    required this.editController,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
    required this.onReact,
    required this.onTogglePin,
    required this.onForward,
  });

  final SendsarChatTheme theme;
  final SendsarMessageListStyle? listStyle;
  final bool animatedEmoji;
  final Message message;
  final bool isSelf;
  final String preview;
  final String senderName;
  final String createdAt;
  final String? forwardedFromLabel;
  final bool isRead;
  final bool editing;
  final TextEditingController editController;
  final VoidCallback? onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String> onReact;
  final VoidCallback? onTogglePin;
  final VoidCallback? onForward;

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
              if (onTogglePin != null)
                ListTile(
                  leading: Icon(
                    message.pinnedAt == null
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                  ),
                  title: Text(message.pinnedAt == null ? 'Pin' : 'Unpin'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onTogglePin!();
                  },
                ),
              if (onForward != null)
                ListTile(
                  leading: const Icon(Icons.forward_outlined),
                  title: const Text('Forward'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onForward!();
                  },
                ),
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
    final timeLabel = formatMessageHeaderTime(createdAt);
    final displayName = isSelf ? '$senderName (Me)' : senderName;

    final reactions = <String, int>{};
    for (final r in message.reactions ?? const []) {
      reactions[r.emoji] = (reactions[r.emoji] ?? 0) + 1;
    }

    Widget avatar() => CircleAvatar(
          radius: 14,
          backgroundColor: theme.accentSoft,
          child: Text(
            initialsFor(senderName),
            style: TextStyle(fontSize: 10, color: theme.accent),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment:
                  isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isSelf) ...[
                  avatar(),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    displayName,
                    textAlign: isSelf ? TextAlign.end : TextAlign.start,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textMuted,
                    ),
                  ),
                ],
                if (isSelf) ...[
                  const SizedBox(width: 8),
                  avatar(),
                ],
              ],
            ),
          ),
          Row(
            mainAxisAlignment:
                isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isSelf && message.pinnedAt != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: Icon(Icons.push_pin, size: 14, color: theme.textMuted),
                ),
              Flexible(
                child: Align(
                  alignment:
                      isSelf ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                    ),
                    child: IntrinsicWidth(
                      child: GestureDetector(
                        onLongPress: editing
                            ? null
                            : () => _showMessageActions(context),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          child: editing
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (forwardedFromLabel != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.forward_outlined,
                                              size: 12,
                                              color:
                                                  fg.withValues(alpha: 0.7),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                forwardedFromLabel!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: fg.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Attachments first, then caption — matches Angular.
                                    ..._attachmentWidgets(message, fg),
                                    if (preview.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: fileParts(message.parts)
                                                  .isNotEmpty
                                              ? 6
                                              : 0,
                                        ),
                                        child: SendsarMessageText(
                                          text: preview,
                                          style: TextStyle(
                                            color: fg,
                                            height: 1.35,
                                          ),
                                          animatedEmoji: animatedEmoji,
                                        ),
                                      ),
                                    if (isSelf)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Icon(
                                            isRead
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: 14,
                                            color: isRead
                                                ? theme.bubbleSelfText
                                                    .withValues(alpha: 0.85)
                                                : theme.bubbleSelfText
                                                    .withValues(alpha: 0.55),
                                          ),
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
              if (!isSelf && message.pinnedAt != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Icon(Icons.push_pin, size: 14, color: theme.textMuted),
                ),
            ],
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isSelf ? 0 : 4,
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
    final inverted = isSelf;

    for (final part in fileParts(message.parts)) {
      final url = filePartUrl(part);
      if (isImagePart(part) && url != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: imageHeight,
                  maxWidth: 280,
                ),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => SizedBox(
                    height: imageHeight,
                    width: 180,
                    child: ColoredBox(color: theme.skeletonMuted),
                  ),
                  errorWidget: (_, __, ___) => _FilePreviewChip(
                    name: part.filename ?? 'Image',
                    mediaType: part.mediaType ?? '',
                    theme: theme,
                    inverted: inverted,
                    fg: fg,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _FilePreviewChip(
              name: part.filename ?? 'Attachment',
              mediaType: part.mediaType ?? '',
              theme: theme,
              inverted: inverted,
              fg: fg,
              href: url,
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _FilePreviewChip extends StatelessWidget {
  const _FilePreviewChip({
    required this.name,
    required this.mediaType,
    required this.theme,
    required this.inverted,
    required this.fg,
    this.href,
  });

  final String name;
  final String mediaType;
  final SendsarChatTheme theme;
  final bool inverted;
  final Color fg;
  final String? href;

  @override
  Widget build(BuildContext context) {
    final bg = inverted
        ? Colors.white.withValues(alpha: 0.14)
        : theme.sidebarBg;
    final borderColor = inverted ? Colors.transparent : theme.border;
    final iconBg = inverted
        ? Colors.white.withValues(alpha: 0.18)
        : theme.surface;
    final iconColor = inverted ? fg : theme.accent;
    final nameColor = inverted ? fg : theme.textSecondary;

    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                fileIconForAttachment(name, mediaType),
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: nameColor,
                  decoration:
                      href != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (href == null) return chip;
    return chip; // URL present — bubble already shows filename; open handled by platform later if needed.
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

/// Prefer the chronologically later read cursor (live events vs history fetch).
String? _laterReadAt(String? a, String? b) {
  if (a == null || a.isEmpty) return b;
  if (b == null || b.isEmpty) return a;
  final da = _parseApiTime(a);
  final db = _parseApiTime(b);
  if (da == null) return b;
  if (db == null) return a;
  return da.isAfter(db) ? a : b;
}

/// Read-cursor check resilient to timezone-naive ISO strings and ms truncation.
bool _isMessageReadByPeerCursor({
  required String messageCreatedAt,
  required String? peerLastReadAt,
}) {
  if (peerLastReadAt == null || peerLastReadAt.isEmpty) return false;
  final readAt = _parseApiTime(peerLastReadAt);
  final createdAt = _parseApiTime(messageCreatedAt);
  if (readAt == null || createdAt == null) return false;
  // Second precision: gateway cursors may drop sub-second createdAt digits.
  final readSec = readAt.toUtc().millisecondsSinceEpoch ~/ 1000;
  final createdSec = createdAt.toUtc().millisecondsSinceEpoch ~/ 1000;
  return createdSec <= readSec;
}

DateTime? _parseApiTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final hasTz = trimmed.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(trimmed) ||
      RegExp(r'[+-]\d{4}$').hasMatch(trimmed);
  if (!hasTz) {
    return DateTime.tryParse('${trimmed}Z') ?? DateTime.tryParse(trimmed);
  }
  return DateTime.tryParse(trimmed);
}
