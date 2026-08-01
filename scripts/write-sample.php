<?php
// full export embedded
$raw = file_get_contents("php://stdin");
file_put_contents(__DIR__ . "/sample-export.txt", $raw);
echo "wrote ".strlen($raw)."\n";
