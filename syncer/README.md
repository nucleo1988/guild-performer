# Guild Performer Sync

App Windows per aggiornare il roster **senza PowerShell**. Pensata per officer non tecnici.

## Per la gilda (utenti)

1. Scarica **`GuildPerformerSync-Setup-*.exe`** dalla [Release](https://github.com/nucleo1988/guild-performer/releases) (oppure `GuildPerformerSync.exe` portable).
2. Installa e apri **Guild Performer Sync**.
3. Sul sito RaidRoster → pannello gilda → **Config** → genera token → **Copia URL**.
4. Nell’app: **Incolla** l’URL → **Trova** (cartella addon) → **Sincronizza ora**.
5. In gioco: `/reload` oppure `/gp sync`.

Opzionale: attiva *Sincronizza automaticamente* e *Avvia con Windows*.

> Ogni gilda ha il **proprio** URL. Non condividere quello di un’altra gilda.

## Sviluppatori — build locale

```powershell
cd syncer\app
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Output:

- `syncer/app/dist/GuildPerformerSync.exe` — portable  
- `syncer/dist-installer/GuildPerformerSync-Setup-1.1.0.exe` — installer (richiede [Inno Setup 6](https://jrsoftware.org/isinfo.php))

## CLI (dopo installazione)

```text
GuildPerformerSync.exe --sync
GuildPerformerSync.exe --sync --force
```

Config salvata in `%APPDATA%\GuildPerformerSync\config.json`.

## Script PowerShell (avanzato)

`Sync-GuildPerformer.ps1` resta disponibile per automazioni headless; l’app GUI è il percorso consigliato.
