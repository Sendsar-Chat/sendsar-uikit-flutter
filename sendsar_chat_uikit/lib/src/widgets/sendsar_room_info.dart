import 'package:flutter/material.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../theme/sendsar_chat_theme.dart';
import '../utils/room_label.dart';
import '../utils/user_directory.dart';

class SendsarRoomInfo extends StatelessWidget {
  const SendsarRoomInfo({
    super.key,
    required this.room,
    required this.users,
    required this.selfUserId,
    required this.onlineUserIds,
    required this.title,
    required this.onClose,
  });

  final RoomSummary? room;
  final List<UserDirectoryEntry> users;
  final String selfUserId;
  final Set<String> onlineUserIds;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final room = this.room;
    if (room == null) {
      return const SizedBox.shrink();
    }

    final isGroup = isGroupRoom(room);
    final isDm = isDirectMessage(room);
    final members = _visibleMembers(room, isDm);

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
                  onPressed: onClose,
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
                initialsFor(title.isNotEmpty ? title : 'Chat'),
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
              title,
              style: theme.titleStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              isGroup
                  ? '${members.length} members'
                  : isDm
                      ? 'Direct message'
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
                  Text('Members', style: theme.titleStyle),
                  const SizedBox(height: 8),
                  for (final member in members.take(8))
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
                      title: Text(member.displayName),
                      trailing: onlineUserIds.contains(member.id)
                          ? Icon(Icons.circle, size: 10, color: theme.online)
                          : null,
                    ),
                  if (members.length > 8)
                    Text(
                      '+${members.length - 8} more',
                      style: theme.subtitleStyle,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<UserDirectoryEntry> _visibleMembers(RoomSummary room, bool isDm) {
    if (isDm) {
      final peerId = parseDmPeerId(room.externalId, selfUserId);
      if (peerId == null || peerId.isEmpty) return [];
      final peer = users.where((u) => u.id == peerId).firstOrNull;
      return [peer ?? UserDirectoryEntry(id: peerId, displayName: title)];
    }
    return users.where((u) => u.id != selfUserId).toList();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
