import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import 'package:sendsar_call/sendsar_call.dart';

import '../services/sendsar_call_service.dart';
import '../theme/sendsar_chat_theme.dart';
import 'call_ui_shared.dart';

/// Floating call card for wide/desktop layouts — incoming/outgoing ring,
/// active call, and a minimized chip. Mount it in a [Stack] above the chat
/// shell whenever [SendsarCallService.showCallUi] is true.
///
/// On mobile (narrow layouts) the shell pushes [SendsarCallScreen] as a
/// full-screen route instead.
class SendsarCallOverlay extends StatelessWidget {
  const SendsarCallOverlay({
    super.key,
    required this.title,
    this.avatarUrl,
  });

  /// Peer or room label shown in the header/chip.
  final String title;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final calls = context.watch<SendsarCallService>();
    if (!calls.showCallUi) return const SizedBox.shrink();

    if (calls.minimized) {
      return Positioned(
        top: 12,
        right: 12,
        child: _MinimizedChip(calls: calls, title: title, avatarUrl: avatarUrl),
      );
    }

    return Positioned(
      top: 16,
      right: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: _CallCard(calls: calls, title: title, avatarUrl: avatarUrl),
      ),
    );
  }
}

class _MinimizedChip extends StatelessWidget {
  const _MinimizedChip({
    required this.calls,
    required this.title,
    this.avatarUrl,
  });

  final SendsarCallService calls;
  final String title;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    return Material(
      color: theme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => calls.setMinimized(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CallAvatar(title: title, avatarUrl: avatarUrl, radius: 14),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      callStatusLabel(calls),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => unawaited(safeCallHangUp(calls)),
                icon: Icon(Icons.call_end, size: 18, color: theme.error),
                tooltip: 'Hang up',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({
    required this.calls,
    required this.title,
    this.avatarUrl,
  });

  final SendsarCallService calls;
  final String title;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    final error = calls.error;
    final canMinimize = calls.callState == callStateOutgoing ||
        calls.callState == callStateConnecting ||
        calls.callState == callStateActive;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleStyle,
                      ),
                      Text(
                        callStatusLabel(calls),
                        style:
                            TextStyle(fontSize: 13, color: theme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (canMinimize)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => calls.setMinimized(true),
                    icon: Icon(
                      Icons.close_fullscreen,
                      size: 20,
                      color: theme.textSecondary,
                    ),
                    tooltip: 'Minimize',
                  ),
              ],
            ),
          ),
          Flexible(
            child: _Stage(
              calls: calls,
              title: title,
              avatarUrl: avatarUrl,
              theme: theme,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CallControlsRow(calls: calls),
                if (error != null && error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: theme.error),
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

class _Stage extends StatelessWidget {
  const _Stage({
    required this.calls,
    required this.title,
    required this.theme,
    this.avatarUrl,
  });

  final SendsarCallService calls;
  final String title;
  final String? avatarUrl;
  final SendsarChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final remote = calls.remoteVideoTrack;
    final local = calls.localVideoTrack;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: theme.sidebarBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (remote != null)
              lk.VideoTrackRenderer(remote)
            else
              Center(
                child:
                    CallAvatar(title: title, avatarUrl: avatarUrl, radius: 40),
              ),
            if (local != null)
              Positioned(
                right: 10,
                bottom: 10,
                width: 96,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: lk.VideoTrackRenderer(local),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
