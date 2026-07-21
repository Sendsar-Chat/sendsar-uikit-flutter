import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

import 'support/call_mocks.dart';

Widget _wrap(SendsarCallService service) {
  return MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(
        listenable: service,
        builder: (_, __) => SendsarOngoingCallBar(calls: service),
      ),
    ),
  );
}

void main() {
  testWidgets('shows Calling… while the call is still ringing', (tester) async {
    final h = callHarness();
    await h.service.startVideoCall('room-1');

    await tester.pumpWidget(_wrap(h.service));
    expect(find.text('Calling…'), findsOneWidget);

    h.service.dispose();
  });

  testWidgets('shows Ongoing call with live duration once connected',
      (tester) async {
    final h = callHarness();
    await h.service.startVideoCall('room-1');
    h.signaling.emitAccepted(const CallAcceptedEvent(
      callId: 'call-1',
      roomId: 'room-1',
      userId: 'user-b',
    ));
    await tester.pumpWidget(_wrap(h.service));
    await tester.pump();

    expect(find.text('Ongoing call · 0:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Ongoing call ·'), findsOneWidget);

    h.service.dispose();
    await tester.pump();
  });

  testWidgets('tap restores the call screen (unminimizes)', (tester) async {
    final h = callHarness();
    await h.service.startVideoCall('room-1');
    h.signaling.emitAccepted(const CallAcceptedEvent(
      callId: 'call-1',
      roomId: 'room-1',
      userId: 'user-b',
    ));
    await tester.pumpWidget(_wrap(h.service));
    await tester.pump();

    h.service.setMinimized(true);
    expect(h.service.minimized, isTrue);

    await tester.tap(find.byType(SendsarOngoingCallBar));
    expect(h.service.minimized, isFalse);

    h.service.dispose();
    await tester.pump();
  });
}
