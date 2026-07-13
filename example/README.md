# Sendsar UI Kit Example

Demo Flutter app for [`sendsar_chat_uikit`](../sendsar_chat_uikit/).

## Run

From the repo root (recommended):

```bash
npm install
npm run setup          # once — edit sample-bff/.env
npm run start:bff      # terminal 1 → http://localhost:4400
cd example && flutter pub get && flutter run -d chrome
```

Or use `npm start` from the repo root to run BFF + Flutter together.

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
