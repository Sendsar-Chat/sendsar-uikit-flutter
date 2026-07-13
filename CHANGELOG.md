## 0.2.0

### Features
- `SendsarChatTheme` light/dark tokens (follows `MaterialApp` brightness).
- Unread badges on conversation rows.
- `cached_network_image` for attachment previews.
- Noto animated emoji in message bubbles (`animatedEmoji` on `SendsarConfig`).
- Customization: `SendsarConversationListStyle`, `SendsarMessageListStyle`, `itemBuilder` / `conversationItemBuilder`, `bubbleBuilder` / `messageBubbleBuilder`.
- Mobile room details bottom sheet.
- Local `sample-bff/` with CORS for Flutter web (no Angular checkout required).

### UX
- Composer: bordered input box, toolbar row (emoji + attach + send aligned).
- Messages: Telegram-style long-press action sheet for react / edit / delete.
- Read receipts inside message bubbles; reaction pills only when reactions exist.

### Tests
- Utils tests for format time, room labels, emoji segments, Noto URLs.

## 0.1.0

- Initial release: `SendsarScope`, session/chat services, and chat shell widgets mirroring sendsar-uikit-angular.
