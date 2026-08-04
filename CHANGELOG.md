# Changelog

All notable changes to Guild Performer will be documented in this file.

## [Unreleased]

## [1.3.0] - 2026-08-04

### Added

- **RaidRoster Companion** sync (pull/push) via `GuildPerformer_Data.lua` staging file.
- **Guild** tab: ilvl / roles / Raider.IO enrichment display.
- **Events** calendar view and calendar role helpers.
- `/gp pushprep` flow for members (own characters) and officers (full roster).
- Class Performer–style CurseForge release tooling (`tools/release`, `release.bat`) for project **1635122**.

### Changed

- Notes/TOC updated for Companion + RaidRoster workflow.
- Packaging keeps roster data stub-only (never ships live guild dumps).

## [1.1.1] - 2026-08-01

### Added

- **Guild Performer Sync** Windows GUI + Setup installer (`syncer/app`, `syncer/installer`) for non-technical officers.
- GitHub Action `build-syncer.yml` attaches Setup.exe to releases.

## [1.1.0] - 2026-08-01

### Added

- Desktop syncer (`syncer/`) fetches guild-scoped HTTPS export and writes `GuildPerformer_Data.lua` (WoW cannot HTTP GET).
- `/gp sync` and Settings/Import **Apply sync data**; optional auto-apply on login.
- Settings field for Sync URL (informational; used with the syncer).

### Fixed

- Paste format field separator is `^` (caret). Raw `|` breaks WoW EditBox (`|tank|` / `|healer|` corruption).

## [1.0.0] - 2026-08-01

### Added

- Initial Guild Performer addon (dashboard, roster filters, import, settings, group builder).
- Shared `GPv1` paste format and Lua dump documentation.
- Packaging scripts and GitHub Actions for validate + CurseForge release (project 1635122).
- enUS / itIT locales.
