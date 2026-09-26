# Sendsar UI Kit Example

Demo Flutter app for [`sendsar_chat_uikit`](../sendsar_chat_uikit/).

## Run (web)

From the repo root (recommended):

```bash
npm install
npm run setup          # once — edit sample-bff/.env
npm run start:bff      # terminal 1 → http://localhost:4400
cd example && flutter pub get && flutter run -d chrome
```

Or use `npm start` from the repo root to run BFF + Flutter together.

## Run / build (mobile)

Platforms: `android/` and `ios/` (generated via `flutter create`).

### VS Code / Cursor (Run Without Debugging)

1. Start the BFF: `npm run start:bff` (or Terminal → Run Task → `start:bff`)
2. Start an Android emulator (or plug in a device)
3. Open the Run and Debug panel → pick **example (Android)**
4. Press **Ctrl+F5** (Run Without Debugging) or **F5** (with debugger)

Configs live in [`.vscode/launch.json`](../.vscode/launch.json).  
For a physical phone, edit **example (Android · device LAN)** and set your PC’s LAN IP.

### CLI

```bash
# terminal 1 — BFF
npm run start:bff

# terminal 2 — Android emulator (host loopback)
cd example
flutter pub get
flutter run -d android --dart-define=BFF_BASE_URL=http://10.0.2.2:4400

# or build an APK
flutter build apk --dart-define=BFF_BASE_URL=http://10.0.2.2:4400
# → build/app/outputs/flutter-apk/app-release.apk
```

Physical device: use your PC LAN IP instead of `10.0.2.2` (and ensure the BFF listens on `0.0.0.0`).

iOS (macOS only):

```bash
flutter run -d ios --dart-define=BFF_BASE_URL=http://127.0.0.1:4400
```

## What it demonstrates

1. Pick a demo user (Alice, Bob, etc.)
2. Use **DM** / **Create group** buttons (calls `sample-bff`)
3. Full chat shell: inbox, thread, composer, typing, presence, reactions

Session minting goes through `sample-bff/` — see [root README](../README.md) for the auth model.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BFF_BASE_URL` | `http://localhost:4400` | Sample backend URL (`--dart-define`) |

```bash
flutter run -d chrome --dart-define=BFF_BASE_URL=http://localhost:4400
```

## Key files

| File | Role |
|------|------|
| `lib/main.dart` | App shell, identity picker, `SendsarScope` + `SendsarChatShell` |
| `lib/demo_session_service.dart` | Calls BFF session + room endpoints |
| `lib/demo_environment.dart` | Demo users + BFF base URL |
