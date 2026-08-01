"""Core sync logic shared by GUI and CLI (--sync)."""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

DEFAULT_WOW_PATHS = [
    r"C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\GuildPerformer",
    r"C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\GuildPerformer",
    r"D:\World of Warcraft\_retail_\Interface\AddOns\GuildPerformer",
    r"E:\World of Warcraft\_retail_\Interface\AddOns\GuildPerformer",
]


@dataclass
class SyncConfig:
    url: str = ""
    addon_path: str = ""
    format: str = "lua"
    auto_minutes: int = 30
    auto_enabled: bool = False
    start_with_windows: bool = False

    @classmethod
    def load(cls, path: Path) -> "SyncConfig":
        if not path.is_file():
            return cls()
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(
            url=str(data.get("url") or ""),
            addon_path=str(data.get("addonPath") or data.get("addon_path") or ""),
            format=str(data.get("format") or "lua"),
            auto_minutes=int(data.get("autoMinutes") or data.get("auto_minutes") or 30),
            auto_enabled=bool(data.get("autoEnabled") or data.get("auto_enabled") or False),
            start_with_windows=bool(
                data.get("startWithWindows") or data.get("start_with_windows") or False
            ),
        )

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "url": self.url.strip(),
                    "addonPath": self.addon_path.strip(),
                    "format": self.format or "lua",
                    "autoMinutes": max(5, int(self.auto_minutes or 30)),
                    "autoEnabled": bool(self.auto_enabled),
                    "startWithWindows": bool(self.start_with_windows),
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )


@dataclass
class SyncResult:
    ok: bool
    message: str
    status_code: int = 0
    bytes_written: int = 0
    guild_id: str = ""
    player_count: str = ""


def config_dir() -> Path:
    base = Path(os.environ.get("APPDATA") or Path.home())
    return base / "GuildPerformerSync"


def config_path() -> Path:
    return config_dir() / "config.json"


def etag_path() -> Path:
    return config_dir() / "last-etag.txt"


def detect_addon_path() -> Optional[str]:
    for p in DEFAULT_WOW_PATHS:
        if Path(p).is_dir() and (Path(p) / "GuildPerformer.toc").is_file():
            return p
    # Broad search under common Program Files roots (shallow)
    roots = [
        Path(r"C:\Program Files (x86)"),
        Path(r"C:\Program Files"),
        Path(r"D:\\"),
    ]
    for root in roots:
        if not root.exists():
            continue
        for candidate in root.glob("**/GuildPerformer/GuildPerformer.toc"):
            return str(candidate.parent)
    return None


def ensure_format_query(url: str, fmt: str = "lua") -> str:
    if re.search(r"[?&]format=", url, re.I):
        return url
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}format={fmt}"


def run_sync(cfg: SyncConfig, force: bool = False) -> SyncResult:
    url = (cfg.url or "").strip()
    addon = (cfg.addon_path or "").strip()
    if not url:
        return SyncResult(False, "Incolla l'URL sync della gilda (dal sito RaidRoster > Config).")
    if "gp_" not in url:
        return SyncResult(False, "URL non valido: deve contenere il token gp_… della tua gilda.")
    if not addon:
        return SyncResult(False, "Seleziona la cartella AddOns\\GuildPerformer.")
    addon_path = Path(addon)
    if not addon_path.is_dir():
        return SyncResult(False, f"Cartella addon non trovata:\n{addon}")

    out_file = addon_path / "GuildPerformer_Data.lua"
    fetch_url = ensure_format_query(url, cfg.format or "lua")

    headers = {
        "User-Agent": "GuildPerformerSync/1.1",
        "Accept": "text/plain",
    }
    etag_file = etag_path()
    if not force and etag_file.is_file():
        prev = etag_file.read_text(encoding="utf-8").strip()
        if prev:
            headers["If-None-Match"] = prev

    req = Request(fetch_url, headers=headers, method="GET")
    try:
        with urlopen(req, timeout=60) as resp:
            status = getattr(resp, "status", 200) or 200
            body = resp.read()
            etag = resp.headers.get("ETag") or resp.headers.get("X-Content-Hash") or ""
            guild_id = resp.headers.get("X-Guild-Id") or ""
            players = resp.headers.get("X-Player-Count") or ""
    except HTTPError as e:
        if e.code == 304:
            return SyncResult(True, "Nessuna novità: roster già aggiornato.", status_code=304)
        if e.code == 401:
            return SyncResult(False, "Token non valido o revocato. Genera un nuovo URL sul sito.", status_code=401)
        return SyncResult(False, f"Errore HTTP {e.code}: {e.reason}", status_code=e.code)
    except URLError as e:
        return SyncResult(False, f"Connessione fallita: {e.reason}")
    except Exception as e:  # noqa: BLE001
        return SyncResult(False, f"Errore: {e}")

    text = body.decode("utf-8", errors="replace")
    if "GuildPerformerDB_Import" not in text:
        return SyncResult(False, "Risposta del server non riconosciuta (non è un dump Guild Performer).")

    from datetime import datetime, timezone

    header = (
        f"-- Auto-generated by Guild Performer Sync {datetime.now(timezone.utc).isoformat()}\n"
        "-- Do not edit by hand. Run Sync again to refresh.\n"
    )
    out_file.write_text(header + text, encoding="utf-8")
    config_dir().mkdir(parents=True, exist_ok=True)
    if etag:
        etag_file.write_text(etag, encoding="utf-8")

    extra = ""
    if guild_id or players:
        extra = f" (gilda #{guild_id}, {players} giocatori)" if guild_id else f" ({players} giocatori)"
    return SyncResult(
        True,
        f"Roster aggiornato.{extra}\nIn WoW digita: /reload   oppure   /gp sync",
        status_code=status,
        bytes_written=len(body),
        guild_id=guild_id,
        player_count=players,
    )
