# Changelog

All notable changes to Guild Performer will be documented in this file.

## [Unreleased]

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
