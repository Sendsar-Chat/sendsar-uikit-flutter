import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_call/sendsar_call.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import 'support/call_mocks.dart';

void main() {
  group('SendsarCallService', () {
    test('startVideoCall goes outgoing then active once peer accepts', () async {
      final h = callHarness();

      final startFuture = h.service.startVideoCall('room-1');
      expect(h.service.callState, callStateOutgoing);
      expect(h.service.calling, isTrue);
      expect(h.service.showCallUi, isTrue);

      final call = await startFuture;
      expect(call.id, 'call-1');
      expect(h.service.calling, isFalse);
      expect(h.service.activeCall?.id, 'call-1');

      h.signaling.emitAccepted(const CallAcceptedEvent(
        callId: 'call-1',
        roomId: 'room-1',
        userId: 'user-b',
      ));
      await pumpEventQueue();

      expect(h.service.callState, callStateActive);
      expect(h.service.mediaStatus, 'connected');
      expect(h.media.connected, isTrue);
      h.service.dispose();
    });

    test('rejects a second call while one is in progress', () async {
      final h = callHarness();

      await h.service.startAudioCall('room-1');
      expect(
        () => h.service.startAudioCall('room-2'),
        throwsA(isA<StateError>()),
      );
      h.service.dispose();
    });

    test('incoming invite is exposed; accept connects media', () async {
      final h = callHarness(currentUserId: 'user-b');

      h.signaling.emitInvite(kTestInvite);
      await pumpEventQueue();

      expect(h.service.callState, callStateIncoming);
      expect(h.service.incomingInvite?.callId, 'call-1');
      expect(h.service.showCallUi, isTrue);

      final call = await h.service.accept();
      await pumpEventQueue();

      expect(call.status, 'active');
      expect(h.service.callState, callStateActive);
      expect(h.service.incomingInvite, isNull);
      expect(h.media.connected, isTrue);
      h.service.dispose();
    });

    test('decline resets to idle', () async {
      final h = callHarness(currentUserId: 'user-b');

      h.signaling.emitInvite(kTestInvite);
      await pumpEventQueue();

      await h.service.decline();
      await pumpEventQueue();

      expect(h.service.callState, callStateIdle);
      expect(h.service.incomingInvite, isNull);
      expect(h.service.showCallUi, isFalse);
      h.service.dispose();
    });

    test('hangUp while outgoing cancels and returns to idle', () async {
      final h = callHarness();

      await h.service.startVideoCall('room-1');
      expect(h.service.callState, callStateOutgoing);

      await h.service.hangUp(reason: 'cancelled');
      await pumpEventQueue();

      expect(h.service.callState, callStateIdle);
      expect(h.service.showCallUi, isFalse);
      expect(h.service.activeCall, isNull);
      h.service.dispose();
    });

    test('remote callEnded resets state and media', () async {
      final h = callHarness();

      await h.service.startVideoCall('room-1');
      h.signaling.emitAccepted(const CallAcceptedEvent(
        callId: 'call-1',
        roomId: 'room-1',
        userId: 'user-b',
      ));
      await pumpEventQueue();
      expect(h.service.callState, callStateActive);

      h.signaling.emitEnded(const CallEndedEvent(
        callId: 'call-1',
        roomId: 'room-1',
        reason: 'ended',
      ));
      await pumpEventQueue();

      expect(h.service.callState, callStateIdle);
      expect(h.service.mediaStatus, 'idle');
      expect(h.media.connected, isFalse);
      expect(h.service.showCallUi, isFalse);
      h.service.dispose();
    });

    test('toggleMicrophone flips state optimistically', () async {
      final h = callHarness();

      await h.service.startAudioCall('room-1');
      h.signaling.emitAccepted(const CallAcceptedEvent(
        callId: 'call-1',
        roomId: 'room-1',
        userId: 'user-b',
      ));
      await pumpEventQueue();

      expect(h.service.micEnabled, isTrue);
      await h.service.toggleMicrophone();
      expect(h.service.micEnabled, isFalse);
      expect(h.media.micEnabled, isFalse);
      h.service.dispose();
    });

    test('audio call starts with camera disabled', () async {
      final h = callHarness();

      await h.service.startAudioCall('room-1');
      expect(h.service.cameraEnabled, isFalse);
      expect(h.service.micEnabled, isTrue);
      h.service.dispose();
    });

    test('setMinimized is refused while incoming', () async {
      final h = callHarness(currentUserId: 'user-b');

      h.signaling.emitInvite(kTestInvite);
      await pumpEventQueue();

      h.service.setMinimized(true);
      expect(h.service.minimized, isFalse);

      await h.service.accept();
      await pumpEventQueue();

      h.service.setMinimized(true);
      expect(h.service.minimized, isTrue);
      h.service.dispose();
    });

    test('session going offline destroys call state', () async {
      final h = callHarness();

      await h.service.startVideoCall('room-1');
      expect(h.service.showCallUi, isTrue);

      h.session.setOffline();
      await pumpEventQueue();

      expect(h.service.callState, callStateIdle);
      expect(h.service.showCallUi, isFalse);
      h.service.dispose();
    });
  });
}
