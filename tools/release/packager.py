"""Build a CurseForge-ready GuildPerformer zip (GuildPerformer/ at zip root)."""
from __future__ import annotations

import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ADDON_DIR = ROOT / "addon"
DIST_DIR = ROOT / "dist"

EXCLUDE_NAMES = {
    "Interface.version",
    "Thumbs.db",
    ".DS_Store",
    ".gitkeep",
    "GuildPerformer_Data.local.lua",
}

EXCLUDE_SUFFIXES = (".bak", ".local.lua")


def _prepare_toc(src_toc: Path, version: str, interface: str) -> str:
    text = src_toc.read_text(encoding="utf-8")
    text = re.sub(r"(## Interface:\s*)\S+", rf"\g<1>{interface}", text, count=1)
    text = text.replace("@project-version@", version)
    text, n = re.subn(r"(## Version:\s*)\S+", rf"\g<1>{version}", text, count=1)
    if n != 1:
        raise ValueError(f"Could not set ## Version in {src_toc}")
    return text


def build_zip(version: str, out_dir: Path | None = None) -> Path:
    """Create dist/GuildPerformer-{version}.zip with GuildPerformer/ at the root."""
    if not ADDON_DIR.is_dir():
        raise FileNotFoundError(f"Addon folder not found: {ADDON_DIR}")

    out_dir = out_dir or DIST_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / f"GuildPerformer-{version}.zip"
    if zip_path.exists():
        zip_path.unlink()

    staging_root = out_dir / "_staging"
    staging = staging_root / "GuildPerformer"
    if staging_root.exists():
        shutil.rmtree(staging_root)
    staging.mkdir(parents=True)

    iface_file = ADDON_DIR / "Interface.version"
    interface = iface_file.read_text(encoding="utf-8").strip() if iface_file.is_file() else "120007"

    for path in ADDON_DIR.rglob("*"):
        if path.is_dir():
            continue
        if path.name in EXCLUDE_NAMES:
            continue
        if path.name.endswith(EXCLUDE_SUFFIXES):
            continue
        rel = path.relative_to(ADDON_DIR)
        dest = staging / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if path.name == "GuildPerformer.toc":
            dest.write_text(_prepare_toc(path, version, interface), encoding="utf-8")
        elif path.name == "GuildPerformer_Data.lua":
            dest.write_text(
                "-- Guild Performer sync data stub.\n"
                "-- Overwritten by Companion / syncer locally.\n"
                "GuildPerformerDB_Import = nil\n",
                encoding="utf-8",
            )
        else:
            shutil.copy2(path, dest)

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in staging.rglob("*"):
            if path.is_dir():
                continue
            arc = path.relative_to(staging_root)
            zf.write(path, arc.as_posix())

    shutil.rmtree(staging_root)
    return zip_path
