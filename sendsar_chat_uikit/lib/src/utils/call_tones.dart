import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Lightweight synthesized call cues (no asset files).
/// Patterns mirror the JavaScript UI kit's WebAudio tones:
/// phone ringback / ringtone / hangup beep.

const _sampleRate = 44100;

class CallToneHandle {
  CallToneHandle._(this._player);

  /// Inert handle (already stopped) — useful as a placeholder.
  factory CallToneHandle.stopped() => CallToneHandle._(null).._stopped = true;

  final AudioPlayer? _player;
  bool _stopped = false;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {
      // Best-effort — tones are non-critical.
    }
  }
}

class _ToneNote {
  const _ToneNote(this.frequency, this.durationMs, this.startMs, this.gain);

  final double frequency;
  final int durationMs;
  final int startMs;
  final double gain;
}

/// 16-bit PCM mono WAV containing all [notes], padded to [totalMs].
Uint8List _buildWav(List<_ToneNote> notes, int totalMs) {
  final totalSamples = (_sampleRate * totalMs / 1000).round();
  final samples = Float64List(totalSamples);

  for (final note in notes) {
    final start = (_sampleRate * note.startMs / 1000).round();
    final length = (_sampleRate * note.durationMs / 1000).round();
    for (var i = 0; i < length; i++) {
      final index = start + i;
      if (index >= totalSamples) break;
      final t = i / _sampleRate;
      // Exponential decay from gain to ~0 over the note duration
      // (mirrors WebAudio exponentialRampToValueAtTime).
      final progress = i / length;
      final envelope = note.gain * math.pow(0.0001 / note.gain, progress);
      samples[index] += envelope * math.sin(2 * math.pi * note.frequency * t);
    }
  }

  final pcm = Int16List(totalSamples);
  for (var i = 0; i < totalSamples; i++) {
    final v = samples[i].clamp(-1.0, 1.0);
    pcm[i] = (v * 32767).round();
  }

  final dataSize = pcm.lengthInBytes;
  final bytes = BytesBuilder();
  void writeString(String s) => bytes.add(s.codeUnits);
  void writeUint32(int v) =>
      bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void writeUint16(int v) =>
      bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(_sampleRate);
  writeUint32(_sampleRate * 2); // byte rate
  writeUint16(2); // block align
  writeUint16(16); // bits per sample
  writeString('data');
  writeUint32(dataSize);
  bytes.add(pcm.buffer.asUint8List());
  return bytes.toBytes();
}

Uint8List? _ringbackWav;
Uint8List? _ringtoneWav;
Uint8List? _endToneWav;

Uint8List _ringback() => _ringbackWav ??= _buildWav(
      const [
        _ToneNote(440, 400, 0, 0.06),
        _ToneNote(480, 400, 0, 0.06),
      ],
      2000,
    );

Uint8List _ringtone() => _ringtoneWav ??= _buildWav(
      const [
        _ToneNote(523.25, 180, 0, 0.09),
        _ToneNote(659.25, 180, 200, 0.09),
        _ToneNote(783.99, 220, 400, 0.09),
      ],
      1600,
    );

Uint8List _endTone() => _endToneWav ??= _buildWav(
      const [
        _ToneNote(320, 160, 0, 0.07),
        _ToneNote(220, 220, 180, 0.07),
      ],
      450,
    );

Future<CallToneHandle> _playLoop(Uint8List wav) async {
  final player = AudioPlayer();
  try {
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(BytesSource(wav, mimeType: 'audio/wav'));
    return CallToneHandle._(player);
  } catch (_) {
    try {
      await player.dispose();
    } catch (_) {}
    return CallToneHandle._(null);
  }
}

/// Outgoing ringback: repeating dual-tone burst (440 + 480 Hz every 2s).
Future<CallToneHandle> playRingback() => _playLoop(_ringback());

/// Incoming ringtone: repeating ascending chirp (C5-E5-G5 every 1.6s).
Future<CallToneHandle> playRingtone() => _playLoop(_ringtone());

/// Short one-shot end/hangup beep (320 then 220 Hz).
Future<void> playEndTone() async {
  final player = AudioPlayer();
  try {
    await player.setReleaseMode(ReleaseMode.release);
    await player.play(BytesSource(_endTone(), mimeType: 'audio/wav'));
    player.onPlayerComplete.first.then((_) => player.dispose()).catchError((_) {});
  } catch (_) {
    try {
      await player.dispose();
    } catch (_) {}
  }
}
