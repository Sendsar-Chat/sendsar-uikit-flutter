import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:provider/provider.dart';
import 'package:sendsar_call/sendsar_call.dart';

import '../services/sendsar_call_service.dart';
import 'call_ui_shared.dart';

/// Full-screen call page for mobile — Telegram-style: remote video (or a
/// large avatar) fills the screen, controls at the bottom, and a minimize
/// chevron that sends the call to the background bar.
///
/// Push it as a route (the shell does this automatically on narrow layouts)
/// with a [SendsarCallService] available via provider or [calls].
class SendsarCallScreen extends StatelessWidget {
  const SendsarCallScreen({
    super.key,
    required this.title,
    this.avatarUrl,
    this.calls,
  });

  final String title;
  final String? avatarUrl;

  /// Explicit service instance; falls back to `context.watch`.
  final SendsarCallService? calls;

  @override
  Widget build(BuildContext context) {
    final explicit = calls;
    if (explicit != null) {
      return ListenableBuilder(
        listenable: explicit,
        builder: (context, _) => _CallScreenBody(
          calls: explicit,
          title: title,
          avatarUrl: avatarUrl,
        ),
      );
    }
    return _CallScreenBody(
      calls: context.watch<SendsarCallService>(),
      title: title,
      avatarUrl: avatarUrl,
    );
  }
}

class _CallScreenBody extends StatelessWidget {
  const _CallScreenBody({
    required this.calls,
    required this.title,
    this.avatarUrl,
  });

  final SendsarCallService calls;
  final String title;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final isIncoming = calls.callState == callStateIncoming && !calls.calling;
    final canMinimize = !isIncoming && calls.showCallUi;
    final remote = calls.remoteVideoTrack;
    final local = calls.localVideoTrack;
    final error = calls.error;

    return PopScope(
      // Back never leaves the call: it minimizes (refused while incoming).
      canPop: canMinimize,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) calls.setMinimized(true);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (remote != null)
              lk.VideoTrackRenderer(remote)
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E293B), Color(0xFF0B1220)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CallAvatar(
                          title: title, avatarUrl: avatarUrl, radius: 56),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        callStatusLabel(calls),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        if (canMinimize)
                          IconButton(
                            onPressed: () => calls.setMinimized(true),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 30,
                            ),
                            tooltip: 'Minimize',
                          )
                        else
                          const SizedBox(width: 48),
                        // Compact header shown when video covers the stage.
                        if (remote != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 8, color: Colors.black54),
                                    ],
                                  ),
                                ),
                                Text(
                                  callStatusLabel(calls),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 8, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (error != null && error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32, top: 8),
                    child: CallControlsRow(
                      calls: calls,
                      buttonSize: 60,
                      spacing: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (local != null)
              Positioned(
                right: 16,
                bottom: 128,
                width: 108,
                height: 148,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: lk.VideoTrackRenderer(local),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
