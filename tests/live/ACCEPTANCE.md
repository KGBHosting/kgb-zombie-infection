# Controlled Valve-client acceptance

This is a procedure, **not a record of passing gameplay**. No live result is
implied by compiling the core or helper. Fill in the evidence table only after
observing each case. Use a reserved development server, a legally provisioned
original Valve Steam client, stock server assets, and no customer files.

## Identity and setup

Record the source commit, core AMXX SHA-256, helper source/artifact SHA-256,
Panel recipe version, stopped-runtime fingerprint attestation, running engine,
ReGameDLL, ReAPI and AMXX versions, stock map, and UTC test time. The normal
installation must load exactly one core mode with its managed configuration.
The real process must be Steam's `hl.exe -steam -game cstrike`; connect and
complete its team/class flow normally. Do not set the human's joining state,
team, position, weapons, health, movement or input through instrumentation.

Retain cropped game screenshots and matching server evidence. Remove account
names, Steam/auth IDs, player IPs, credentials and unrelated player names.
Helper logs contain only slots, ephemeral engine user IDs, game state and stock
model/weapon names. Raw engine logs may contain identities and need redaction.

Build the opt-in helper from this exact source commit:

```sh
BUILD_COMPONENTS='core acceptance-helper' ./scripts/check-compatibility.sh
AMXX_VERSION=1.9 BUILD_COMPONENTS=acceptance-helper ./scripts/build.sh
shasum -a 256 compiled/kgb_zi_acceptance_helper.amxx tests/live/kgb_zi_acceptance_helper.sma
```

Install `compiled/kgb_zi_acceptance_helper.amxx` **after** the core plugin in
the reserved server's `plugins.ini`. Restart the development server, verify
`amxx plugins`/`amxx modules` without errors, then record the configuration:

```text
version
meta list
amxx plugins
amxx modules
mp_round_infinite
mp_freeforall
mp_forcerespawn
mp_friendlyfire
mp_freezetime
mp_infinite_ammo
kgb_zi_infection_delay
kgb_zi_survival_time
kgb_zi_zombie_ratio
kgb_zi_respawn_delay
amx_zi_status
ziqa_list
```

Expected mode defaults: infinite native round `1`, free-for-all/automatic native
respawn/friendly fire/freeze `0`, reserve-only infinite ammo `2`; preparation
`15`, survival `180`, initial zombie ratio `.20`, respawn `3` seconds. A missing
or mismatched runtime prerequisite invalidates the run.

## Test helper boundary

All `ziqa_*` commands are **server-console only**. Arguments are the positive
ephemeral numeric user IDs from `ziqa_list`, without `#`; do not use account IDs
or names. In examples below replace `REAL`, `FAKE` and `HUMAN_FAKE` with those
observed values. They are placeholders, not literal server input.

| Command | Effect |
| --- | --- |
| `ziqa_add 3` | Creates three explicitly stationary engine fake-client test doubles; at most three owned fakes exist. |
| `ziqa_list` | Reads participants, teams/join states, core phase and engine team scores. |
| `ziqa_snapshot REAL` | Reads loadout, current actual/cached weapon, stats, model/render, joining state and natural frame count. |
| `ziqa_place FAKE REAL 45` | Moves only the owned living fake in front of the living real client; rejects occupied hulls. No role/loadout/stats overrides. |
| `ziqa_health FAKE 1` | Optional **labeled fake-only fixture setup**, after capturing default health. It applies no damage and cannot prove default durability. |
| `ziqa_drop FAKE` | Kicks only the identity-checked owned fake through normal disconnect. |
| `ziqa_clear` | Disconnects all currently owned fakes; never kicks humans. |

Fakes receive one-time CT/class/JOINED enrollment because they have no Valve
menus. The core's normal spawn hook then supplies the phase-appropriate role and
loadout. The helper preserves each fake's slot + positive original user ID,
verifies `FL_FAKECLIENT`, restores fake-only stationary flags after spawn, and
feeds zero movement/buttons with fake-only idle activity. It never attacks,
calls infection internals, applies `Ham_TakeDamage`/`Ham_Killed`, sends a
DeathMsg, or changes a real client's state. One-time fake class initialization
does not qualify real-client onboarding or player model rendering.

Actual Valve-client primary/secondary attacks, actual engine damage/death,
spawn events, TeamScore messages and game-rule scores are observed. A logged
attack alone is not proof that a target was hit. Match damage/conversion/death
and client-visible results. `rg_round_end` does not trigger the RG_RoundEnd
hook by default, so the helper observes native round log/messages and counters
instead of relying on that hook.

## Minimum controlled matrix

Start on `de_dust2` with one real client and no fakes. After testing waiting,
add three fakes: the normal `.20` rule then creates exactly one initial zombie
and leaves three humans. Choose targets from **observed** teams; never force an
infection role through the helper. Capture each default loadout before any
optional fake health override. The product admin infection command may be used
only for its own authorization test or explicitly recorded setup after the
normal initial-infection/countdown observation.

