# Publishing `sendsar_chat_uikit`

Publish from **`Sendsar-Chat/sendsar-uikit-flutter`** to **pub.dev** via **OIDC** (no upload tokens). This repo ships the full package source on GitHub and pub.dev.

| Output | Location |
|--------|----------|
| pub.dev | [`sendsar_chat_uikit`](https://pub.dev/packages/sendsar_chat_uikit) |
| GitHub | [github.com/Sendsar-Chat/sendsar-uikit-flutter](https://github.com/Sendsar-Chat/sendsar-uikit-flutter) (`sendsar_chat_uikit/`) |

Workflow: [`.github/workflows/publish.yml`](.github/workflows/publish.yml)

Docs: [Automated publishing on pub.dev](https://dart.dev/tools/pub/automated-publishing)

**Dependency:** `sendsar_chat` must be a **hosted** dependency in `sendsar_chat_uikit/pubspec.yaml` (not `path:`). Use `npm run use:local-sdk` only for local monorepo development.

---

## One-time setup

### 1. pub.dev publisher + first manual publish

```bash
cd sendsar_chat_uikit
flutter pub get && flutter test
dart pub publish   # interactive — creates the package on pub.dev (once)
```

### 2. Enable OIDC on pub.dev (required for CI)

1. [pub.dev/packages/sendsar_chat_uikit/admin](https://pub.dev/packages/sendsar_chat_uikit/admin)
2. **Automated publishing** → **Enable publishing from GitHub Actions**
3. Configure:

| Field | Value |
|-------|--------|
| Repository | `Sendsar-Chat/sendsar-uikit-flutter` |
| Tag pattern | `sendsar_chat_uikit-v{{version}}` |

4. Save

CI uses `dart-lang/setup-dart@v1` which provisions **`PUB_TOKEN`** via OIDC.

---

## Release (every version)

**pub.dev only accepts OIDC when the workflow is triggered by a matching git tag push.**

1. Bump `version` in `sendsar_chat_uikit/pubspec.yaml` (must match the tag)
2. Update `sendsar_chat_uikit/CHANGELOG.md` (and root `CHANGELOG.md` for repo releases)
3. Commit and push to `main`
4. **Push the tag**:

```bash
VERSION=0.2.0   # must match pubspec.yaml
git tag "sendsar_chat_uikit-v${VERSION}"
git push origin "sendsar_chat_uikit-v${VERSION}"
```

5. Workflow will:
   - `flutter test` in `sendsar_chat_uikit/`
   - `dart pub publish --dry-run`
   - `dart pub publish --force` (OIDC via `PUB_TOKEN`, skips if version already exists)

---

## Pre-publish checklist

```bash
cd sendsar_chat_uikit
flutter pub get
flutter test
dart pub publish --dry-run
```

| Check | Requirement |
|-------|-------------|
| `sendsar_chat` dependency | Hosted (`^0.1.0`), not `path:` |
| `CHANGELOG.md` | Present in `sendsar_chat_uikit/` |
| `LICENSE` | Present in `sendsar_chat_uikit/` |
| `README.md` | Present in `sendsar_chat_uikit/` |
| Version | Matches git tag |
| `sendsar_chat` on pub.dev | Published version satisfies constraint |

---

## Local development

**Default (pub.dev SDK):**

```bash
cd sendsar_chat_uikit && flutter pub get
```

**Monorepo SDK checkout** (`../sendsar-monorepo`):

```bash
npm run use:local-sdk
cd sendsar_chat_uikit && flutter pub get
cd ../example && flutter pub get
```

Revert to pub.dev:

```bash
npm run use:pub-sdk
```

---

## Verify

```bash
curl -s https://pub.dev/api/packages/sendsar_chat_uikit | jq -r '.latest.version'
```

On pub.dev → package **Admin** → **Audit log** — a successful OIDC publish links to the GitHub Actions run.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Don't depend on sendsar_chat from the path source` | Use hosted dep in `pubspec.yaml`; local path only via `pubspec_overrides.yaml` |
| `Please add a CHANGELOG.md` | Add/update `sendsar_chat_uikit/CHANGELOG.md` |
| `No pub.dev credentials` | Push the git tag; enable OIDC on pub.dev admin |
| `publishing is only allowed from tag` | Tag must be `sendsar_chat_uikit-v<version>` matching `pubspec.yaml` |
| `version already exists` | Bump `pubspec.yaml` and push a new tag |
