# Capacity fixture: development tests only

This stationary fake-client helper is **test instrumentation**, never a runtime
core/map release asset. Its source matches the frozen r3 correction. It measures
native enrollment/spawn allocation and actual hull occupancy;31 fake test doubles
plus one genuine Valve client are not 32 real network clients and prove no performance
or player-count entitlement.

The genuine Valve client joins normally and remains read-only. Fakes also reach
JOINED via native team/class commands and normal engine thinking; there is no
forced team, joining state or spawn. Every fake write requires its positive
original ephemeral userid plus ownership/native fake proof; a slot or name alone
never authorizes mutation. Creation reserves one real-client slot even if the
real player has not connected yet. Foreign fakes make further creation fail.

Server-console commands: `zicap_add COUNT`, `zicap_snapshot`,
`zicap_drop EPHEMERAL_USERID`, and `zicap_clear`. They never change slot limits,
CVars, map, restart, human movement/stats or gameplay damage. An unprovable partial
creation requires stopping/restarting the operator's isolated test server; do not
force flags or ownership to hide it.

For capacity evidence, await naturally JOINED clients, perform an approved native
round reset, and take a settled snapshot. Only then compare observed per-round
Ham_Spawn counts with connected/JOINED/alive team counts. Initial creation may
observe a pre-JOINED spawn and is not capacity acceptance. World checks use
world-only TraceHull; player intersections require strictly positive three-axis
penetration, so adjacent boundaries are not overlaps.

Aggregate output is three complete fixed-schema lines: `counts`, `ownership`,
`collision`, each with the same round/time. Every source printf message is at
most 177 bytes at the parser's supported numeric bounds; no 255-byte truncation is
accepted as a successful snapshot. Individual participant/hull rows remain
necessary evidence. Unknown fields/events/identities fail closed in the parser.

`extractor.php` is a pure numeric parsing library with no application, endpoint,
credentials or network access. To filter operator-provided logs locally:

```sh
php tests/live/capacity/extract.php < private-console.log
python3 tests/live/capacity/test-extractor.py
```

Keep raw logs private. The extractor emits only fixed event names and validated
numeric fields, including temporary game userids; account/auth IDs, names,
addresses, emails and raw errors are rejected. The private deployment/access
adapter is deliberately outside this public source. Tests use synthetic identity
strings and documentation-only addresses as explicit negative-control fixtures.

## Qualification status

Local AMXX 1.9/1.10 compilation is warning-free and repeat 1.9 bytes match. The strict
parser has 199 local fixture checks across 24 actual source print templates and 50
negative fixtures. These are compiler/parser checks, not gameplay tests.
Controlled capacity qualification passed on 2026-11-11 for the frozen original
courtyard, depot and containment maps: one genuine Valve client plus 31 stationary
fake test doubles, all 32 naturally JOINED and alive CT after native round reset,
each with one observed native spawn in that round, 32 unique hull origins and zero
world blockage/positive player-hull overlap. The independent receipt validator
also confirmed all 32 CT spawn origins were exercised on each map. See
[qualification.json](qualification.json) for immutable source/map identities.
This result covers capacity/spawn allocation only. It does not prove 32 real-client
network performance, full route traversal, infection balance or final operator
cleanup. Keep those acceptance gates separate.

The bounded ClientConnect rejection-buffer call follows the
[official Fakemeta implementation](https://github.com/alliedmodders/amxmodx/blob/844eebd471635c197f5f4fffb71c2ea0628310fd/modules/fakemeta/dllfunc.cpp#L115-L126).
The helper is GPL-3.0-or-later, covered by the repository license.
