import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../services/sendsar_chat_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../theme/sendsar_styles.dart';
import '../utils/format_time.dart';
import '../utils/room_label.dart';
import '../utils/user_directory.dart';

/// Imperative handle for [SendsarConversationList].
class SendsarConversationListController {
  Future<void> Function()? _reload;
  Future<RoomSummary?> Function(String roomId)? _selectById;

  void attach({
    required Future<void> Function() reload,
    required Future<RoomSummary?> Function(String roomId) selectById,
  }) {
    _reload = reload;
    _selectById = selectById;
  }

  void detach() {
    _reload = null;
    _selectById = null;
  }

  Future<void> reload() async => _reload?.call();

  Future<RoomSummary?> selectRoomById(String roomId) async =>
      _selectById?.call(roomId) ?? null;
}

class SendsarConversationList extends StatefulWidget {
  const SendsarConversationList({
    super.key,
    required this.selectedRoomId,
    required this.users,
    required this.selfUserId,
    required this.typingByRoom,
    required this.onlineUserIds,
    required this.onRoomSelect,
    this.controller,
    this.style,
    this.itemBuilder,
  });

  final String? selectedRoomId;
  final List<UserDirectoryEntry> users;
  final String selfUserId;
  final TypingByRoom typingByRoom;
  final Set<String> onlineUserIds;
  final ValueChanged<RoomSummary> onRoomSelect;
  final SendsarConversationListController? controller;
  final SendsarConversationListStyle? style;
  final SendsarConversationItemBuilder? itemBuilder;

  @override
  State<SendsarConversationList> createState() =>
      _SendsarConversationListState();
}

class _SendsarConversationListState extends State<SendsarConversationList> {
  List<RoomSummary> _rooms = [];
  bool _initialLoad = true;
  bool _refreshing = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(reload: reload, selectById: selectRoomById);
    WidgetsBinding.instance.addPostFrameCallback((_) => _waitAndLoad());
  }

  @override
  void didUpdateWidget(covariant SendsarConversationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(reload: reload, selectById: selectRoomById);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  Future<void> _waitAndLoad() async {
    final session = context.read<SendsarSessionService>();
    while (mounted && !session.isReady) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) await reload();
  }

  Future<void> reload() async {
    final session = context.read<SendsarSessionService>();
    if (!session.isReady) return;

    final hasRooms = _rooms.isNotEmpty;
    setState(() {
      if (hasRooms) {
        _refreshing = true;
      } else {
        _initialLoad = true;
      }
      _error = null;
    });

    try {
      final chat = context.read<SendsarChatService>();
      final result = await chat.listRooms(const ListRoomsParams(limit: 50));
      if (!mounted) return;
      setState(() {
        _rooms = sortRoomsByLatestActivity(result.rooms);
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to load rooms';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _initialLoad = false;
        _refreshing = false;
      });
    }
  }

  Future<RoomSummary?> selectRoomById(String roomId) async {
    await reload();
    final room = _rooms.where((r) => r.id == roomId).firstOrNull;
    if (room != null) {
      widget.onRoomSelect(room);
    }
    return room;
  }

  List<RoomSummary> get _filteredRooms {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _rooms;
    return _rooms
        .where((room) => _roomLabel(room).toLowerCase().contains(query))
        .toList();
  }

  String _roomLabel(RoomSummary room) {
    final selfId = widget.selfUserId.isNotEmpty
        ? widget.selfUserId
        : context.read<SendsarSessionService>().session?.chatUserId ?? '';
    return resolveRoomLabel(room, selfId, widget.users);
  }

  String _roomSubtitle(RoomSummary room) {
    final selfId = widget.selfUserId.isNotEmpty
        ? widget.selfUserId
        : context.read<SendsarSessionService>().session?.chatUserId ?? '';
    final typingIds = otherTypingUserIds(
      widget.typingByRoom,
      room.id,
      selfId,
    );
    final map = userDirectoryMap(widget.users);
    final displayNames = {
      for (final e in map.entries) e.key: e.value.displayName,
    };
    final typingLabel = formatTypingLabel(
      typingIds,
      displayNames,
      directMessage: isDirectMessage(room),
    );
    return inboxSubtitleForPeer(
          typingLabel: typingLabel.isEmpty ? null : typingLabel,
          lastMessagePreview: room.lastMessage?.previewText,
        ) ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final style = widget.style ?? const SendsarConversationListStyle();
    return ColoredBox(
      color: theme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    style.headerTitle ?? 'Messages',
                    style: theme.titleStyle,
                  ),
                ),
                if (_refreshing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: style.searchHint ?? 'Search conversations',
                isDense: true,
                filled: true,
                fillColor: theme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: theme.error)),
            ),
          Expanded(
            child: _initialLoad && _rooms.isEmpty
                ? ListView.builder(
                    itemCount: 5,
                    itemBuilder: (_, __) => const _SkeletonRow(),
                  )
                : _filteredRooms.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations yet',
                          style: theme.subtitleStyle,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredRooms.length,
                        itemBuilder: (context, index) {
                          final room = _filteredRooms[index];
                          final selected = room.id == widget.selectedRoomId;
                          final label = _roomLabel(room);
                          final peerOnline = _isPeerOnline(room);
                          final unread = room.unreadCount ?? 0;
                          final defaultTile = Material(
                            color: selected
                                ? (style.selectedColor ?? theme.accentSoft)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onRoomSelect(room),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    _AvatarBadge(
                                      initials: initialsFor(label),
                                      online: peerOnline,
                                      theme: theme,
                                      radius: style.avatarRadius ?? 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  label,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (unread > 0) ...[
                                                _UnreadBadge(
                                                  count: unread,
                                                  theme: theme,
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Text(
                                                formatRelativeTime(
                                                  room.lastMessage?.createdAt ??
                                                      room.createdAt,
                                                ),
                                                style: theme.subtitleStyle,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _roomSubtitle(room),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.subtitleStyle,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (widget.itemBuilder != null) {
                            return widget.itemBuilder!(
                              context,
                              room,
                              defaultTile,
                            );
                          }
                          return defaultTile;
                        },
                      ),
          ),
        ],
      ),
    );
  }

  bool _isPeerOnline(RoomSummary room) {
    if (!isDirectMessage(room)) return false;
    final selfId = widget.selfUserId.isNotEmpty
        ? widget.selfUserId
        : context.read<SendsarSessionService>().session?.chatUserId ?? '';
    final peerId = parseDmPeerId(room.externalId, selfId);
    return peerId != null && widget.onlineUserIds.contains(peerId);
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.initials,
    required this.online,
    required this.theme,
    required this.radius,
  });

  final String initials;
  final bool online;
  final SendsarChatTheme theme;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: theme.accentSoft,
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.accent,
              fontSize: radius * 0.6,
            ),
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 6,
              backgroundColor: theme.online,
            ),
          ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.theme});

  final int count;
  final SendsarChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.unreadBadge,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: theme.unreadBadgeText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: theme.skeleton),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 12,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.skeleton,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 10,
                  width: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.skeletonMuted,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
