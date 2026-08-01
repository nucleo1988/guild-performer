# Export tool

The interactive **Export Guild Performer** UI ships inside the RaidRoster Laravel app
(`Analisi` → `Guild Performer` tab), not as a standalone SPA in this repository.

This folder documents how to integrate or re-host the encoder:

- Shared format: [`../shared/FORMAT.md`](../shared/FORMAT.md)
- Reference PHP encoder: RaidRoster `App\Services\RaidSeason\GuildPerformerExportService`
- Format version constant must stay aligned with `addon/ExportFormat.lua` (`ns.FORMAT_VERSION`)

Flow:

1. Officer opens RaidRoster guild analysis.
2. Selects players / filters.
3. Copies `GPv1;…` string or downloads `.txt` / `.lua`.
4. In WoW: `/gp import` → paste → Preview → Replace or Merge.
