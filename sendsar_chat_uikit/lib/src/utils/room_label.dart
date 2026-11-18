import 'package:sendsar_chat/sendsar_chat.dart';

import 'user_directory.dart';

/// Peer user id from a canonical `dm:userA:userB` external id.
String? parseDmPeerId(String? externalId, String selfUserId) {
  if (externalId == null || !externalId.startsWith('dm:')) return null;
  final ids = externalId.substring(3).split(':');
  if (ids.length != 2) return null;
  return ids.firstWhere((id) => id != selfUserId, orElse: () => '');
}

bool isDirectMessage(RoomSummary room) {
  return room.customType == 'demo_dm' ||
      (room.externalId?.startsWith('dm:') ?? false);
}

bool isGroupRoom(RoomSummary room) {
  if (isDirectMessage(room)) return false;
  return room.customType == 'demo_group' || (room.name?.trim().isNotEmpty ?? false);
}

/// Human-readable title — never shows raw `dm:…` external ids.
String resolveRoomLabel(
  RoomSummary room,
  String selfUserId,
  List<UserDirectoryEntry> users,
) {
  final map = userDirectoryMap(users);

  // Direct messages: always show the *other* participant. The stored
  // `room.name` is whatever the creator typed (the receiver's name), so using
  // it would show the same title to both sides.
  if (isDirectMessage(room)) {
    final peerId = parseDmPeerId(room.externalId, selfUserId);
    if (peerId != null && peerId.isNotEmpty) {
      return displayNameFor(peerId, map);
    }
  }

  final name = room.name?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }

  if (room.customType == 'demo_group') {
    return 'Group chat';
  }

  return 'Conversation';
}
