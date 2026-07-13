# sendsar_chat_uikit

Ready-to-use chat UI for Flutter — built on [`sendsar_chat`](https://pub.dev/packages/sendsar_chat).

## Install

```yaml
dependencies:
  sendsar_chat_uikit: ^0.2.0
  sendsar_chat: ^0.1.0
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

## Exports

| Category | Symbols |
|----------|---------|
| Setup | `SendsarScope`, `SendsarConfig` |
| Shell | `SendsarChatShell`, `SendsarChatShellState` |
| Widgets | `SendsarConversationList`, `SendsarMessageList`, `SendsarComposer`, `SendsarRoomInfo` |
| Theme | `SendsarChatTheme`, `SendsarThemeOverride`, `SendsarConversationListStyle`, `SendsarMessageListStyle` |
| Utils | `resolveRoomLabel`, `formatRelativeTime`, `ComposerTypingController`, … |

## Docs

Full guide, sample app, and BFF setup: [github.com/Sendsar-Chat/sendsar-uikit-flutter](https://github.com/Sendsar-Chat/sendsar-uikit-flutter)

## License

MIT
