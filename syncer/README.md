# Guild Performer Syncer

WoW Lua **cannot** download from the internet. This small Windows script pulls your **guild-scoped** export URL from RaidRoster and writes `GuildPerformer_Data.lua` into the addon folder. After `/reload`, Guild Performer applies the roster.

## Setup (per guild / per PC)

1. On RaidRoster → guild **Config** → Guild Performer · Sync Sheet  
   - Paste the Google Sheet URL, enable sync, **Sync now**  
   - **Generate / rotate token** → **Copy URL** (shown once)
2. Copy `config.example.json` → `config.json`
3. Set:
   - `url`: the copied export URL  
   - `addonPath`: your retail AddOns `GuildPerformer` folder  
4. Run once:
   ```powershell
   cd syncer
   powershell -ExecutionPolicy Bypass -File .\Sync-GuildPerformer.ps1
   ```
5. In game: `/reload` or `/gp sync`

## Task Scheduler (every 30 minutes)

1. Open Task Scheduler → Create Basic Task  
2. Trigger: Daily, repeat every 30 minutes for 1 day (or forever)  
3. Action: Start a program  
   - Program: `powershell.exe`  
   - Arguments: `-NoProfile -ExecutionPolicy Bypass -File "C:\path\to\guild-performer\syncer\Sync-GuildPerformer.ps1"`  
4. Keep WoW closed or accept that the file updates on disk until the next `/reload`

## Multi-guild

Each guild has its **own** token URL. Use a separate `config.json` (or `-ConfigPath`) per guild/PC. Never share another guild’s URL.

## Security

The URL is a secret: anyone with it can download the roster (including officer notes). Rotate the token on the site if it leaks.
