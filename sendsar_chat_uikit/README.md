# sendsar_chat_uikit

Ready-to-use chat UI for Flutter — built on [`sendsar_chat`](https://pub.dev/packages/sendsar_chat), with voice/video calls via [`sendsar_call`](https://pub.dev/packages/sendsar_call) (LiveKit).

## Install

```yaml
dependencies:
  sendsar_chat_uikit: ^0.3.0
  sendsar_chat: ^0.2.0
```

## Quick start

```dart
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

SendsarScope(
  config: SendsarConfig(
    fetchSession: () => myBackend.fetchChatSession(),
  ),
  child: SendsarChatShell(
    users: [
      UserDirectoryEntry(id: 'usr_1', displayName: 'Alice'),
    ],
  ),
)
```

Register theme extensions on `MaterialApp` for light/dark support:

```dart
extensions: const [SendsarChatTheme.light],  // or .dark in darkTheme
```

## Calls

`SendsarChatShell` ships with voice/video calling out of the box: header call
buttons, an in-app call overlay (incoming/outgoing ring, active call video,
minimized chip), call tones, and tappable call-log bubbles for redial.

- State lives in `SendsarCallService` (provided by `SendsarScope`) — use it
  directly if you build custom UI: `startAudioCall`, `startVideoCall`,
  `accept`, `decline`, `hangUp`, `toggleMicrophone`, `toggleCamera`,
  `toggleSpeaker`, plus `callState`, `durationLabel`, and video tracks.
- **Permissions**: calls capture mic/camera. Add `NSMicrophoneUsageDescription`
  / `NSCameraUsageDescription` (iOS) and `RECORD_AUDIO` / `CAMERA` (Android);
  browsers prompt automatically on web.

## Exports

| Category | Symbols |
|----------|---------|
| Setup | `SendsarScope`, `SendsarConfig` |
| Shell | `SendsarChatShell`, `SendsarChatShellState` |
| Widgets | `SendsarConversationList`, `SendsarMessageList`, `SendsarComposer`, `SendsarRoomInfo` |
| Calls | `SendsarCallService`, `SendsarCallOverlay`, `SendsarCallLogBubble`, call tones |
| Theme | `SendsarChatTheme`, `SendsarThemeOverride`, `SendsarConversationListStyle`, `SendsarMessageListStyle` |
| Utils | `resolveRoomLabel`, `formatRelativeTime`, `ComposerTypingController`, … |

## Docs

Full guide, sample app, and BFF setup: [github.com/Sendsar-Chat/sendsar-uikit-flutter](https://github.com/Sendsar-Chat/sendsar-uikit-flutter)

## License

MIT
