#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADDON="$ROOT/addon"
ERR=0

fail() { echo "ERROR: $*"; ERR=1; }
ok() { echo "OK: $*"; }

[[ -f "$ADDON/GuildPerformer.toc" ]] || fail "Missing GuildPerformer.toc"
[[ -f "$ADDON/Interface.version" ]] || fail "Missing Interface.version"

IFACE="$(tr -d '[:space:]' < "$ADDON/Interface.version")"
TOC_IFACE="$(grep -E '^## Interface:' "$ADDON/GuildPerformer.toc" | head -1 | awk '{print $3}')"
[[ "$IFACE" == "$TOC_IFACE" ]] || fail "Interface mismatch: Interface.version=$IFACE toc=$TOC_IFACE"
ok "Interface $IFACE"

REQUIRED=(
  Core.lua Database.lua Import.lua SyncData.lua GuildPerformer_Data.lua ExportFormat.lua
  Theme.lua Widgets.lua Minimap.lua
  Roster.lua GroupBuilder.lua
  UI/MainWindow.lua UI/Dashboard.lua UI/RosterView.lua UI/ImportView.lua UI/Settings.lua
  Locales/enUS.lua Locales/itIT.lua
)
for f in "${REQUIRED[@]}"; do
  [[ -f "$ADDON/$f" ]] || fail "Missing $f"
done
ok "Required Lua modules present"

# Basic Lua syntax if luac available
if command -v luac >/dev/null 2>&1; then
  while IFS= read -r -d '' file; do
    if ! luac -p "$file" 2>/dev/null; then
      fail "Lua syntax: $file"
    fi
  done < <(find "$ADDON" -name '*.lua' -print0)
  ok "luac syntax check"
else
  echo "WARN: luac not installed; skipping syntax parse"
fi

# Reject secrets patterns in addon
if grep -RInE 'CF_API_TOKEN|api[_-]?key\s*=\s*['\''\"][A-Za-z0-9]{16,}' "$ADDON" >/dev/null 2>&1; then
  fail "Possible secret in addon sources"
else
  ok "No obvious secrets in addon"
fi

[[ $ERR -eq 0 ]] || exit 1
echo "Validation passed."
