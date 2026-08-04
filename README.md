# Guild Performer

Import guild raid roster data from [RaidRoster](https://github.com/nucleo1988) into World of Warcraft and review it in-game.

CurseForge project ID: **1635122**

## Screenshots

_Place screenshots here:_

- `docs/screenshots/dashboard.png`
- `docs/screenshots/roster.png`
- `docs/screenshots/import.png`

## Features

- Paste-string import (`GPv1;…`) from the RaidRoster **Export Guild Performer** tool
- **RaidRoster Companion** / desktop **syncer** for roster pull/push without a new CurseForge release
- Guild tab (ilvl / roles / Raider.IO), Events calendar, roster tools
- Dashboard with role counts, Day One / deferred launch, critical notes
- Filterable roster (role, class, status, search) with class colors
- Group builder with suggestions, utility gaps, and saved templates
- Replace / merge import, backup + undo
- Slash commands, minimap button, SavedVariables
- Italian and English locales

## Manual install

1. Download the latest `GuildPerformer-*.zip` from [Releases](https://github.com/nucleo1988/guild-performer/releases) or CurseForge.
2. Extract so you have:
   `World of Warcraft\_retail_\Interface\AddOns\GuildPerformer\`
3. Ensure `GuildPerformer.toc` is directly inside that folder.
4. Restart WoW or `/reload`.

## Web export (RaidRoster)

In the guild panel → **Analisi** → **Guild Performer**:

1. Filter / select players.
2. **Copia tutti** or **Copia selezionati** (or download `.txt` / `.lua`).
3. In-game: `/gp import` → paste → Preview → Replace or Merge.

Shared format docs: [`web/shared/FORMAT.md`](web/shared/FORMAT.md)

## Slash commands

| Command | Action |
|---------|--------|
| `/guildperformer` or `/gp` | Toggle main window |
| `/gp import` | Open Import tab |
| `/gp roster` | Open Roster |
| `/gp settings` | Open Settings |
| `/gp reset` | Reset window position |
| `/gp sync` | Apply `GuildPerformer_Data.lua` from the desktop syncer |

## Automated roster sync (Windows app)

For non-technical officers, use the **Guild Performer Sync** installer from [Releases](https://github.com/nucleo1988/guild-performer/releases):

1. RaidRoster guild Config → generate **export token URL** (per guild) → Copy URL.
2. Install/open **Guild Performer Sync** → Paste URL → Find addon folder → **Sync now**.
3. In-game `/reload` or `/gp sync`.

Details: [`syncer/README.md`](syncer/README.md). Advanced users can still use `syncer/Sync-GuildPerformer.ps1`.

Roster data is **never** bundled in CurseForge zips; only addon code is released.

## Configuration

- Minimap button: Settings tab or `GuildPerformerDB.settings.showMinimap`
- Window position is saved automatically
- Profiles: account-wide SavedVariables (`GuildPerformerDB`)

## Repository layout

```text
guild-performer/
├── addon/                 # WoW addon sources (packaged as GuildPerformer/)
├── tools/release/         # Class Performer–style CurseForge upload (Python)
├── web/shared/            # Shared format documentation
├── scripts/               # Package + validate helpers
├── .github/workflows/     # CI validate + CurseForge release
├── release.bat            # Windows shortcut → tools/release/release.py
├── CHANGELOG.md
├── README.md
├── LICENSE
└── .pkgmeta
```

## Development

1. Clone this repo.
2. Symlink or copy `addon/` → `Interface/AddOns/GuildPerformer`.
3. Edit Lua files; `/reload` in-game.
4. Keep `## Interface:` in sync with retail (see `addon/Interface.version`).

The export encoder lives in the RaidRoster app (`GuildPerformerExportService`). Keep `FORMAT_VERSION` aligned with `addon/ExportFormat.lua` (`ns.FORMAT_VERSION`).

## Build

```bash
./scripts/package-addon.sh 1.0.0
```

Produces `dist/GuildPerformer-1.0.0.zip` with root folder `GuildPerformer/`.

```bash
./scripts/validate-release.sh
```

Checks TOC, Interface version, and required Lua modules.

## Release & CurseForge

Same author Upload API flow as **Class Performer** (`performer/scraper/release.py`).

### Local (recommended)

1. Copy `tools/release/release.env.example` → `tools/release/release.env`
2. Set `CF_API_TOKEN` (from [authors.curseforge.com](https://authors.curseforge.com/)) and `CF_PROJECT_ID=1635122`
3. Run:

```bash
cd tools/release
pip install -r requirements.txt
python release.py --version 1.3.0          # package + upload
python release.py --version 1.3.0 --dry-run
# or from repo root:
release.bat --version 1.3.0
```

### GitHub Actions (tag)

1. Add GitHub secret **`CF_API_TOKEN`**.
2. Push a version tag (`v1.3.0`, `v1.3.0-beta.1`, …).
3. Workflow `.github/workflows/release.yml` validates, creates a GitHub Release, and uploads via the same Python CurseForge client (project `1635122`).

Never commit `release.env` / tokens. Roster dumps are never packaged.

## Versioning

Semantic Versioning `MAJOR.MINOR.PATCH`:

| Version | Where |
|---------|--------|
| Addon | `GuildPerformer.toc` / packager `@project-version@` |
| Import format | `ns.FORMAT_VERSION` / `GuildPerformerExportService::FORMAT_VERSION` |
| Web tool | `GuildPerformerExportService::WEB_TOOL_VERSION` |

## Known issues

- Spec field may be empty if the Google Form does not collect specialization.
- Paste strings can be large for very big rosters; prefer `.txt` download if clipboard limits hit.
- Group builder suggestions never auto-exclude players without officer confirmation.

## Roadmap

- Absences calendar view inside the addon
- Optional Ace3 profiles (character vs account) if demand grows
- Melee / ranged DPS split when the web data provides it
- Multi-guild import slots

## License

MIT — see [LICENSE](LICENSE).
