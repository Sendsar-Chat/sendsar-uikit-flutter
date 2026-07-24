import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../services/sendsar_chat_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../utils/room_label.dart';
import '../utils/user_directory.dart';

class SendsarRoomInfo extends StatefulWidget {
  const SendsarRoomInfo({
    super.key,
    required this.room,
    required this.users,
    required this.selfUserId,
    required this.onlineUserIds,
    required this.title,
    required this.onClose,
    this.onConversationDeleted,
    this.onHistoryCleared,
  });

  final RoomSummary? room;
  final List<UserDirectoryEntry> users;
  final String selfUserId;
  final Set<String> onlineUserIds;
  final String title;
  final VoidCallback onClose;
  final ValueChanged<String>? onConversationDeleted;
  final ValueChanged<String>? onHistoryCleared;

  @override
  State<SendsarRoomInfo> createState() => _SendsarRoomInfoState();
}

class _SendsarRoomInfoState extends State<SendsarRoomInfo> {
  List<RoomParticipant> _participants = const [];
  bool _loading = false;
  bool _mutating = false;
  bool _showAddPicker = false;
  String? _error;
  VoidCallback? _rosterUnsub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireRoster();
      _reloadMembers();
    });
  }

  @override
  void dispose() {
    _rosterUnsub?.call();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SendsarRoomInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room?.id != widget.room?.id ||
        oldWidget.selfUserId != widget.selfUserId) {
      _wireRoster();
      _reloadMembers();
    }
  }

  void _wireRoster() {
    _rosterUnsub?.call();
    _rosterUnsub = null;
    final client = context.read<SendsarSessionService>().client;
    final roomId = widget.room?.id;
    if (client == null || roomId == null) return;
    _rosterUnsub = client.on(SocketEvent.roomParticipantsChanged, (event) {
      if (event is! RoomParticipantsChangedEvent) return;
      if (event.roomId != roomId || !mounted) return;
      unawaited(_reloadMembers());
    });
  }

  Future<void> _reloadMembers() async {
    final room = widget.room;
    if (room == null || !isGroupRoom(room)) {
      setState(() {
        _participants = const [];
        _loading = false;
        _error = null;
        _showAddPicker = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showAddPicker = false;
    });

    try {
      final detail = await context.read<SendsarChatService>().getRoom(room.id);
      if (!mounted) return;
      setState(() {
        _participants = detail.participants;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _participants = const [];
        _loading = false;
        _error = err.toString();
      });
    }
  }

  bool get _selfIsOperator => _participants.any(
        (p) => p.userId == widget.selfUserId && p.isOperator,
      );

  List<_MemberRow> _memberRows(RoomSummary room, bool isGroup, bool isDm) {
    final map = userDirectoryMap(widget.users);
    if (isDm) {
      final peerId = parseDmPeerId(room.externalId, widget.selfUserId);
      if (peerId == null || peerId.isEmpty) return const [];
      return [
        _MemberRow(
          userId: peerId,
          displayName: displayNameFor(peerId, map),
          isOperator: false,
          isSelf: false,
        ),
      ];
    }
    if (!isGroup) return const [];

    final rows = _participants
        .map(
          (p) => _MemberRow(
            userId: p.userId,
            displayName: displayNameFor(p.userId, map),
            isOperator: p.isOperator,
            isSelf: p.userId == widget.selfUserId,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.isOperator && !b.isOperator) return -1;
        if (b.isOperator && !a.isOperator) return 1;
        return a.displayName.compareTo(b.displayName);
      });
    return rows;
  }

  List<UserDirectoryEntry> get _addableUsers {
    final inRoom = _participants.map((p) => p.userId).toSet();
    return widget.users
        .where((u) => u.id != widget.selfUserId && !inRoom.contains(u.id))
        .toList();
  }

  Future<void> _addMember(UserDirectoryEntry user) async {
    final roomId = widget.room?.id;
    if (roomId == null || _mutating) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final detail = await context.read<SendsarChatService>().addParticipant(
            roomId,
            AddParticipantParams(
              userId: user.id,
              username: user.displayName,
            ),
          );
      if (!mounted) return;
      setState(() {
        _participants = detail.participants;
        _showAddPicker = false;
        _mutating = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _mutating = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _removeMember(String userId) async {
    final roomId = widget.room?.id;
    if (roomId == null || _mutating) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final detail =
          await context.read<SendsarChatService>().removeParticipant(roomId, userId);
      if (!mounted) return;
      setState(() {
        _participants = detail.participants;
        _mutating = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _mutating = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _clearHistory() async {
    final roomId = widget.room?.id;
    if (roomId == null || _mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history'),
        content: const Text(
          'Clear history? Messages will be removed from your view only. Others keep their copy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await context.read<SendsarChatService>().clearHistory(roomId);
      if (!mounted) return;
      setState(() => _mutating = false);
      widget.onHistoryCleared?.call(roomId);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _mutating = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _deleteConversation() async {
    final room = widget.room;
    if (room == null || _mutating) return;
    final isGroup = isGroupRoom(room);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isGroup ? 'Leave group' : 'Delete chat'),
        content: Text(
          isGroup
              ? 'Leave and delete this group chat? You will leave the group.'
              : 'Delete this chat? It disappears from your list. New messages will show it again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isGroup ? 'Leave' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await context.read<SendsarChatService>().deleteConversation(room.id);
      if (!mounted) return;
      setState(() => _mutating = false);
      widget.onConversationDeleted?.call(room.id);
      widget.onClose();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _mutating = false;
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final room = widget.room;
    if (room == null) {
      return const SizedBox.shrink();
    }

    final isGroup = isGroupRoom(room);
    final isDm = isDirectMessage(room);
    final members = _memberRows(room, isGroup, isDm);

    return ColoredBox(
      color: theme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Details', style: theme.titleStyle),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: theme.accentSoft,
              child: Text(
                initialsFor(widget.title.isNotEmpty ? widget.title : 'Chat'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              widget.title,
              style: theme.titleStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              isGroup
                  ? (members.isEmpty
                      ? 'Group'
                      : '${members.length} members, ${members.where((m) => widget.onlineUserIds.contains(m.userId)).length} online')
                  : isDm
                      ? (members.isNotEmpty &&
                              widget.onlineUserIds.contains(members.first.userId)
                          ? 'Online'
                          : '')
                      : 'Conversation',
              style: theme.subtitleStyle,
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (isGroup || isDm) ...[
                  Row(
                    children: [
                      Expanded(child: Text('Members', style: theme.titleStyle)),
                      if (isGroup && _selfIsOperator)
                        TextButton(
                          onPressed: _mutating
                              ? null
                              : () => setState(
                                    () => _showAddPicker = !_showAddPicker,
                                  ),
                          child: Text(_showAddPicker ? 'Cancel' : 'Add'),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: theme.subtitleStyle.copyWith(color: Colors.red),
                    ),
                  ],
                  if (isGroup && _showAddPicker) ...[
                    const SizedBox(height: 8),
                    if (_addableUsers.isEmpty)
                      Text(
                        'No directory users left to add',
                        style: theme.subtitleStyle,
                      )
                    else
                      ..._addableUsers.map(
                        (user) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: theme.accentSoft,
                            child: Text(
                              initialsFor(user.displayName),
                              style: TextStyle(
                                color: theme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(user.displayName),
                          onTap: _mutating ? null : () => _addMember(user),
                        ),
                      ),
                    const Divider(height: 16),
                  ],
                  if (_loading && isGroup)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Loading members…', style: theme.subtitleStyle),
                    )
                  else ...[
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: theme.accentSoft,
                          child: Text(
                            initialsFor(member.displayName),
                            style: TextStyle(
                              color: theme.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          member.isSelf
                              ? '${member.displayName} (you)'
                              : member.displayName,
                        ),
                        subtitle: member.isOperator
                            ? Text(
                                'Owner',
                                style: theme.subtitleStyle.copyWith(
                                  color: theme.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onlineUserIds.contains(member.userId))
                              Icon(Icons.circle, size: 10, color: theme.online),
                            if (isGroup &&
                                _selfIsOperator &&
                                !member.isSelf) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _mutating
                                    ? null
                                    : () => _removeMember(member.userId),
                                child: const Text('Remove'),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 16),
                Text('Chat actions', style: theme.titleStyle),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Clear history'),
                  onTap: _mutating ? null : _clearHistory,
                ),
                if (isGroup || isDm)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isGroup ? 'Leave group' : 'Delete chat',
                      style: TextStyle(color: theme.error),
                    ),
                    onTap: _mutating ? null : _deleteConversation,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow {
  const _MemberRow({
    required this.userId,
    required this.displayName,
    required this.isOperator,
    required this.isSelf,
  });

  final String userId;
  final String displayName;
  final bool isOperator;
  final bool isSelf;
}
