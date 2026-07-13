# Sendsar UI Kit for Flutter

Ready-to-use chat UI for Flutter, built on [`sendsar_chat`](https://pub.dev/packages/sendsar_chat).

The **example** app mirrors [sendsar-uikit-angular](https://github.com/Sendsar-Chat/sendsar-uikit-angular): direct messages, groups, images/files, reactions, typing indicators, read receipts, presence, edit/delete, and pagination.

## Auth model

| | **Your server** | **Client** |
|---|---|---|
| **Credential** | `sk_*` in `sample-bff/.env` | Session JWT only |
| **Calls** | Mint token, create rooms | Chat REST + WebSocket |

```text
Client → your server   POST /api/chat/session   → JWT
Client → Sendsar gateway                      → chat (Bearer JWT)
```

> `sample-bff/` is a demo — it skips real login. In production, authenticate **your** user before minting a JWT.

## Quick start

**Prerequisites:** Flutter 3.24+, Node.js 18+, a Sendsar tenant API key ([docs](https://docs.sendsar.com/setup/authentication)).

```bash
git clone https://github.com/Sendsar-Chat/sendsar-uikit-flutter.git
cd sendsar-uikit-flutter
npm install
npm run setup
# Edit sample-bff/.env → SENDSAR_API_KEY

# Option A — one command (BFF + Flutter web)
npm start

# Option B — two terminals
npm run start:bff          # http://localhost:4400
cd example && flutter pub get && flutter run -d chrome
```

The example defaults to `http://localhost:4400` for the BFF. Override if needed:

```bash
flutter run -d chrome --dart-define=BFF_BASE_URL=http://localhost:4400
```

The UI kit depends on [`sendsar_chat`](https://pub.dev/packages/sendsar_chat) from pub.dev. To develop against a local monorepo checkout:

```bash
npm run use:local-sdk   # requires ../sendsar-monorepo
cd sendsar_chat_uikit && flutter pub get
```

Revert with `npm run use:pub-sdk`. See [PUBLISHING.md](PUBLISHING.md) for pub.dev release steps.

## Sample app features

| Feature | How it works |
|---------|----------------|
| **Direct messages** | BFF `POST /api/chat/demo/ensure-dm` — deduped by `externalId`, friendly labels via user directory |
| **Groups** | BFF `POST /api/chat/demo/ensure-group` — named room + participants |
| **Text + attachments** | Composer toolbar: text, emoji picker, file upload |
| **Reactions** | Long-press a message → emoji row in action sheet |
| **Typing** | `ComposerTypingController` + thread header indicator |
| **Read receipts** | ✓ / ✓✓ inside your message bubbles (1:1) |
| **Presence** | Online dot in sidebar (DM) |
| **Unread badges** | Count on conversation rows |
| **Edit / delete** | Long-press your message → action sheet |
| **Pagination** | “Load older messages” in thread |
| **Dark mode** | Follows system / `MaterialApp` theme |

## Integrate in your app

```dart
MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    extensions: const [SendsarChatTheme.light],
  ),
  darkTheme: ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    extensions: const [SendsarChatTheme.dark],
  ),
  home: SendsarScope(
    config: SendsarConfig(
      fetchSession: () => myApi.fetchChatSession(),
      animatedEmoji: true, // Noto Lottie in bubbles (default)
    ),
    child: SendsarChatShell(
      users: [
        UserDirectoryEntry(id: 'usr_1', displayName: 'Alice'),
        // ...
      ],
    ),
  ),
)
```

Pass a **user directory** (`UserDirectoryEntry` list) so DM rooms show peer names instead of internal ids.

See the [Flutter chat SDK docs](https://docs.sendsar.com/sdk/flutter/) for session shape and gateway URLs.

## UI kit widgets

| Widget | Description |
|--------|-------------|
| `SendsarChatShell` | Inbox + thread, typing, presence, responsive layout |
| `SendsarConversationList` | Rooms, search, unread badges, avatars |
| `SendsarMessageList` | Live messages, cached media, reactions, receipts |
| `SendsarComposer` | Bordered input + toolbar (emoji, attach, send) |
| `SendsarRoomInfo` | Room details sidebar (bottom sheet on mobile) |

### UX patterns

- **Composer** — Text field on top, toolbar below (emoji + attach left, send right). Send button matches toolbar height.
- **Messages** — Clean bubbles by default. **Long-press** a message for reactions, edit, or delete (Telegram-style). Tap existing reaction pills to toggle.
- **Mobile** — Thread back button, room info via bottom sheet.

### Theming & customization

| API | Purpose |
|-----|---------|
| `SendsarChatTheme.light` / `.dark` | Color tokens via `ThemeData.extensions` |
| `SendsarScope(theme: SendsarChatTheme.dark.copyWith(...))` | Override tokens for a subtree |
| `SendsarConversationListStyle` | Header title, search hint, selection color |
| `SendsarMessageListStyle` | Bubble colors, radius, image height |
| `conversationItemBuilder` / `itemBuilder` | Custom conversation row (shell / list) |
| `messageBubbleBuilder` / `bubbleBuilder` | Custom message bubble (shell / list) |
| `SendsarConfig(animatedEmoji: false)` | Static emoji only |

```dart
SendsarChatShell(
  conversationListStyle: const SendsarConversationListStyle(
    headerTitle: 'Inbox',
  ),
  messageBubbleBuilder: (context, message, isSelf, defaultBubble) {
    return defaultBubble; // or wrap / replace
  },
)
```

## Repository layout

| Path | Purpose |
|------|---------|
| `sendsar_chat_uikit/` | Publishable package `sendsar_chat_uikit` |
| `example/` | Demo Flutter app |
| `sample-bff/` | Demo backend (session JWT + room helpers; CORS for Flutter web) |
| `scripts/setup.mjs` | Copies `sample-bff/.env.example` → `.env` |
| `scripts/use-local-sdk.mjs` | Local `sendsar_chat` path override for monorepo dev |

### `sample-bff` endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/chat/health` | Health check |
| `POST` | `/api/chat/session` | Mint session JWT |
| `POST` | `/api/chat/demo/ensure-dm` | Create or find a DM room |
| `POST` | `/api/chat/demo/ensure-group` | Create a group room |

Default port: **4400** (`sample-bff/.env`).

**Scripts:** `npm run setup` · `npm run start:bff` · `npm run start:flutter` · `npm start`

## Related

- [sendsar_chat](https://pub.dev/packages/sendsar_chat) — Flutter chat SDK
- [sendsar_chat_uikit](https://pub.dev/packages/sendsar_chat_uikit) — this package on pub.dev
- [sendsar-uikit-angular](https://github.com/Sendsar-Chat/sendsar-uikit-angular) — Angular UI kit (same BFF pattern)

## Publishing

See [PUBLISHING.md](PUBLISHING.md) for pub.dev OIDC setup, release tags (`sendsar_chat_uikit-v0.2.0`), and the pre-publish checklist.

## License

MIT — see [LICENSE](sendsar_chat_uikit/LICENSE).
