# 0.2.0 weapon menu and stock night vision acceptance

Status: **NOT RUN**. This is a candidate procedure, not a gameplay receipt.
Do not change the managed recipe or replace the qualified 0.1.3 release until
the exact 0.2.0 candidate completes this matrix and the core acceptance matrix.
Use a reserved development server and a legally provisioned Valve Steam client.
Never install the candidate on a customer server. Preserve the known-good
0.1.3 artifact/configuration for rollback and keep its immutable tag unchanged.

Record the exact source, configuration and AMXX 1.9 artifact SHA-256 from the
local build receipt, the installed file hash, runtime/module versions, map and
time. Capture client-visible results together with the server inventory/status
and privacy-safe AMXX logs. Do not include credentials, addresses, Steam IDs or
unrelated names. Existing opt-in test helpers remain frozen and excluded from
runtime assets; a stationary fake test double may provide a second participant,
but cannot qualify client menus, NVG rendering or human knife input.

## Weapon choices and onboarding

1. Join through the normal VGUI team/class flow while alone, then repeat using
   `setinfo _vgui_menus 0` and the legacy text flow. Leave each onboarding menu
   open for more than two clock ticks: the weapon menu must not replace it.
   Once alive, CT and fully joined, the menu should open on the next clock tick
   after its one-second minimum delay. No extra download or client binding is
   required. If a normal radio/AMXX menu is already open, defer until it closes.
2. The menu must show M4A1, AK47, MP5 Navy and M3 with short descriptions and
   explain that USP + knife are included. Dismiss it, wait for its 15-second
   timeout, and use `/guns` and team-chat `/weapons` in separate rounds. Each
   dismissal/timeout keeps M4A1/USP/knife and permits a manual choice later in
   that preparation period; it must not automatically reopen repeatedly.
   Specifically stay alone in WAITING, touch no keys for 17 seconds, and confirm
   the old menu disappears without any phase transition or input. `/guns` must
   then reopen a usable menu immediately; dismiss it and wait again to confirm
   no automatic re-opening. Also submit `/guns` just after its 15-second expiry
   before the next clock tick, and verify it replaces the expired owned menu.
3. In four fresh rounds, choose each primary. Confirm exactly that primary,
   USP and knife in the weapon slots. Check normal reloads/unlimited reserve
   ammunition, health/armor unchanged by the choice, and no previous primary
   on the ground or remaining in the inventory. The configured finite reserve
   baselines are 90 M4/AK, 120 MP5, 32 M3 and 100 USP; ReGameDLL's unlimited
   reserve mode may subsequently refill these during play.
4. Try `/guns` repeatedly after choosing and send `menuselect 1/2/3/4` again.
   No second weapon or ammo grant may occur. Try the normal drop key and console
   `drop`, including `drop weapon_m4a1` before changing to another primary: no
   weapon box may be produced. Attempt to collect another player's weapon;
   controlled loadouts must not create dropped weapons through menu selection.
5. Die during preparation after choosing, then naturally respawn. Keep the
   chosen primary and retain the used-choice restriction. In a fresh round,
   die before choosing: a normal human respawn may offer the menu again.

## Invalid state and reset cases

6. Open the menu near the infection deadline and press a selection at/after the
   deadline. All menus must close at infection, including menus belonging to
   surviving humans. Delayed `menuselect` and `/guns` must not alter a survivor's
   loadout or give any zombie a gun. Repeat with an infection caused by actual
   human-controlled knife input while a menu is open.
7. While the menu is open, switch to spectator or die. A selection cannot grant
   weapons or revive the player. Spectators, dead players and active-round late
   joins must never receive a delayed human menu. Normal engine spectator/team
   menus must still work; repeat direct, VGUI and legacy team-lock cases from
   the core acceptance matrix to protect the 0.1.3 engine-return fix.
8. Disconnect with the menu pending/open and reconnect, including reuse of the
   same slot by a different test participant. An old menu choice or pending
   automatic action must not affect the new client. Repeat native round reset,
   `sv_restart 1`, a map change, and a fresh human spawn. Every new round starts
   at the default M4A1 and permits exactly one new choice.
9. Set `kgb_zi_auto_weapon_menu 0`: no automatic menu, but `/guns` still works.
   Set `kgb_zi_weapon_menu 0`: no automatic/manual grants; an already open menu
   must close by the next clock tick and a submitted callback must be rejected
   immediately. Return both to 1 for the remaining tests. Restore test settings.

## Stock zombie night vision

10. As a human, press N: no goggles/effect. Become a zombie through initial
    infection and through genuine knife infection in separate rounds. Goggles
    start off; press N twice with at least 0.3 seconds between presses. The
    stock green effect must turn on and off, without new models/sounds/downloads.
    Confirm the knife-only loadout, speed, gravity and damage behavior still work.
11. Die with zombie NVG enabled, naturally respawn as a zombie and press N
    again. NVG must be off after death, then available initially off on respawn.
    End a round with vision enabled; at round end and next human preparation
    the green effect must be gone and N must not re-enable it. Repeat disconnect
    and map change. No stale green screen may appear on a human or reused slot.
12. With a second genuine client if available, spectate a zombie in first-person
    while it toggles N, dies, leaves, and becomes human next round. Confirm the
    engine's normal observer view updates, with no stale green screen after
    target/round changes. Record this case as untested if only one genuine
    client is available; a fake observer cannot qualify client rendering.
13. Set `kgb_zi_zombie_nightvision 0` before fresh infection/spawn: zombies must
    receive no goggles and N must have no effect. Restore to 1 and start a new
    life. Existing goggles are intentionally not revoked by a mid-life CVar
    change; death/round cleanup still removes them.

## Core regression and removal

Repeat the full core knife conversion, late join/respawn, human timeout win,
zombie win, one-point native score and clean next-round reset checks. Run the
menu/NVG loop on all three selected original infection maps plus a stock
objective map. Inspect AMXX/runtime logs for native errors, invalid menu handles
and leaked cancellation callbacks across several resets. No helper may mutate
human state or synthesize damage to pass these checks.

Reinstall another managed mode and confirm the candidate plugin and its three
new CVars/config entries are removed along with the existing infection runtime
settings. If any required check fails, restore the exact known-good artifact
and configuration; do not release or change Platform's pin. Record any approved
scope exception explicitly with the affected untested case.
