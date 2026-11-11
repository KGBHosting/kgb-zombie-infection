<?php
// GPL-3.0-or-later. TEST ONLY. Reads stdin; emits only strict numeric records.
require __DIR__ . '/extractor.php';
$kept = $dropped = 0;
while (($raw = fgets(STDIN, 4098)) !== false) {
    if (!str_ends_with($raw, "\n") && !feof(STDIN)) {
        // Reject an entire overlong input line, including any later valid-looking
        // suffix; never parse successive buffer chunks as independent records.
        while (($tail = fgets(STDIN, 4098)) !== false && !str_ends_with($tail, "\n")) {}
        ++$dropped;
        continue;
    }
    if (str_ends_with($raw, "\n")) $raw = substr($raw, 0, -1);
    if (str_ends_with($raw, "\r")) $raw = substr($raw, 0, -1);
    $record = zicapSafeLine($raw);
    if ($record === null) { ++$dropped; continue; }
    echo json_encode($record, JSON_THROW_ON_ERROR) . "\n";
    ++$kept;
}
echo json_encode(['source'=>'ZICAP_extractor', 'event'=>'local_input_summary', 'kept_lines'=>$kept, 'dropped_lines'=>$dropped], JSON_THROW_ON_ERROR) . "\n";
