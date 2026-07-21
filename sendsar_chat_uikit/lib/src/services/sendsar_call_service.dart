import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:sendsar_call/sendsar_call.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../utils/call_tones.dart';
import 'sendsar_session_service.dart';

/// Media connection status for the call UI.
typedef SendsarCallMediaStatus = String; // idle | reconnecting | connected

/// Voice/video call state for the UI kit — wraps [CallClient] from
/// `sendsar_call` the same way the Angular UI kit wraps the JS call SDK.
class SendsarCallService extends ChangeNotifier {
  SendsarCallService(
    this._session, {
    CallClient Function(SendsarClient chat)? createCallClient,
    bool enableTones = true,
  })  : _createCallClient = createCallClient,
        _tonesEnabled = enableTones {
    _session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final SendsarSessionService _session;
  final CallClient Function(SendsarClient chat)? _createCallClient;
  final bool _tonesEnabled;

  CallClient? _client;
  SendsarClient? _boundChatClient;
  final List<void Function()> _unsubs = [];
  CallInviteEvent? _bufferedInvite;
  void Function()? _earlyInviteUnsub;
  Timer? _durationTimer;
  DateTime? _connectedAt;
  CallToneHandle? _toneHandle;
  var _toneEpoch = 0;
  var _disposed = false;

  CallState _callState = callStateIdle;
  CallRecord? _activeCall;
  CallInviteEvent? _incomingInvite;
  bool _calling = false;
  String? _error;
  SendsarCallMediaStatus _mediaStatus = 'idle';
  int _elapsedSeconds = 0;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _speakerEnabled = true;
  bool _minimized = false;
  lk.VideoTrack? _localVideoTrack;
  lk.VideoTrack? _remoteVideoTrack;

  CallState get callState => _callState;
  CallRecord? get activeCall => _activeCall;
  CallInviteEvent? get incomingInvite => _incomingInvite;
  bool get calling => _calling;
  String? get error => _error;
  SendsarCallMediaStatus get mediaStatus => _mediaStatus;
  int get elapsedSeconds => _elapsedSeconds;
  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  bool get speakerEnabled => _speakerEnabled;
  bool get minimized => _minimized;
  lk.VideoTrack? get localVideoTrack => _localVideoTrack;
  lk.VideoTrack? get remoteVideoTrack => _remoteVideoTrack;

  /// Live `m:ss` / `h:mm:ss` while media is connected; empty otherwise.
  String get durationLabel {
    if (_mediaStatus != 'connected' && _mediaStatus != 'reconnecting') {
      return '';
    }
    if (_callState != callStateActive) return '';
    return formatCallTimer(_elapsedSeconds);
  }

  /// True while a call UI should be visible (outgoing, incoming, connecting,
  /// active, or dialing).
  bool get showCallUi {
    if (_calling) return true;
    return _callState == callStateOutgoing ||
        _callState == callStateIncoming ||
        _callState == callStateConnecting ||
        _callState == callStateActive;
  }

  /// Ensure [CallClient] is created so incoming invites are received.
  void ensureReady() {
    if (_session.client == null) return;
    _requireCallClient();
    final buffered = _bufferedInvite;
    if (buffered != null && _client != null) {
      _client!.ingestInvite(buffered);
      _bufferedInvite = null;
    }
  }

  Future<CallRecord> startVideoCall(String roomId) => _startCall(roomId, 'video');

  Future<CallRecord> startAudioCall(String roomId) => _startCall(roomId, 'audio');

  /// Start (or redial) a call of the given type.
  Future<CallRecord> startCallOfType(String roomId, CallType type) {
    return type == 'video' ? startVideoCall(roomId) : startAudioCall(roomId);
  }

  Future<CallRecord> accept([String? callId, String? roomId]) async {
    final invite = _incomingInvite;
    final resolvedCallId = callId ?? invite?.callId;
    if (resolvedCallId == null) {
      throw StateError('No incoming call to accept');
    }

    _error = null;
    _calling = true;
    notifyListeners();
    _stopTones();
    try {
      final call =
          await _requireCallClient().accept(resolvedCallId, roomId ?? invite?.roomId);
      _activeCall = call;
      _incomingInvite = null;
      _minimized = false;
      return call;
    } catch (err) {
      _error = _messageFor(err, 'Failed to accept call');
      rethrow;
    } finally {
      _calling = false;
      _notify();
    }
  }

  Future<CallRecord?> decline([String? callId]) async {
    final invite = _incomingInvite;
    final resolvedCallId = callId ?? invite?.callId;
    if (resolvedCallId == null) return null;

    _stopTones();
    try {
      final call = await _requireCallClient().decline(resolvedCallId);
      _incomingInvite = null;
      if (_callState == callStateIncoming) {
        _callState = callStateIdle;
      }
      _playEndTone();
      _notify();
      return call;
    } catch (err) {
      _error = _messageFor(err, 'Failed to decline call');
      _notify();
      rethrow;
    }
  }

  Future<CallRecord?> hangUp({String? reason}) async {
    _stopTones();
    try {
      final callClient = _requireCallClient();
      final result = await callClient.hangUp(reason: reason);
      _resetCallUi(playEnd: true);
      if (result == null &&
          (_calling ||
              _callState == callStateOutgoing ||
              _callState == callStateConnecting)) {
        _calling = false;
        _callState = callStateIdle;
        _activeCall = null;
      }
      _notify();
      return result;
    } catch (err) {
      _error = _messageFor(err, 'Failed to hang up');
      _notify();
      rethrow;
    }
  }

  Future<void> toggleMicrophone() async {
    final previous = _micEnabled;
    _micEnabled = !previous;
    notifyListeners();
    try {
      await _requireCallClient().setMicrophoneEnabled(_micEnabled);
    } catch (err) {
      _micEnabled = previous;
      _error = _messageFor(err, 'Failed to toggle microphone');
      _notify();
      rethrow;
    }
  }

  Future<void> toggleCamera() async {
    final previous = _cameraEnabled;
    _cameraEnabled = !previous;
    if (!_cameraEnabled) {
      _localVideoTrack = null;
    }
    notifyListeners();
    try {
      await _requireCallClient().setCameraEnabled(_cameraEnabled);
    } catch (err) {
      _cameraEnabled = previous;
      _error = _messageFor(err, 'Failed to toggle camera');
      _notify();
      rethrow;
    }
  }

  /// Route audio to loudspeaker on mobile; no-op on desktop/web.
  Future<void> toggleSpeaker() async {
    _speakerEnabled = !_speakerEnabled;
    notifyListeners();
    try {
      await lk.Hardware.instance.setSpeakerphoneOn(_speakerEnabled);
    } catch (_) {
      // Speaker routing is only supported on iOS/Android.
    }
  }

  void setMinimized(bool minimized) {
    if (_callState == callStateIncoming) return;
    if (_minimized == minimized) return;
    _minimized = minimized;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSessionChanged);
    _destroyClient(notify: false);
    super.dispose();
  }

