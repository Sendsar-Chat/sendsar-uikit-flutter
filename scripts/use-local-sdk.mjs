/**
 * Point sendsar_chat_uikit + example at a local sendsar-monorepo SDK checkout.
 * Removes overrides when SENDSAR_USE_LOCAL_SDK=0.
 */
import { copyFileSync, existsSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const targets = [
  join(root, "sendsar_chat_uikit"),
  join(root, "example"),
];

const disable = process.argv.includes("--pub") || process.env.SENDSAR_USE_LOCAL_SDK === "0";

for (const dir of targets) {
  const overridePath = join(dir, "pubspec_overrides.yaml");
  if (disable) {
    if (existsSync(overridePath)) {
      rmSync(overridePath);
      console.log(`Removed ${overridePath}`);
    }
    continue;
  }

  const example = join(dir, "pubspec_overrides.yaml.example");
  if (!existsSync(example)) {
    console.warn(`Skip ${dir} — no pubspec_overrides.yaml.example`);
    continue;
  }
  copyFileSync(example, overridePath);
  console.log(`Wrote ${overridePath}`);
}

if (disable) {
  console.log("Using pub.dev sendsar_chat.");
} else {
  console.log("Using local sendsar_chat from sendsar-monorepo.");
  console.log("Run: cd sendsar_chat_uikit && flutter pub get");
}
