import 'package:sendsar_call/sendsar_call.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

/// Session service stub that lets tests flip readiness and inject a client.
class FakeSessionService extends SendsarSessionService {
  FakeSessionService()
      : super(SendsarConfig(fetchSession: () async => throw UnimplementedError()));

  SendsarClient? _fakeClient;
  String _status = 'idle';

  @override
  SessionManagerState get state => SessionManagerState(
        status: _status,
        client: _fakeClient,
        session: null,
      );

  @override
  SendsarClient? get client => _fakeClient;

  void setReady(SendsarClient client) {
    _fakeClient = client;
    _status = 'ready';
    notifyListeners();
  }

  void setOffline() {
    _fakeClient = null;
    _status = 'offline';
    notifyListeners();
  }
}

/// In-memory signaling — same pattern as the sendsar_call SDK tests.
class MockCallSignaling implements CallSignaling {
  MockCallSignaling({this.currentUserId = 'user-a', this.isConnected = true});

  @override
  final String? currentUserId;

  @override
  final bool isConnected;

  final _inviteHandlers = <void Function(CallInviteEvent payload)>{};
  final _acceptedHandlers = <void Function(CallAcceptedEvent payload)>{};
  final _declinedHandlers = <void Function(CallDeclinedEvent payload)>{};
  final _endedHandlers = <void Function(CallEndedEvent payload)>{};

  Future<StartCallResult> Function(String roomId, StartCallParams params)?
      startCallImpl;

  static const livekit = LiveKitCredentials(
    url: 'ws://localhost:7880',
    token: 'lk-token',
    expiresAt: '2099-01-01T00:00:00.000Z',
  );

  static const call = CallRecord(
    id: 'call-1',
    roomId: 'room-1',
    type: 'video',
    status: 'ringing',
    livekitRoomName: 'fc_t_room-1',
    createdByUserId: 'user-a',
  );

  void emitInvite(CallInviteEvent payload) {
    for (final handler in Set.of(_inviteHandlers)) {
      handler(payload);
    }
  }

  void emitAccepted(CallAcceptedEvent payload) {
    for (final handler in Set.of(_acceptedHandlers)) {
      handler(payload);
    }
  }

  void emitEnded(CallEndedEvent payload) {
    for (final handler in Set.of(_endedHandlers)) {
      handler(payload);
    }
  }

  @override
  void Function() callInvite(void Function(CallInviteEvent payload) handler) {
    _inviteHandlers.add(handler);
    return () => _inviteHandlers.remove(handler);
  }

  @override
  void Function() callAccepted(
      void Function(CallAcceptedEvent payload) handler) {
    _acceptedHandlers.add(handler);
    return () => _acceptedHandlers.remove(handler);
  }

  @override
  void Function() callDeclined(
      void Function(CallDeclinedEvent payload) handler) {
    _declinedHandlers.add(handler);
    return () => _declinedHandlers.remove(handler);
  }

  @override
  void Function() callEnded(void Function(CallEndedEvent payload) handler) {
    _endedHandlers.add(handler);
    return () => _endedHandlers.remove(handler);
  }

  @override
  Future<StartCallResult> startCall(String roomId, StartCallParams params) {
    if (startCallImpl != null) return startCallImpl!(roomId, params);
    return Future.value(
      const StartCallResult(call: call, livekit: livekit, ringTimeoutSeconds: 30),
    );
  }

  @override
  Future<StartCallResult> acceptCall(String roomId, String callId) async {
    return const StartCallResult(
      call: CallRecord(
        id: 'call-1',
        roomId: 'room-1',
        type: 'video',
        status: 'active',
        livekitRoomName: 'fc_t_room-1',
        createdByUserId: 'user-a',
      ),
      livekit: livekit,
      ringTimeoutSeconds: 30,
    );
  }

  @override
  Future<CallRecord> declineCall(String roomId, String callId) async {
    return const CallRecord(
      id: 'call-1',
      roomId: 'room-1',
      type: 'video',
      status: 'declined',
      livekitRoomName: 'fc_t_room-1',
      createdByUserId: 'user-a',
    );
  }

  @override
  Future<CallRecord> endCall(String roomId, String callId, {String? reason}) async {
    return const CallRecord(
      id: 'call-1',
      roomId: 'room-1',
      type: 'video',
      status: 'ended',
      livekitRoomName: 'fc_t_room-1',
      createdByUserId: 'user-a',
    );
  }

  @override
  Future<CallRecord> leaveCall(String roomId, String callId) async {
    return const CallRecord(
      id: 'call-1',
      roomId: 'room-1',
      type: 'video',
      status: 'ended',
      livekitRoomName: 'fc_t_room-1',
      createdByUserId: 'user-a',
    );
  }

  @override
  Future<LiveKitCredentials> refreshCallToken(String roomId, String callId) async =>
      livekit;

  @override
  Future<CallRecord?> getActiveCall(String roomId) async => null;
}

class FakeMediaConnector implements MediaConnector {
  var connected = false;
  var micEnabled = false;
  var cameraEnabled = false;

  @override
  Future<void> connect(
      LiveKitCredentials credentials, MediaConnectOptions media) async {
    connected = true;
    if (media.audio) micEnabled = true;
    if (media.video) cameraEnabled = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    micEnabled = false;
    cameraEnabled = false;
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    micEnabled = enabled;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabled = enabled;
  }
}

const kTestInvite = CallInviteEvent(
  callId: 'call-1',
  roomId: 'room-1',
  type: 'video',
  createdByUserId: 'user-b',
  livekitRoomName: 'fc_t_room-1',
);

typedef CallHarness = ({
  SendsarCallService service,
  FakeSessionService session,
  MockCallSignaling signaling,
  FakeMediaConnector media,
});

CallHarness callHarness({String currentUserId = 'user-a'}) {
  final session = FakeSessionService();
  final signaling = MockCallSignaling(currentUserId: currentUserId);
  final media = FakeMediaConnector();
  final service = SendsarCallService(
    session,
    enableTones: false,
    createCallClient: (chat) => CallClient(
      CallClientOptions(
        chat: chat,
        signaling: signaling,
        createMediaSession: ({createRoom, required handlers, debug = false}) =>
            media,
      ),
    ),
  );
  session.setReady(
    SendsarClient(const SendsarInitOptions(apiUrl: 'https://api.example.com')),
  );
  return (service: service, session: session, signaling: signaling, media: media);
}
