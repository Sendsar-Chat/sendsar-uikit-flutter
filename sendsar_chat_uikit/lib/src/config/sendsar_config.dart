import 'package:sendsar_chat/sendsar_chat.dart';

/// Configuration for [SendsarScope].
class SendsarConfig {
  const SendsarConfig({
    required this.fetchSession,
    this.refreshBeforeExpiryMs,
    this.animatedEmoji = true,
  });

  /// Fetch session JWT from your backend (never use `sk_*` in the client).
  final Future<SessionResponse> Function() fetchSession;

  final int? refreshBeforeExpiryMs;

  /// Noto animated emoji in message bubbles (default: true).
  final bool animatedEmoji;
}
