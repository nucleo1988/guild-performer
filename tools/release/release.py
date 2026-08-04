"""Package Guild Performer and upload to CurseForge (Class Performer release flow).

Usage:
    cd tools/release
    pip install -r requirements.txt

    # Configure credentials (copy release.env.example → release.env)
    python release.py                         # bump patch + zip + upload
    python release.py --dry-run               # zip only
    python release.py --version 1.3.0         # explicit version
    python release.py --release-type beta

Environment (or release.env in this folder):
    CF_API_TOKEN   — CurseForge author API token
    CF_PROJECT_ID  — 1635122 (Guild Performer)
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOOLS = Path(__file__).resolve().parent
ADDON_TOC = ROOT / "addon" / "GuildPerformer.toc"
CHANGELOG = ROOT / "CHANGELOG.md"
ENV_FILE = TOOLS / "release.env"
EXPORT_FORMAT = ROOT / "addon" / "ExportFormat.lua"

# Ensure local imports work when run as a script.
sys.path.insert(0, str(TOOLS))


def load_env_file() -> None:
    if not ENV_FILE.is_file():
        return
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key, val = key.strip(), val.strip().strip('"').strip("'")
        os.environ.setdefault(key, val)


def read_addon_version_constant() -> str | None:
    if not EXPORT_FORMAT.is_file():
        return None
    m = re.search(r'ADDON_VERSION\s*=\s*"([^"]+)"', EXPORT_FORMAT.read_text(encoding="utf-8"))
    return m.group(1) if m else None


def set_addon_version_constant(version: str) -> None:
    if not EXPORT_FORMAT.is_file():
        return
    text = EXPORT_FORMAT.read_text(encoding="utf-8")
    new_text, n = re.subn(
        r'(ADDON_VERSION\s*=\s*")[^"]+(")',
        rf"\g<1>{version}\2",
        text,
        count=1,
    )
    if n == 1:
        EXPORT_FORMAT.write_text(new_text, encoding="utf-8")


def default_changelog(version: str) -> str:
    today = date.today().isoformat()
    if CHANGELOG.is_file():
        text = CHANGELOG.read_text(encoding="utf-8")
        # Prefer matching section
        m = re.search(
            rf"## \[{re.escape(version)}\][^\n]*\n(.*?)(?=\n## |\Z)",
            text,
            re.S,
        )
        if m:
            body = m.group(1).strip()
            if body:
                return f"## GuildPerformer {version} ({today})\n\n{body}\n"
        # Fall back to Unreleased
        m = re.search(r"## \[Unreleased\]\s*\n(.*?)(?=\n## |\Z)", text, re.S)
        if m and m.group(1).strip():
            return f"## GuildPerformer {version} ({today})\n\n{m.group(1).strip()}\n"
    return (
        f"## GuildPerformer {version} ({today})\n\n"
        f"- Guild roster sync with RaidRoster Companion (pull/push).\n"
        f"- Guild tab, calendar events, roster tools.\n"
    )


def validate_addon() -> None:
    required = [
        ADDON_TOC,
        ROOT / "addon" / "Core.lua",
        ROOT / "addon" / "GuildPerformer_Data.lua",
        ROOT / "addon" / "UI" / "MainWindow.lua",
        ROOT / "addon" / "UI" / "GuildView.lua",
    ]
    for path in required:
        if not path.is_file():
            raise FileNotFoundError(f"Missing required file: {path}")
    data = (ROOT / "addon" / "GuildPerformer_Data.lua").read_text(encoding="utf-8")
    if "players" in data.lower() and "GuildPerformerDB_Import =" in data and "nil" not in data.split("GuildPerformerDB_Import", 1)[-1][:80]:
        # soft check — stub must remain nil for public releases
        if re.search(r"GuildPerformerDB_Import\s*=\s*\{", data):
            raise ValueError("GuildPerformer_Data.lua contains roster payload; ship stub only")


def main() -> int:
    load_env_file()

    ap = argparse.ArgumentParser(description="Package and upload GuildPerformer to CurseForge.")
    ap.add_argument("--version", help="Set addon version explicitly (default: bump patch / ADDON_VERSION)")
    ap.add_argument("--release-type", choices=["alpha", "beta", "release"], default="release")
    ap.add_argument("--changelog", help="Custom changelog text (markdown)")
    ap.add_argument("--dry-run", action="store_true", help="Build zip but do not upload")
    ap.add_argument("--no-upload", action="store_true", help="Same as --dry-run")
    ap.add_argument("--keep-toc-placeholder", action="store_true",
                    help="Leave @project-version@ in source TOC (zip still gets real version)")
    args = ap.parse_args()

    from curseforge import (
        CurseForgeClient,
        bump_patch_version,
        parse_toc_interfaces,
        parse_toc_project_id,
        parse_toc_version,
        set_toc_version,
    )
    from packager import build_zip

    print(">> Validating addon...", flush=True)
    validate_addon()

    old_version = parse_toc_version(ADDON_TOC)
    const_version = read_addon_version_constant()
    will_upload = not (args.dry_run or args.no_upload)

    if args.version:
        version = args.version
    elif old_version.startswith("@") and const_version:
        version = const_version
    elif will_upload and not old_version.startswith("@"):
        version = bump_patch_version(old_version)
    elif const_version:
        version = const_version
    else:
        version = bump_patch_version(old_version if not old_version.startswith("@") else "1.0.0")

    print(f">> Version: {old_version} -> {version}", flush=True)
    set_addon_version_constant(version)
    if not args.keep_toc_placeholder:
        # Keep packager-friendly placeholder in git; numeric version goes into the zip only
        # unless uploading a tagged release and user wants TOC updated.
        if not old_version.startswith("@"):
            set_toc_version(ADDON_TOC, version)

    print("\n>> Building zip...", flush=True)
    zip_path = build_zip(version)
    print(f"   {zip_path} ({zip_path.stat().st_size // 1024} KB)", flush=True)

    if args.dry_run or args.no_upload:
        print("\nDry run — upload skipped.")
        return 0

    token = os.environ.get("CF_API_TOKEN", "").strip()
    project_id = os.environ.get("CF_PROJECT_ID", "").strip()
    if not project_id:
        toc_id = parse_toc_project_id(ADDON_TOC)
        if toc_id:
            project_id = str(toc_id)
    if not token or not project_id:
        print(
            "\nUpload skipped: set CF_API_TOKEN and CF_PROJECT_ID in tools/release/release.env "
            "(see release.env.example).\n"
            f"Zip ready at: {zip_path}",
            file=sys.stderr,
        )
        return 1

    # Resolve game versions from staged TOC content inside zip's source addon
    # Use Interface.version + current TOC interfaces after prepare — re-read addon TOC Interface line
    interfaces = parse_toc_interfaces(ADDON_TOC)
    if not interfaces:
        iface_file = ROOT / "addon" / "Interface.version"
        if iface_file.is_file():
            interfaces = [int(iface_file.read_text(encoding="utf-8").strip())]
    if not interfaces:
        raise RuntimeError("No ## Interface values found for GuildPerformer")

    changelog = args.changelog or default_changelog(version)
    client = CurseForgeClient(token, int(project_id))
    print("\n>> Resolving CurseForge game versions...", flush=True)
    game_ids = client.game_version_ids(interfaces)
    print(f"   Interface {interfaces} -> CF ids {game_ids}", flush=True)

    print("\n>> Uploading to CurseForge...", flush=True)
    file_id = client.upload(
        zip_path,
        changelog=changelog,
        game_version_ids=game_ids,
        release_type=args.release_type,
        display_name=f"GuildPerformer {version}",
        changelog_type="markdown",
    )
    print(f"\nDone. CurseForge file ID: {file_id}")
    print(f"https://www.curseforge.com/wow/addons/guild-performer/files/{file_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
