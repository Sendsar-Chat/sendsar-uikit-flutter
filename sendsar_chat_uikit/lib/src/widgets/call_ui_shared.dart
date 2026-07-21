import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sendsar_call/sendsar_call.dart';

import '../services/sendsar_call_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../utils/user_directory.dart';

/// Shared building blocks for the call overlay (wide layouts) and the
/// full-screen call page (mobile). Not exported from the package barrel.

String callStatusLabel(SendsarCallService calls) {
  if (calls.mediaStatus == 'reconnecting') return 'Reconnecting…';
  final duration = calls.durationLabel;
  if (duration.isNotEmpty) return duration;
  switch (calls.callState) {
    case callStateOutgoing:
      return 'Calling…';
    case callStateIncoming:
      return 'Incoming call';
    case callStateConnecting:
      return 'Connecting…';
    case callStateActive:
      return 'Connected';
    default:
      return '';
  }
}

/// Whether the current/incoming call is audio-only (no camera control).
bool callIsAudioOnly(SendsarCallService calls) {
  final activeType = calls.activeCall?.type;
  final inviteType = calls.incomingInvite?.type;
  return (activeType ?? inviteType) == 'audio';
}

Future<void> safeCallHangUp(SendsarCallService calls) async {
  try {
    final reason = calls.callState == callStateOutgoing ? 'cancelled' : null;
    await calls.hangUp(reason: reason);
  } catch (_) {
    // Error surfaced via calls.error.
  }
}

Future<void> runCallAction(Future<Object?> Function() action) async {
  try {
    await action();
  } catch (_) {
    // Error surfaced via calls.error.
  }
}

class CallRoundButton extends StatelessWidget {
  const CallRoundButton({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.tooltip,
    required this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.46, color: foreground),
          ),
        ),
      ),
    );
  }
}

class CallAvatar extends StatelessWidget {
  const CallAvatar({
    super.key,
    required this.title,
    required this.radius,
    this.avatarUrl,
  });

  final String title;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.accentSoft,
      child: Text(
        initialsFor(title),
        style: TextStyle(
          color: theme.accent,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.66,
        ),
      ),
    );
  }
}

/// Call controls: accept/decline while ringing, otherwise
/// mic / speaker / camera (video calls) / hang-up.
class CallControlsRow extends StatelessWidget {
  const CallControlsRow({
    super.key,
    required this.calls,
    this.buttonSize = 48,
    this.spacing = 16,
  });

  final SendsarCallService calls;
  final double buttonSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final isIncoming = calls.callState == callStateIncoming && !calls.calling;
    final isAudioOnly = callIsAudioOnly(calls);

    if (isIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CallRoundButton(
            icon: Icons.call_end,
            background: theme.error,
            foreground: Colors.white,
            tooltip: 'Decline',
            size: buttonSize,
            onPressed: () => unawaited(runCallAction(() => calls.decline())),
          ),
          SizedBox(width: spacing * 2),
          CallRoundButton(
            icon: Icons.call,
            background: theme.online,
            foreground: Colors.white,
            tooltip: 'Accept',
            size: buttonSize,
            onPressed: () => unawaited(runCallAction(() => calls.accept())),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CallRoundButton(
          icon: calls.micEnabled ? Icons.mic : Icons.mic_off,
          background: theme.accentSoft,
          foreground: calls.micEnabled ? theme.accent : theme.error,
          tooltip: calls.micEnabled ? 'Mute' : 'Unmute',
          size: buttonSize,
          onPressed: () => unawaited(runCallAction(calls.toggleMicrophone)),
        ),
        SizedBox(width: spacing),
        CallRoundButton(
          icon: calls.speakerEnabled ? Icons.volume_up : Icons.volume_down,
          background: theme.accentSoft,
          foreground: calls.speakerEnabled ? theme.accent : theme.textMuted,
          tooltip: calls.speakerEnabled ? 'Speaker on' : 'Speaker off',
          size: buttonSize,
          onPressed: () => unawaited(runCallAction(calls.toggleSpeaker)),
        ),
        if (!isAudioOnly) ...[
          SizedBox(width: spacing),
          CallRoundButton(
            icon: calls.cameraEnabled ? Icons.videocam : Icons.videocam_off,
            background: theme.accentSoft,
            foreground: calls.cameraEnabled ? theme.accent : theme.error,
            tooltip: calls.cameraEnabled ? 'Camera off' : 'Camera on',
            size: buttonSize,
            onPressed: () => unawaited(runCallAction(calls.toggleCamera)),
          ),
        ],
        SizedBox(width: spacing),
        CallRoundButton(
          icon: Icons.call_end,
          background: theme.error,
          foreground: Colors.white,
          tooltip: 'Hang up',
          size: buttonSize,
          onPressed: () => unawaited(safeCallHangUp(calls)),
        ),
      ],
    );
  }
}
