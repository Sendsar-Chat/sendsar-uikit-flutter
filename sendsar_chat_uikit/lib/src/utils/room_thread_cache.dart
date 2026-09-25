import 'package:sendsar_chat/sendsar_chat.dart';

/// Cached thread snapshot for instant conversation switches.
class CachedRoomThread {
  const CachedRoomThread({
    required this.messages,
    this.nextCursor,
    this.peerLastReadAt,
    this.peerLastReadMessageId,
  });

  final List<Message> messages;
  final String? nextCursor;
  final String? peerLastReadAt;
  final String? peerLastReadMessageId;
}

final Map<String, CachedRoomThread> _roomThreadCache = {};

CachedRoomThread? getCachedRoomThread(String roomId) {
  final cached = _roomThreadCache[roomId];
  if (cached == null) return null;
  return CachedRoomThread(
    messages: List<Message>.from(cached.messages),
    nextCursor: cached.nextCursor,
    peerLastReadAt: cached.peerLastReadAt,
    peerLastReadMessageId: cached.peerLastReadMessageId,
  );
}

void setCachedRoomThread(String roomId, CachedRoomThread cache) {
  _roomThreadCache[roomId] = CachedRoomThread(
    messages: List<Message>.from(cache.messages),
    nextCursor: cache.nextCursor,
    peerLastReadAt: cache.peerLastReadAt,
    peerLastReadMessageId: cache.peerLastReadMessageId,
  );
}
