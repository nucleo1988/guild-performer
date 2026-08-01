# Guild Performer — Shared Export Format v1

## Paste string (recommended for in-game import)

```
GPv1;<headerKV>;PLAYERS;<playerRows>
```

Header keys (semicolon-separated `key=value`):

| Key | Description |
|-----|-------------|
| fv | Format version (integer, currently `1`) |
| at | Export ISO-8601 datetime |
| guild | Guild name |
| realm | Realm name |
| region | `eu` / `us` / … |
| season | Season / raid label |
| count | Player count |

Player rows use **caret** (`^`) as field separator (not `|`), records separated by `;;`.

> Why not `|`? WoW EditBoxes treat `|t`, `|h`, `|c` as UI escape codes, so pasting `|tank|` / `|healer|` corrupts the string and every role collapses to `dps`.

```
name^primaryRole^class^spec^offRoles^attendance^raidDays^mplusDays^status^launch^intends^mythic^tags^notes
```

Header may include `sep=caret`.

Field notes:

- `primaryRole`: `tank` | `healer` | `dps`
- `offRoles`: comma-separated roles (may include primary)
- `attendance`: integer nights/week or empty
- `raidDays` / `mplusDays`: comma-separated weekdays `1-7` (Mon=1)
- `status`: officer status slug
- `launch`: `day_one` | `deferred` | empty
- `intends` / `mythic`: `1` | `0` | empty
- `tags`: comma-separated note tags
- `notes`: escaped (`\` → `\\`, `|` → `\|`, `;` → `\;`, newline → `\n`)

## Lua SavedVariables download

Optional file for advanced users:

```lua
GuildPerformerDB_Import = { formatVersion = 1, ... }
```

Addon version and format version are independent.
