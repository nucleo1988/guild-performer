"""CurseForge author Upload API helpers for WoW addons.

Same client used by Class Performer (performer/scraper/curseforge.py).
Docs: https://support.curseforge.com/en/support/solutions/articles/9000197321-curseforge-upload-api
Token: https://authors.curseforge.com/ (Account → API Tokens)
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import requests

CF_WOW_API = "https://wow.curseforge.com/api"


def interface_to_game_version(interface: int) -> str:
    """Convert a WoW ## Interface number to a game version string (e.g. 120007 -> 12.0.7)."""
    return f"{interface // 10000}.{(interface // 100) % 100}.{interface % 100}"


def parse_toc_interfaces(toc_path: Path) -> list[int]:
    text = toc_path.read_text(encoding="utf-8")
    m = re.search(r"## Interface:\s*([^\n]+)", text)
    if not m:
        return []
    return [int(x.strip()) for x in m.group(1).split(",") if x.strip().isdigit()]


def parse_toc_version(toc_path: Path) -> str:
    text = toc_path.read_text(encoding="utf-8")
    m = re.search(r"## Version:\s*(\S+)", text)
    if not m:
        raise ValueError(f"No ## Version line in {toc_path}")
    return m.group(1).strip()


def parse_toc_project_id(toc_path: Path) -> int | None:
    text = toc_path.read_text(encoding="utf-8")
    m = re.search(r"## X-Curse-Project-ID:\s*(\d+)", text)
    return int(m.group(1)) if m else None


def set_toc_version(toc_path: Path, version: str) -> None:
    text = toc_path.read_text(encoding="utf-8")
    new_text, n = re.subn(r"(## Version:\s*)\S+", rf"\g<1>{version}", text, count=1)
    if n != 1:
        raise ValueError(f"Could not update ## Version in {toc_path}")
    toc_path.write_text(new_text, encoding="utf-8")


def bump_patch_version(version: str) -> str:
    # Ignore packager placeholders like @project-version@
    if version.startswith("@") and version.endswith("@"):
        return "1.0.0"
    parts = version.split(".")
    if len(parts) >= 3 and parts[-1].isdigit():
        parts[-1] = str(int(parts[-1]) + 1)
        return ".".join(parts)
    if len(parts) == 2 and parts[-1].isdigit():
        return f"{version}.1"
    # strip -dev / -beta suffixes for bump base
    base = re.sub(r"[-+].*$", "", version)
    parts = base.split(".")
    if len(parts) >= 3 and parts[-1].isdigit():
        parts[-1] = str(int(parts[-1]) + 1)
        return ".".join(parts)
    return f"{base}.1"


class CurseForgeClient:
    def __init__(self, api_token: str, project_id: int):
        self.api_token = api_token
        self.project_id = int(project_id)
        self._headers = {"X-Api-Token": api_token, "Accept": "application/json"}

    def _get(self, path: str) -> list | dict:
        url = f"{CF_WOW_API}{path}"
        resp = requests.get(url, headers=self._headers, timeout=60)
        resp.raise_for_status()
        return resp.json()

    def game_version_ids(self, interface_numbers: list[int]) -> list[int]:
        """Resolve CurseForge game-version IDs from WoW Interface numbers."""
        versions = self._get("/game/versions")
        by_name = {v["name"]: v["id"] for v in versions}
        ids: list[int] = []
        missing: list[str] = []
        for iface in interface_numbers:
            name = interface_to_game_version(iface)
            vid = by_name.get(name)
            if vid:
                ids.append(vid)
            else:
                missing.append(name)
        if missing:
            known = ", ".join(sorted(by_name.keys())[-8:])
            raise RuntimeError(
                f"CurseForge has no game version for: {', '.join(missing)}. "
                f"Recent API names include: {known}"
            )
        return ids

    def upload(
        self,
        zip_path: Path,
        *,
        changelog: str,
        game_version_ids: list[int],
        release_type: str = "release",
        display_name: str | None = None,
        changelog_type: str = "markdown",
    ) -> int:
        """Upload an addon zip. Returns the new CurseForge file ID."""
        metadata = {
            "changelog": changelog,
            "changelogType": changelog_type,
            "releaseType": release_type,
            "gameVersions": game_version_ids,
        }
        if display_name:
            metadata["displayName"] = display_name

        url = f"{CF_WOW_API}/projects/{self.project_id}/upload-file"
        with zip_path.open("rb") as fh:
            resp = requests.post(
                url,
                headers={"X-Api-Token": self.api_token},
                data={"metadata": json.dumps(metadata)},
                files={"file": (zip_path.name, fh, "application/zip")},
                timeout=300,
            )

        if resp.status_code != 200:
            raise RuntimeError(
                f"CurseForge upload failed (HTTP {resp.status_code}): {resp.text[:800]}"
            )

        data = resp.json()
        file_id = data.get("id")
        if not file_id:
            raise RuntimeError(f"Unexpected CurseForge response: {data}")
        return int(file_id)
