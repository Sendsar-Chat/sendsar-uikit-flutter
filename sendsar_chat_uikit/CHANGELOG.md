## 0.3.0

### Features
- Voice/video calls — parity with sendsar-uikit-angular, built on `sendsar_chat` 0.2.0 + `sendsar_call` 0.2.0 (LiveKit):
  - `SendsarCallService` (registered by `SendsarScope`): call state, early-invite buffering, mic/camera/speaker toggles, live duration timer.
  - `SendsarCallOverlay`: incoming/outgoing ring, active call with remote video + local PiP (`VideoTrackRenderer`), minimized chip, controls, error text.
  - Synthesized call tones (ringback, ringtone, end beep) via `audioplayers` — no bundled assets.
  - `SendsarCallLogBubble` + call-log (`data-call`) rows in the message list with tap-to-redial; viewer-aware call previews in inbox/thread (`formatCallLogPreview`).
  - Shell header voice/video call buttons wired.
  - Mobile-first call UX: on narrow layouts the shell pushes `SendsarCallScreen` as a full-screen page (system back minimizes, never hangs up) and shows a Telegram-style `SendsarOngoingCallBar` while the call runs in the background; wide layouts keep the floating `SendsarCallOverlay` card.

### UX
- Conversation list stays fresh in realtime: rows use the latest `new-message` event (preview + timestamp, including call logs) when the server room list is stale, and the sidebar reloads after a call ends.

### Breaking
- Requires Dart `^3.6.0` / Flutter `>=3.27.0`; `sendsar_chat` `^0.2.0` and new `sendsar_call` `^0.2.0` dependencies.
- `messagePreview` gained an optional `selfUserId` named parameter (viewer-specific call previews).

## 0.2.1

### UX
- Message list caches threads in memory when switching conversations (no loading flash on revisit).
- Uses `createRoomSubscription` `nextCursor` — one history fetch per open (requires `sendsar_chat` ≥ 0.1.3).

## 0.2.0

### Features
- `SendsarChatTheme` light/dark tokens (follows `MaterialApp` brightness).
- Unread badges on conversation rows.
- `cached_network_image` for attachment previews.
- Noto animated emoji in message bubbles (`animatedEmoji` on `SendsarConfig`).
- Customization: `SendsarConversationListStyle`, `SendsarMessageListStyle`, `itemBuilder` / `conversationItemBuilder`, `bubbleBuilder` / `messageBubbleBuilder`.
- Mobile room details bottom sheet.

### UX
- Composer: bordered input box, toolbar row (emoji + attach + send aligned).
- Messages: Telegram-style long-press action sheet for react / edit / delete.
- Read receipts inside message bubbles; reaction pills only when reactions exist.

### Tests
- Utils tests for format time, room labels, emoji segments, Noto URLs.

## 0.1.0

- Initial release: `SendsarScope`, session/chat services, and chat shell widgets mirroring sendsar-uikit-angular.