  void _onSessionChanged() {
    final status = _session.state.status;
    final chat = _session.client;

    if (status != 'ready' || chat == null) {
      _destroyClient();
      return;
    }

    if (_boundChatClient != chat) {
      _destroyClient();
      _attachEarlyInviteListener(chat);
      ensureReady();
    }
  }

  void _attachEarlyInviteListener(SendsarClient client) {
    _earlyInviteUnsub?.call();
    _earlyInviteUnsub = client.on<CallInviteEvent>(SocketEvent.callInvite, (invite) {
      if (_client != null) return;
      if (showCallUi) return;
      _bufferedInvite = invite;
      _incomingInvite = invite;
      _callState = callStateIncoming;
      _notify();
    });
  }

  Future<CallRecord> _startCall(String roomId, CallType type) async {
    if (roomId.isEmpty) {
      throw ArgumentError('roomId is required to start a call');
    }
    if (_calling || showCallUi) {
      throw StateError('A call is already in progress');
    }

    _calling = true;
    _error = null;
    _micEnabled = true;
    _cameraEnabled = type == 'video';
    _speakerEnabled = true;
    _minimized = false;
    _clearMediaTracks();
    // Optimistic: show overlay as "Calling…" before the start API returns.
    _callState = callStateOutgoing;
    notifyListeners();

    try {
      final call =
          await _requireCallClient().start(roomId, CallStartOptions(type: type));
      _activeCall = call;
      return call;
    } catch (err) {
      _error = _messageFor(err, 'Failed to start call');
      _callState = callStateIdle;
      _activeCall = null;
      _stopTones();
      rethrow;
    } finally {
      _calling = false;
      _notify();
    }
  }

