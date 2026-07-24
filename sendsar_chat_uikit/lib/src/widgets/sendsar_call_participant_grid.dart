import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../services/sendsar_call_service.dart';
import 'call_ui_shared.dart';

/// Google Meet-style equal tiles for group calls (includes local self-view).
class SendsarCallParticipantGrid extends StatelessWidget {
  const SendsarCallParticipantGrid({
    super.key,
    required this.calls,
    required this.roomTitle,
    this.labelForIdentity,
    this.padding = EdgeInsets.zero,
  });

  final SendsarCallService calls;
  final String roomTitle;
  final String Function(String identity)? labelForIdentity;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tiles = <_GridTileData>[
      _GridTileData(
        key: 'local',
        track: calls.localVideoTrack,
        label: 'You',
      ),
    ];
    calls.remoteVideoTracks.forEach((sid, track) {
      final identity = calls.remoteIdentities[sid];
      final label = identity == null
          ? roomTitle
          : (labelForIdentity?.call(identity) ?? identity);
      tiles.add(_GridTileData(key: sid, track: track, label: label));
    });

    final count = tiles.length;
    final crossAxisCount = count <= 1
        ? 1
        : count <= 4
            ? 2
            : 3;

    return Padding(
      padding: padding,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1,
        ),
        itemCount: count,
        itemBuilder: (context, index) => _ParticipantTile(data: tiles[index]),
      ),
    );
  }
}

class _GridTileData {
  const _GridTileData({
    required this.key,
    required this.track,
    required this.label,
  });

  final String key;
  final lk.VideoTrack? track;
  final String label;
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.data});

  final _GridTileData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: const Color(0xFF1E293B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (data.track != null)
              lk.VideoTrackRenderer(data.track!)
            else
              Center(child: CallAvatar(title: data.label, radius: 28)),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