| Case | Actions and required evidence |
| --- | --- |
| Waiting and preparation | With one real player: waiting HUD, natural joined/alive state, CT weapons and stats. A normal `kill`/respawn during waiting recovers as human. `ziqa_add 3`: countdown starts without restart, lasts the default 15 seconds (allow the 1-second scheduling tick), no early infection, then exactly one of four is zombie. Capture visible HUD and snapshots before/after. |
| Default roles/loadouts | Humans: CT, M4A1/USP/knife, 100 HP, 50 helmet armor, gravity 1, normal stock appearance. Zombies: T, knife only, 3000 HP, armor 0, gravity .80, max speed 300 while moving, green glow. Observe actual human movement/jump and remote player visibility; snapshot values alone do not prove movement/rendering. Confirm human M4A1 reloads normally while reserve remains available. |
| Human damage and zombie respawn | If the real player is human, place the sole zombie fake at a safe distance (e.g. 100). Shoot with the actual M4A1 until genuine engine death. Capture default 3000 HP first; prefer testing full health, or explicitly record a fake-only health fixture if shortening the kill. A dead zombie remains a participant, no early CT win occurs, and it respawns as T/knife after about 3–4 seconds with restored normal zombie stats. If the real player was the initial zombie, perform this case after a fresh round with a real human; do not replace it with fake attacks. |
| Human death and late joining | While other humans remain, use the real client's normal suicide or a genuine fall death: actual death, then natural zombie respawn, default zombie loadout/stats. A suicide does not also prove fall damage. Separately disconnect/reconnect the real Valve client during infection, complete its menus naturally, and confirm it becomes zombie while original humans survive. No helper assignment to JOINED is permitted. |
| Both melee attacks | With the real client now a zombie and at least two observed human fakes alive, `ziqa_place HUMAN_FAKE REAL 45`, wait for normal spawn protection expiry, then use the actual client primary knife attack. The target immediately becomes T, remains alive, receives zombie loadout/stats and has no extra DeathMsg/death count. Repeat against another human with actual secondary stab. The helper crosshair trace must hit the intended target; move/aim normally if needed. |
| Zombie victory/reset | Infect the final human through actual real-client melee. Capture exactly one T score increment (engine counter + TeamScore + visible scoreboard), one winner announcement/outcome, no extra increment during the 3-second ending gap, then everyone playing returns to CT human loadout in fresh preparation. Keep observing beyond the next timer tick. |
| Human survival victory/reset | After recording the default 180-second start, set `kgb_zi_survival_time 15` **before the next infection phase**, restart normally and record this test-only change. Keep a human alive to the deadline with stationary zombies. Capture exactly one CT point, no T point, one win/outcome, clean all-human next preparation. Also record one complete default 180-second survival round before claiming the default duration qualified. Restore `180` afterward. |
| Team lock and native spectating | While infected, snapshot the real player's role/team, attempt direct `jointeam 1`, `jointeam 2`, `jointeam 5`; VGUI choices; then real-client `setinfo _vgui_menus 0`, `chooseteam`, `menuselect 1/2/5`. All preserve role/team/loadout with the mode's lock message. Repeat in preparation/ending: the plugin must delegate normal engine handling. Test spectator choice `6` while **dead or in freeze**, as required by the native game DLL, with `allow_spectators 1`. While alive the native engine may refuse; this is not a plugin lock failure. A spectator is excluded, stays unrespawned beyond the delay, then rejoins through normal menus and becomes zombie during infection. Restore the client's original `_vgui_menus` value. |
| Disconnect outcomes/empty recovery | In separate active rounds, disconnect the sole zombie (normal `ziqa_drop` if owned fake) with humans remaining: CT wins once. Disconnect the final human through the actual client's normal disconnect while zombies remain: T wins once. `ziqa_clear` and real disconnect before the next 1-second tick: no participants means drawn result with no point. If ordering prevents a true simultaneous empty state, record that draw branch as untested rather than claiming it passed. Reconnect and add fakes to recover without stale roles/deadlines. |
| Authorization and helper safety | An unprivileged real client cannot run `amx_zi_infect`; snapshots unchanged. Server-console `amx_zi_infect #FAKE` rejects waiting/preparation and accepts only a living human in active infection; use a non-final human. Client `ziqa_*` commands are unavailable. Server `ziqa_health REAL 1`, `ziqa_place REAL REAL 45` and `ziqa_drop REAL` must refuse and leave the human unchanged. Retry stale fake user IDs after disconnect/slot reuse; all mutations must refuse. |
| Restart/objectives/cleanup | Real normal restart during a pending respawn, and `changelevel` on stock `cs_office`: clean phase, no old spawn, correct human preparation. Observe several complete rounds without AMXX native/runtime errors. Verify bomb/hostage (and officially provisioned VIP if supported) objectives cannot terminate infection, with no unexpected custom downloads. Finally uninstall/reinstall a different managed recipe, verify all infection config/plugin/helper files are gone and the replacement mode behaves normally. |

The fake clients cannot prove a second real human's onboarding or input. Record
that coverage limit. Core infection acceptance must include the real client's
normal joined state and actual attacks; fake-only cycles cannot satisfy it.

## Evidence receipt and cleanup

For each case retain a row with UTC time, observed result, core/helper hashes,
sanitized screenshot path/hash, matching engine/core log excerpt, and pass,
fail or explicitly untested. Record default-config checks separately from
shortened timers or fake health fixtures. No observed result is pre-filled here.

Before leaving the reserved server: run `ziqa_clear`, remove the helper from
`plugins.ini` and disk, restore recorded temporary CVars/client menu settings,
restart, verify no helper is loaded, and check logs again. The Panel fifth
Reinstall option must stay unpublished until the agreed real-client/live gates
pass. Production promotion is a separate authorized release step.
