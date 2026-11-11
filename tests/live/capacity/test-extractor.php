<?php
require __DIR__ . '/zicap-safe-logs-library.php';
$fixtures = json_decode(file_get_contents(__DIR__ . '/extractor-fixtures.json'), true, 512, JSON_THROW_ON_ERROR);
$checks = 0;
foreach ($fixtures['positive'] as $line) {
    $record = zicapSafeLine($line);
    if ($record === null || ($record['source'] ?? null) !== 'ZICAP') throw new RuntimeException('positive fixture rejected: ' . $checks);
    foreach ($record as $key=>$value) if (!in_array($key, ['source','event'], true) && !is_int($value) && !is_float($value)) throw new RuntimeException('non-numeric field escaped');
    ++$checks;
}
foreach ($fixtures['negative'] as $line) {
    if (zicapSafeLine($line) !== null) throw new RuntimeException('negative fixture accepted: ' . $checks);
    ++$checks;
}
$zero = zicapSafeLine('[ZICAP] event=hull_overlap slot_a=1 slot_b=2 userid_a=1 userid_b=2 depth_x=0.000 depth_y=1.000 depth_z=1.000');
if ($zero !== null) throw new RuntimeException('adjacent boundary counted as overlap');
++$checks;
$summary = [];
foreach ($fixtures['summaries'] as $line) {
    $record = zicapSafeLine($line);
    if ($record === null) throw new RuntimeException('split summary rejected');
    $summary += $record;
    ++$checks;
}
if (($summary['maximum_slots'] ?? null) !== 32 || ($summary['owned_test_doubles'] ?? null) !== 31 || ($summary['real_clients'] ?? null) !== 1 || ($summary['overlap_pairs'] ?? null) !== 0) throw new RuntimeException('numeric32-slot split summary not preserved');
++$checks;
// Exhaustive field suffix substitution of all source print formats: reject
// identity payloads even when they replace an otherwise legitimate field.
foreach ($fixtures['positive'] as $line) {
    foreach (['STEAM_0:1:12345','VALVE_ID_PENDING','private@example.invalid','192.0.2.7','ZombieQA'] as $identity) {
        $mutated = preg_replace('/=([^ =]+)$/', '=' . $identity, $line);
        if (zicapSafeLine($mutated) !== null) throw new RuntimeException('identity substitution escaped');
        ++$checks;
    }
}
echo json_encode(['local_fixture_checks'=>$checks,'source_print_templates'=>count($fixtures['positive']),'negative_fixtures'=>count($fixtures['negative']),'remote_calls'=>0], JSON_THROW_ON_ERROR) . PHP_EOL;