  CallClient _requireCallClient() {
    final chat = _session.client;
    if (chat == null) {
      throw StateError('Sendsar client is not connected');
    }

    if (_client == null || _boundChatClient != chat) {
      _destroyClient(notify: false);
      _boundChatClient = chat;
      final client = _createCallClient?.call(chat) ??
          CallClient(CallClientOptions(chat: chat));
      _client = client;
      _unsubs.addAll([
        client.on<CallStateChangeEvent>('stateChange', (event) {
          _callState = event.to;
          _activeCall = event.call;
          if (event.to == callStateIdle || event.to == callStateEnded) {
            _resetCallUi(playEnd: event.to == callStateEnded);
            if (event.to == callStateEnded) {
              _callState = callStateIdle;
            }
          }
          _notify();
        }),
        client.on<CallInviteEvent>('incoming', (invite) {
          _incomingInvite = invite;
          _callState = callStateIncoming;
          _minimized = false;
          _notify();
        }),
        client.on<CallTrackEvent>('localTrack', (event) {
          final track = event.track;
          if (track is lk.VideoTrack) {
            _localVideoTrack = track;
            _notify();
          }
        }),
        client.on<CallTrackEvent>('remoteTrack', (event) {
          final track = event.track;
          if (track is lk.VideoTrack) {
            _remoteVideoTrack = track;
            _notify();
          }
        }),
        client.on<CallTrackEvent>('remoteTrackRemoved', (event) {
          if (event.track is lk.VideoTrack) {
            _remoteVideoTrack = null;
            _notify();
          }
        }),
        client.on<Object?>('mediaConnected', (_) {
          _mediaStatus = 'connected';
          _startDurationTimer();
          _stopTones();
          _notify();
        }),
        client.on<Object?>('mediaReconnecting', (_) {
          _mediaStatus = 'reconnecting';
          _notify();
        }),
        client.on<Object?>('mediaReconnected', (_) {
          _mediaStatus = 'connected';
          _notify();
        }),
        client.on<Object?>('mediaDisconnected', (_) {
          _mediaStatus = 'idle';
          _stopDurationTimer();
          _notify();
        }),
        client.on<CallErrorEvent>('error', (event) {
          _error = event.message;
          _notify();
        }),
        client.on<CallEndedEvent>('ended', (_) {
          _resetCallUi(playEnd: true);
          _callState = callStateIdle;
          _activeCall = null;
          _incomingInvite = null;
          _notify();
        }),
        client.on<CallDeclinedEvent>('declined', (_) {
          _resetCallUi(playEnd: true);
          _callState = callStateIdle;
          _activeCall = null;
          _incomingInvite = null;
          _notify();
        }),
      ]);
    }

    return _client!;
  }

  void _notify() {
    if (_disposed) return;
    _syncCallTones();
    notifyListeners();
  }

  void _syncCallTones() {
    if (!_tonesEnabled) return;
    final state = _callState;
    final media = _mediaStatus;
    if (media == 'connected' ||
        state == callStateActive ||
        state == callStateConnecting) {
      _stopTones();
      return;
    }
    if (state == callStateOutgoing) {
      _startTone(playRingback);
      return;
    }
    if (state == callStateIncoming) {
      _startTone(playRingtone);
      return;
    }
    _stopTones();
  }

  void _startTone(Future<CallToneHandle> Function() play) {
    if (_toneHandle != null) return;
    final epoch = ++_toneEpoch;
    // Placeholder so a second sync doesn't start another tone while loading.
    _toneHandle = CallToneHandle.stopped();
    unawaited(play().then((handle) {
      if (epoch != _toneEpoch || _disposed) {
        unawaited(handle.stop());
        return;
      }
      _toneHandle = handle;
    }));
  }

  void _stopTones() {
    _toneEpoch += 1;
    final handle = _toneHandle;
    _toneHandle = null;
    if (handle != null) {
      unawaited(handle.stop());
    }
  }

  void _playEndTone() {
    if (!_tonesEnabled) return;
    unawaited(playEndTone());
  }

  void _resetCallUi({required bool playEnd}) {
    _stopTones();
    if (playEnd) {
      _playEndTone();
    }
    _stopDurationTimer();
    _clearMediaTracks();
    _incomingInvite = null;
    _mediaStatus = 'idle';
    _minimized = false;
    _speakerEnabled = true;
  }

  void _startDurationTimer() {
    _stopDurationTimer();
    _connectedAt = DateTime.now();
    _elapsedSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final connectedAt = _connectedAt;
      if (connectedAt == null) return;
      _elapsedSeconds = DateTime.now().difference(connectedAt).inSeconds;
      _notify();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedAt = null;
    _elapsedSeconds = 0;
  }

  void _clearMediaTracks() {
    _localVideoTrack = null;
    _remoteVideoTrack = null;
  }

  void _destroyClient({bool notify = true}) {
    for (final unsub in _unsubs) {
      unsub();
    }
    _unsubs.clear();
    _earlyInviteUnsub?.call();
    _earlyInviteUnsub = null;
    _stopTones();
    _stopDurationTimer();
    _client?.destroy();
    _client = null;
    _boundChatClient = null;
    _bufferedInvite = null;
    _callState = callStateIdle;
    _activeCall = null;
    _incomingInvite = null;
    _calling = false;
    _mediaStatus = 'idle';
    _minimized = false;
    _speakerEnabled = true;
    _clearMediaTracks();
    if (notify) _notify();
  }

  String _messageFor(Object err, String fallback) {
    if (err is StateError) return err.message;
    if (err is ArgumentError) return err.message?.toString() ?? fallback;
    if (err is SendsarError) return err.message;
    return fallback;
  }
}
