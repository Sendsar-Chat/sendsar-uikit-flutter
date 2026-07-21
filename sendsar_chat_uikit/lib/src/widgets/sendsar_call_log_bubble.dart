import 'package:flutter/material.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../theme/sendsar_chat_theme.dart';

/// Call history bubble for `data-call` message parts. The whole pill is the
/// redial affordance — tap to call again with the same type.
class SendsarCallLogBubble extends StatelessWidget {
  const SendsarCallLogBubble({
    super.key,
    required this.data,
    required this.selfUserId,
    this.onRedial,
  });

  final CallLogData data;
  final String selfUserId;
  final void Function(CallType type)? onRedial;

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final missed = isMissedCallLog(data, selfUserId);
    final label = formatCallLogPreview(data, selfUserId);
    final icon = missed
        ? Icons.phone_missed
        : data.callType == 'video'
            ? Icons.videocam
            : Icons.call;
    final color = missed ? theme.error : theme.accent;
    final background =
        missed ? theme.error.withValues(alpha: 0.08) : theme.accentSoft;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onRedial == null ? null : () => onRedial!(data.callType),
        child: Tooltip(
          message: 'Call again',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: missed ? theme.error : theme.textPrimary,
                    ),
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
