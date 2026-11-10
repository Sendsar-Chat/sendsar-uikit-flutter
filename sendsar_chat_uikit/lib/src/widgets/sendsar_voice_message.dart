import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/sendsar_chat_theme.dart';
import '../utils/format_time.dart';

/// Play button, waveform, and duration for a voice attachment.
class SendsarVoiceMessage extends StatefulWidget {
  const SendsarVoiceMessage({
    super.key,
    this.url,
    this.bytes,
    this.mimeType,
    this.durationSeconds,
    this.onRemove,
    required this.recordedAt,
    required this.theme,
    required this.outgoing,
  });

  final String? url;
  final Uint8List? bytes;
  final String? mimeType;

  /// Length known before the player loads the file, such as a fresh recording.
  final int? durationSeconds;
  final VoidCallback? onRemove;
  final String recordedAt;
  final SendsarChatTheme theme;
  final bool outgoing;

  @override
  State<SendsarVoiceMessage> createState() => _SendsarVoiceMessageState();
}

_SendsarVoiceMessageState? _activeVoice;

class _SendsarVoiceMessageState extends State<SendsarVoiceMessage> {
  final _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late List<double> _bars;

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Offset? _wavePointer;
  DateTime? _waveDownAt;

  @override
  void initState() {
    super.initState();
    _bars = _voiceBars(_barSeed);
    _subscriptions.add(
      _player.onDurationChanged.listen((duration) {
        if (!mounted || duration <= Duration.zero) return;
        setState(() => _duration = duration);
      }),
    );
    _subscriptions.add(
      _player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      }),
    );
    _subscriptions.add(
      _player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _playing = state == PlayerState.playing);
      }),
    );
    _subscriptions.add(
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }),
    );
    final source = _source;
    if (source != null) unawaited(_prepare(source));
  }

  @override
  void didUpdateWidget(SendsarVoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final source = _source;
    final changed = widget.url != oldWidget.url ||
        !identical(widget.bytes, oldWidget.bytes);
    if (changed && source != null) {
      _bars = _voiceBars(_barSeed);
      _position = Duration.zero;
      _duration = Duration.zero;
      unawaited(_prepare(source));
    }
  }

  @override
  void dispose() {
    if (_activeVoice == this) _activeVoice = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  String get _barSeed => widget.url ?? widget.recordedAt;

  Source? get _source {
    final bytes = widget.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return BytesSource(bytes, mimeType: widget.mimeType ?? 'audio/mp4');
    }
    final url = widget.url;
    if (url == null || url.isEmpty) return null;
    return UrlSource(url);
  }

  Duration get _knownDuration {
    if (_duration > Duration.zero) return _duration;
    final hint = widget.durationSeconds;
    if (hint != null && hint > 0) return Duration(seconds: hint);
    return Duration.zero;
  }

  Future<void> _prepare(Source source) async {
    try {
      await _player.setSource(source);
    } catch (_) {
      // Duration stays unknown until playback starts.
    }
  }

  Future<void> _pauseForOther() async {
    if (!_playing) return;
    try {
      await _player.pause();
    } catch (_) {}
  }

  void _claim() {
    final previous = _activeVoice;
    _activeVoice = this;
    if (previous != null && previous != this && previous.mounted) {
      unawaited(previous._pauseForOther());
    }
  }

  Future<void> _toggle() async {
    final source = _source;
    if (source == null) return;
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      _claim();
      if (_player.state == PlayerState.paused) {
        await _player.resume();
        return;
      }
      await _player.play(source);
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _listenAt(double ratio) async {
    final source = _source;
    if (source == null) return;
    final fraction = ratio.clamp(0.0, 1.0);
    try {
      _claim();
      final duration = _knownDuration;
      final target = duration > Duration.zero ? duration * fraction : null;
      final state = _player.state;
      if (state == PlayerState.playing || state == PlayerState.paused) {
        if (target != null) await _player.seek(target);
        if (state != PlayerState.playing) await _player.resume();
        return;
      }
      await _player.play(source);
      if (target != null && target > Duration.zero) {
        await _player.seek(target);
      }
    } catch (_) {
      try {
        final fallback = _source;
        if (fallback != null) await _player.play(fallback);
      } catch (_) {
        if (mounted) setState(() => _playing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final outgoing = widget.outgoing;
    final accent = theme.accent;
    final buttonColor = outgoing ? Colors.white : accent;
    final iconColor = outgoing ? accent : Colors.white;
    final barColor = outgoing ? Colors.white : accent;
    final idleColor = barColor.withValues(alpha: outgoing ? 0.4 : 0.35);
    final durationColor = outgoing ? Colors.white : theme.textSecondary;
    final timeColor = outgoing
        ? Colors.white.withValues(alpha: 0.75)
        : theme.textMuted;
    final known = _knownDuration;
    final shown = _playing || _position > Duration.zero ? _position : known;
    final progress = known <= Duration.zero
        ? 0.0
        : (_position.inMilliseconds / known.inMilliseconds).clamp(0.0, 1.0);
    final timeLabel = formatMessageTime(widget.recordedAt);

    return Row(
      children: [
        Material(
          color: buttonColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _source == null ? null : _toggle,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Padding(
                padding: EdgeInsets.only(left: _playing ? 0 : 2),
                child: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: iconColor,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _wavePointer = event.localPosition;
                        _waveDownAt = DateTime.now();
                      },
                      onPointerMove: (event) {
                        final start = _wavePointer;
                        if (start != null &&
                            (event.localPosition - start).distance > 18) {
                          _wavePointer = null;
                        }
                      },
                      onPointerUp: (event) {
                        final start = _wavePointer;
                        final downAt = _waveDownAt;
                        _wavePointer = null;
                        _waveDownAt = null;
                        if (start == null || downAt == null) return;
                        if (DateTime.now().difference(downAt) >
                            const Duration(milliseconds: 350)) {
                          return;
                        }
                        final width = constraints.maxWidth;
                        if (width <= 0) return;
                        unawaited(_listenAt(start.dx / width));
                      },
                      onPointerCancel: (_) {
                        _wavePointer = null;
                        _waveDownAt = null;
                      },
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          bars: _bars,
                          progress: progress,
                          played: _playing || _position > Duration.zero,
                          active: barColor,
                          inactive: idleColor,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _clock(shown),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: durationColor,
                    ),
                  ),
                  const Spacer(),
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: TextStyle(fontSize: 12, color: timeColor),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (widget.onRemove != null)
          IconButton(
            tooltip: 'Delete voice message',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onRemove,
            icon: Icon(Icons.close, size: 18, color: theme.textMuted),
          ),
      ],
    );
  }
}

String _clock(Duration value) {
  final seconds = value.inSeconds;
  final minutes = seconds ~/ 60;
  final remain = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remain';
}

/// Stable bar heights so the same recording always draws the same wave.
List<double> _voiceBars(String seed, {int count = 42}) {
  var state = 2166136261;
  for (final code in seed.codeUnits) {
    state = (state ^ code) * 16777619 & 0x7fffffff;
  }
  if (state == 0) state = 1;
  final bars = <double>[];
  for (var i = 0; i < count; i++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    final noise = (state % 1000) / 1000;
    final wave = (math.sin(i * 0.55) * math.cos(i * 0.18)).abs();
    bars.add((0.18 + (0.55 * wave + 0.45 * noise) * 0.82).clamp(0.18, 1.0));
  }
  return bars;
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.played,
    required this.active,
    required this.inactive,
  });

  final List<double> bars;
  final double progress;
  final bool played;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;
    const gap = 2.0;
    final count = bars.length;
    final barWidth = math.max(1.5, (size.width - gap * (count - 1)) / count);
    final playedCount = (progress * count).floor();
    final activePaint = Paint()..color = active;
    final idlePaint = Paint()..color = inactive;
    for (var i = 0; i < count; i++) {
      final height = math.max(3.0, bars[i] * size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + gap),
          size.height - height,
          barWidth,
          height,
        ),
        const Radius.circular(1),
      );
      final filled = !played || i < playedCount;
      canvas.drawRRect(rect, filled ? activePaint : idlePaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.played != played ||
        oldDelegate.active != active ||
        oldDelegate.inactive != inactive ||
        oldDelegate.bars != bars;
  }
}
