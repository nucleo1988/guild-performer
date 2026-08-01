<?php
// Mimic Guild Performer Lua GPv1 parser closely.
$raw = file_get_contents(__DIR__ . '/sample-export.txt');
$raw = preg_replace('/^\xEF\xBB\xBF/', '', $raw);
$raw = trim($raw);
$raw = str_replace(["\r\n", "\n", "\r"], '', $raw);

echo "len=" . strlen($raw) . "\n";
echo "prefix=" . substr($raw, 0, 5) . "\n";
echo "lua_sub6=" . substr($raw, 5, 30) . "\n";

if (!str_starts_with($raw, 'GPv1;')) {
    fwrite(STDERR, "INVALID PREFIX\n");
    exit(1);
}

$rest = substr($raw, 5); // Lua sub(6) == PHP substr(5)
$marker = strpos($rest, ';PLAYERS;');
if ($marker === false) {
    fwrite(STDERR, "NO PLAYERS MARKER\n");
    exit(1);
}
$header = substr($rest, 0, $marker);
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
            $buf .= $c . $body[$i + 1]; // BUG COPY from lua? use $row
            $buf = substr($buf, 0, -1); // undo wrong
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

function splitFieldsFixed(string $row): array
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

$roles = ['tank' => [], 'healer' => [], 'dps' => [], 'other' => []];
$bad = [];
foreach (splitRecords($body) as $row) {
    $f = splitFieldsFixed($row);
    $name = $f[0] ?? '';
    $role = strtolower(trim($f[1] ?? ''));
    $class = $f[2] ?? '';
    if ($name === '') {
        $bad[] = 'empty name fields=' . count($f);
        continue;
    }
    if (!isset($roles[$role])) {
        $roles['other'][] = "$name role='$role' fields=" . count($f) . " f2=" . ($f[1] ?? '');
        continue;
    }
    $roles[$role][] = "$name | $class | fields=" . count($f);
}

foreach ($roles as $r => $list) {
    echo strtoupper($r) . ' = ' . count($list) . "\n";
    foreach ($list as $line) {
        echo "  $line\n";
    }
}
echo 'BAD=' . count($bad) . "\n";
