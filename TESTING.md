# Development verification

Version 0.1.3 is an explicitly development-only candidate. Do not advertise it
as production-ready until the live gates below have evidence.

## Local gates

```sh
./scripts/check-source-capabilities.sh
./scripts/check-compatibility.sh
./scripts/check-reproducibility.sh
```

The source gate runs bounded lifecycle **specification tests** and checks that
the Pawn implementation contains the corresponding safety contracts. The model
is an explicitly labeled test double; it does not execute Pawn or emulate
ReHLDS, and is not gameplay evidence. Compilation on AMXX 1.9 and 1.10 proves
syntax/native declaration compatibility only. Two clean builds prove the
release artifact can be reproduced from the checked-in source and pinned tools.

The team-choice regression checks evaluate the actual Pawn guard's restricted
boolean expression across 80 phase/participant/menu-choice combinations, with an
explicit test-only participant stub. Separate source contracts require the shared
engine pre-hook and its exact integer-zero/supercede return. Engine `BOOL` is
not ReAPI's distinct `ATYPE_BOOL`; using the latter compiled but raised a
real native runtime error in 0.1.2. A negative-control run of the regression
check rejects that old call. A score contract checks each
actual winning branch increments only its own score after the ending guard and
before termination; the draw branch cannot increment. Three static helper checks
cover console-only access, fake ownership guards and the absence of synthetic
damage/deaths or human state writes. These 20 total checks do not execute engine
menus, round scoring, fake clients or client gameplay.

CI compiles both the core and the opt-in test helper with both supported
compilers. Runtime release assets contain only the core. The detailed controlled
operator procedure is [tests/live/ACCEPTANCE.md](tests/live/ACCEPTANCE.md).

## Required development server + real client gates

Use a dedicated development server and legally provisioned Valve CS1.6 client.
Reserve the test server explicitly; never reuse a customer's server or copy its
files. Record the Panel recipe/runtime identity, plugin/module versions, source
commit and artifact SHA-256. Remove passwords, player IPs, account/Steam IDs and
unrelated player names from evidence.

1. Install via the managed recipe; verify `amxx plugins` has exactly one core
   mode, all required modules load, `mp_round_infinite=1`, `mp_freeforall=0`,
   `mp_forcerespawn=0`, and no missing custom downloads occur on `de_dust2`.
2. With one player, confirm waiting HUD and automatic recovery after death.
   Add a second player; preparation must start without a manual restart.
3. Confirm countdown, shuffled initial infection leaving a human, visible role
   difference, M4A1/USP/knife human loadout, knife-only zombie loadout, speed,
   gravity, health and normal reloads/unlimited reserve ammunition.
4. Have a zombie hit a human with primary and secondary knife attacks. Both
   must infect immediately without killing the victim. Human weapon damage and
   environmental damage must not be misclassified as infection.
5. Kill the sole living zombie. It must respawn after the configured delay;
   humans must not win early while it is dead. Kill a human/environmental death;
   it must return as zombie. A new player joining during infection becomes a
   zombie; spectators remain spectators and cannot be respawned by the mode.
6. With shortened development-only durations (minimum 15 seconds), leave a
   human alive until timeout: CT score/win exactly once, then fresh preparation.
   Infect the final human: T score/win exactly once, then a clean next round.
7. Disconnect/spectate the sole zombie, then the final human in separate rounds.
   Confirm valid terminal outcomes; disconnect everyone and reconnect. Rapid
   round restart/map change and slot reuse must not produce stale respawns.
8. Repeat core loop on `cs_office` (hostages) and an officially provisioned VIP
   map if supported; native objectives must never end an infection round.
9. Verify `/zombie`, status HUD, allowed spectating, blocked active team changes,
   admin permission checks and active-only `amx_zi_infect`. During infection,
   test direct `jointeam 1/2/5`, VGUI team choices, and legacy `_vgui_menus 0` ->
   `chooseteam` -> `menuselect 1/2/5`; all must preserve the active role/team.
   Spectator choice 6 must remain allowed in each path; spectators/late joins
   can join and become zombies. Repeat choices during preparation and after the
   round ends, when the plugin must allow normal engine handling. Inspect AMXX/runtime
   logs after several rounds and a map change; no runtime/native errors.
10. Reinstall a different managed mode and confirm the infection plugin and
    round/ammo/team/respawn configuration are removed/restored correctly.

Record results as observed, with privacy-safe client screenshots and matching
server outcome logs. Report failures and untested cases explicitly. A working
headless server or bot-only round does not replace actual client-visible and
human-controlled knife-infection checks.
