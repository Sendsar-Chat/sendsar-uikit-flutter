import 'package:flutter/material.dart';
import 'package:sendsar_call/sendsar_call.dart';

import '../services/sendsar_call_service.dart';
import '../theme/sendsar_chat_theme.dart';

/// Telegram-style ongoing-call bar shown at the top of the shell while a
/// call is minimized on mobile. Tapping it returns to the call screen.
class SendsarOngoingCallBar extends StatelessWidget {
  const SendsarOngoingCallBar({
    super.key,
    required this.calls,
    this.onTap,
  });

  final SendsarCallService calls;

  /// Defaults to restoring the call screen (`setMinimized(false)`).
  final VoidCallback? onTap;

  String _label() {
    final duration = calls.durationLabel;
    if (calls.mediaStatus == 'reconnecting') {
      return 'Reconnecting…';
    }
    if (duration.isNotEmpty) {
      return 'Ongoing call · $duration';
    }
    if (calls.callState == callStateOutgoing) {
      return 'Calling…';
    }
    if (calls.callState == callStateConnecting) {
      return 'Connecting…';
    }
    return 'Ongoing call';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    return Material(
      color: theme.online,
      child: InkWell(
        onTap: onTap ?? () => calls.setMinimized(false),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_in_talk, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _label(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
