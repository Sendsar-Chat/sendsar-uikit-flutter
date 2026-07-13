import 'dart:async';

import 'package:sendsar_chat/sendsar_chat.dart';

/// Debounced outgoing typing indicator while the user composes a message.
class ComposerTypingController {
  ComposerTypingController(
    this._client,
    this._roomId, {
    this.stopMs = typingStopMs,
  });

  final SendsarClient _client;
  String? _roomId;
  final int stopMs;

  bool _typingActive = false;
  Timer? _timer;

  void setRoomId(String? roomId) {
    if (_roomId == roomId) return;
    stop();
    _roomId = roomId;
  }

  void onValueChange(String value) {
    final roomId = _roomId;
    if (roomId == null || !_client.isConnected) return;
    final hasText = value.trim().isNotEmpty;

    if (hasText) {
      if (!_typingActive) {
        _typingActive = true;
        _client.setTyping(TypingParams(roomId: roomId, isTyping: true));
      }
      _timer?.cancel();
      _timer = Timer(Duration(milliseconds: stopMs), stop);
    } else {
      stop();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    final roomId = _roomId;
    if (_typingActive && roomId != null && _client.isConnected) {
      _client.setTyping(TypingParams(roomId: roomId, isTyping: false));
      _typingActive = false;
    }
  }

  void dispose() => stop();
}
