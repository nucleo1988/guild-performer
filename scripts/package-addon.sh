#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-${GITHUB_REF_NAME:-dev}}"
VERSION="${VERSION#v}"

DIST="$ROOT/dist"
STAGE="$DIST/GuildPerformer"
ZIP="$DIST/GuildPerformer-${VERSION}.zip"

rm -rf "$DIST"
mkdir -p "$STAGE"

IFACE="$(tr -d '[:space:]' < "$ROOT/addon/Interface.version")"
TOC="$ROOT/addon/GuildPerformer.toc"
TMP_TOC="$(mktemp)"
sed "s/^## Interface:.*/## Interface: ${IFACE}/" "$TOC" | sed "s/@project-version@/${VERSION}/g" > "$TMP_TOC"

# Copy without rsync (portable)
cp -R "$ROOT/addon/." "$STAGE/"
rm -f "$STAGE/Interface.version"
cp "$TMP_TOC" "$STAGE/GuildPerformer.toc"
rm -f "$TMP_TOC"

rm -rf "$STAGE/.git" 2>/dev/null || true

(
  cd "$DIST"
  if command -v zip >/dev/null 2>&1; then
    zip -r "GuildPerformer-${VERSION}.zip" GuildPerformer >/dev/null
  else
    # Git Bash / Windows without zip: use PowerShell as fallback
    powershell.exe -NoProfile -Command "Compress-Archive -Path 'GuildPerformer' -DestinationPath 'GuildPerformer-${VERSION}.zip' -Force"
  fi
)

echo "Built $ZIP"
ls -la "$ZIP" 2>/dev/null || ls -la "$DIST"
