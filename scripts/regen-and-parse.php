<?php

require __DIR__ . '/../../raidroster/vendor/autoload.php';
$app = require __DIR__ . '/../../raidroster/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$guild = App\Models\Guild::where('name', 'Iron Legion')->first();
if (!$guild) {
    echo "no guild\n";
    exit(1);
}
$season = App\Models\RaidSeason::where('guild_id', $guild->id)->where('is_active', 1)->first();
$snaps = $season->currentSnapshots()->with(['player.notes', 'roles', 'availabilities', 'noteTags', 'playableClass'])->get();
$payload = app(App\Services\RaidSeason\GuildPerformerExportService::class)->buildPayload($guild, $season, $snaps);
file_put_contents(__DIR__ . '/sample-export.txt', $payload['paste']);

echo 'players=' . $payload['meta']['count'] . ' len=' . strlen($payload['paste']) . PHP_EOL;
$roles = ['tank' => 0, 'healer' => 0, 'dps' => 0];
foreach ($payload['players'] as $p) {
    $roles[$p['primaryRole']] = ($roles[$p['primaryRole']] ?? 0) + 1;
    echo str_pad($p['primaryRole'], 7) . ' ' . $p['name'] . PHP_EOL;
}
print_r($roles);

// Now mimic Lua parser
$raw = $payload['paste'];
$raw = str_replace(["\r\n", "\n", "\r"], '', $raw);
$rest = substr($raw, 5);
$marker = strpos($rest, ';PLAYERS;');
$body = substr($rest, $marker + 9);

function splitRecords(string $body): array
{
    $rows = [];
    $buf = '';
    $len = strlen($body);
    for ($i = 0; $i < $len; $i++) {
        $c = $body[$i];
        if ($c === '\\' && $i + 1 < $len) {
            $buf .= $c . $body[$i + 1];
            $i++;
            continue;
        }
        if ($c === ';' && ($i + 1 < $len) && $body[$i + 1] === ';') {
            if ($buf !== '') {
                $rows[] = $buf;
            }
            $buf = '';
            $i++;
            continue;
        }
        $buf .= $c;
    }
    if ($buf !== '') {
        $rows[] = $buf;
    }
    return $rows;
}

function splitFields(string $row): array
{
    $fields = [];
    $buf = '';
    $len = strlen($row);
    for ($i = 0; $i < $len; $i++) {
        $c = $row[$i];
        if ($c === '\\' && $i + 1 < $len) {
            $buf .= $c . $row[$i + 1];
            $i++;
            continue;
        }
        if ($c === '|') {
            $fields[] = $buf;
            $buf = '';
            continue;
        }
        $buf .= $c;
    }
    $fields[] = $buf;
    return $fields;
}

$parsed = ['tank' => 0, 'healer' => 0, 'dps' => 0, 'other' => 0];
foreach (splitRecords($body) as $row) {
    $f = splitFields($row);
    $role = strtolower(trim($f[1] ?? 'missing'));
    if (!isset($parsed[$role])) {
        $role = 'other';
    }
    $parsed[$role]++;
    if (($f[1] ?? '') !== '' && !in_array($f[1], ['tank', 'healer', 'dps'], true)) {
        echo "WEIRD ROLE name={$f[0]} role={$f[1]} fields=" . count($f) . PHP_EOL;
    }
}
echo "PARSED VIA LUA MIMIC:\n";
print_r($parsed);
echo 'record_count=' . count(splitRecords($body)) . PHP_EOL;
