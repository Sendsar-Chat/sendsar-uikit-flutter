import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

CallLogData _log({
  String callType = 'audio',
  String outcome = 'completed',
  String initiatedByUserId = 'user-a',
  bool isGroup = false,
  int? durationSeconds,
}) {
  return CallLogData(
    callId: 'call-1',
    callType: callType,
    outcome: outcome,
    initiatedByUserId: initiatedByUserId,
    isGroup: isGroup,
    durationSeconds: durationSeconds,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('SendsarCallLogBubble', () {
    testWidgets('completed call shows duration and call icon', (tester) async {
      await tester.pumpWidget(_wrap(
        SendsarCallLogBubble(
          data: _log(durationSeconds: 65),
          selfUserId: 'user-a',
        ),
      ));

      expect(find.text('Voice call · 1:05'), findsOneWidget);
      expect(find.byIcon(Icons.call), findsOneWidget);
    });

    testWidgets('missed call for callee shows missed icon and label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SendsarCallLogBubble(
          data: _log(outcome: 'missed', initiatedByUserId: 'user-a'),
          selfUserId: 'user-b',
        ),
      ));

      expect(find.text('Missed voice call'), findsOneWidget);
      expect(find.byIcon(Icons.phone_missed), findsOneWidget);
    });

    testWidgets('cancelled call is missed for the callee only', (tester) async {
      await tester.pumpWidget(_wrap(
        SendsarCallLogBubble(
          data: _log(outcome: 'cancelled', initiatedByUserId: 'user-a'),
          selfUserId: 'user-a',
        ),
      ));

      expect(find.text('Call cancelled'), findsOneWidget);
      expect(find.byIcon(Icons.call), findsOneWidget);
      expect(find.byIcon(Icons.phone_missed), findsNothing);
    });

    testWidgets('video call uses videocam icon', (tester) async {
      await tester.pumpWidget(_wrap(
        SendsarCallLogBubble(
          data: _log(callType: 'video', durationSeconds: 10),
          selfUserId: 'user-a',
        ),
      ));

      expect(find.byIcon(Icons.videocam), findsOneWidget);
    });

    testWidgets('tap redials with the call type', (tester) async {
      CallType? redialed;
      await tester.pumpWidget(_wrap(
        SendsarCallLogBubble(
          data: _log(callType: 'video', durationSeconds: 10),
          selfUserId: 'user-a',
          onRedial: (type) => redialed = type,
        ),
      ));

      await tester.tap(find.byType(SendsarCallLogBubble));
      expect(redialed, 'video');
    });
  });

  group('messagePreview for call logs', () {
    Message callLogMessage() {
      return const Message(
        id: 'msg-1',
        roomId: 'room-1',
        senderId: 'user-a',
        parts: [
          MessagePart(
            type: kCallLogPartType,
            data: {
              'callId': 'call-1',
              'callType': 'audio',
              'outcome': 'missed',
              'initiatedByUserId': 'user-a',
              'isGroup': false,
            },
          ),
        ],
        previewText: null,
        createdAt: '2026-01-01T00:00:00.000Z',
      );
    }

    test('viewer-specific preview for callee', () {
      expect(
        messagePreview(callLogMessage(), selfUserId: 'user-b'),
        'Missed voice call',
      );
    });

    test('viewer-specific preview for caller', () {
      expect(
        messagePreview(callLogMessage(), selfUserId: 'user-a'),
        'No answer',
      );
    });
  });
}
