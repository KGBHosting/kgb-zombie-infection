<?php
// GPL-3.0-or-later. TEST-ONLY numeric parser. No app, network or server access.
function zicapSchemas(): array
{
    return [
        'loaded' => 'version_major version_minor version_patch test_only',
        'disconnect' => 'slot previously_owned round time',
        'round_reset' => 'round time',
        'created' => 'slot userid owned_test_double round time',
        'add_complete' => 'requested created owned maximum_slots',
        'engine_spawn' => 'slot userid owned_test_double team joining spawns_this_round round time',
        'native_joined' => 'slot userid team alive round time',
        'drop' => 'slot userid round time',
        'clear_complete' => 'owned',
        'participant' => 'slot userid owned_test_double real_client alive team joining solid spawns_this_round world_blocked round',
        'hull' => 'slot x y z min_x min_y min_z max_x max_y max_z',
        'hull_overlap' => 'slot_a slot_b userid_a userid_b depth_x depth_y depth_z',
        'counts' => 'maximum_slots connected joined pending alive ct_alive t_alive round time',
        'ownership' => 'real_clients owned_test_doubles foreign_fake unspawned_this_round spawned_owned spawned_real round time',
        'collision' => 'overlap_pairs world_blocked round time',
    ];
}
function zicapRefusalSchemas(): array
{
    return [
        1 => 'code maximum_slots owned foreign_fake requested limit',
        2 => 'code created',
        3 => 'code slot',
        4 => 'code slot',
        5 => 'code slot accepted',
        6 => 'code slot',
        7 => 'code',
        8 => 'code',
        9 => 'code',
    ];
}
function zicapNumeric(string $field, string $raw, string $event): int|float|null
{
    if ($field === 'time') {
        if (!preg_match('/^(?:0|[1-9]\d{0,7})\.\d{2}$/D', $raw)) return null;
        $value = (float) $raw;
        return is_finite($value) && $value <= 86400000.0 ? $value : null;
    }
    if (in_array($field, ['x','y','z','min_x','min_y','min_z','max_x','max_y','max_z','depth_x','depth_y','depth_z'], true)) {
        if (!preg_match('/^-?(?:0|[1-9]\d{0,4})\.\d{3}$/D', $raw)) return null;
        $value = (float) $raw;
        if (!is_finite($value) || abs($value) > 32768.0) return null;
        if (str_starts_with($field, 'depth_') && ($value <= 0.0 || $value > 256.0)) return null;
        return $value;
    }
    if (!preg_match('/^(?:0|[1-9]\d{0,8})$/D', $raw)) return null;
    $value = (int) $raw;
    $bounds = [
        'slot'=>[1,32], 'slot_a'=>[1,32], 'slot_b'=>[1,32],
        'userid'=>[1,999999999], 'userid_a'=>[1,999999999], 'userid_b'=>[1,999999999],
        'code'=>[1,9], 'round'=>[0,999999999], 'requested'=>[0,999999999],
        'maximum_slots'=>[1,32], 'owned'=>[0,31], 'limit'=>[0,31], 'created'=>[0,31],
        'previously_owned'=>[0,1], 'accepted'=>[0,1], 'owned_test_double'=>[0,1], 'real_client'=>[0,1],
        'team'=>[0,3], 'joining'=>[0,5], 'solid'=>[0,4], 'spawns_this_round'=>[0,1000000],
        'connected'=>[0,32], 'joined'=>[0,32], 'pending'=>[0,32], 'alive'=>[0,32],
        'ct_alive'=>[0,32], 't_alive'=>[0,32], 'real_clients'=>[0,32], 'owned_test_doubles'=>[0,31],
        'foreign_fake'=>[0,32], 'unspawned_this_round'=>[0,32], 'spawned_owned'=>[0,31], 'spawned_real'=>[0,32],
        'overlap_pairs'=>[0,496], 'world_blocked'=>[0,32],
        'version_major'=>[0,0], 'version_minor'=>[1,1], 'version_patch'=>[0,0], 'test_only'=>[1,1],
    ];
    if (!isset($bounds[$field])) return null;
    if ($field === 'alive' && $event !== 'counts') $bounds[$field] = [0,1];
    if ($field === 'world_blocked' && $event === 'participant') $bounds[$field] = [0,1];
    return $value >= $bounds[$field][0] && $value <= $bounds[$field][1] ? $value : null;
}
function zicapSafeLine(string $raw): ?array
{
    if (strlen($raw) > 4096) return null;
    // Known ANSI SGR only. All other controls, newlines and escape sequences fail.
    $line = preg_replace('/\x1b\[[0-9;]*m/', '', $raw);
    if ($line === null || preg_match('/[\x00-\x1f\x7f]/', $line)) return null;
    $line = trim($line, ' ');
    if (!preg_match('/^\[ZICAP\] event=([a-z_]+)(?: (.*))?$/D', $line, $match)) return null;
    $event = $match[1];
    $parts = isset($match[2]) ? explode(' ', $match[2]) : [];
    if ($event === 'refused') {
        if (!isset($parts[0]) || !preg_match('/^code=([1-9])$/D', $parts[0], $code)) return null;
        $fields = zicapRefusalSchemas()[(int) $code[1]] ?? null;
    } else $fields = zicapSchemas()[$event] ?? null;
    if ($fields === null) return null;
    $keys = explode(' ', $fields);
    if (count($parts) !== count($keys)) return null;
    $record = ['source'=>'ZICAP', 'event'=>$event];
    foreach ($keys as $index=>$key) {
        $prefix = $key . '=';
        if (!str_starts_with($parts[$index], $prefix)) return null;
        $value = zicapNumeric($key, substr($parts[$index], strlen($prefix)), $event);
        if ($value === null) return null;
        $record[$key] = $value;
    }
    // Every field has been checked before any record is returned. No raw text.
    return $record;
}
