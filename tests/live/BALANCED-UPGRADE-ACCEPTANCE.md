# 0.2.1 balanced Zombie upgrade acceptance

Status: **NOT RUN**. This is a reviewable development test plan, not a receipt.
The previous draft 0.2.0 observations retain their original artifact and scope.
No new core release, Platform pin or managed installation is qualified here.

Use only the reserved development target and a legally provisioned Valve Steam
client. Record exact source commit, configuration and installed AMXX SHA256,
15-file runtime/marker, plugin/module inventory and map. Keep credentials,
addresses, account/Steam identifiers and unrelated names out of evidence.
Preserve the qualified core/configuration and test-owned changes for guarded
restoration. Do not touch a customer server or use customer files/settings.

## Behavior and interfaces

- `/guns` and `/weapons` in normal/team chat choose one of M4A1, AK47, MP5 Navy
  or M3, with USP/knife, once per human round before infection. No health/armor
  refresh, repeated inventory grant or dropped weapon is permitted.
- The current primary appears in the menu and the human spawn hint. Ignoring or
  dismissing the menu keeps it. Preparation death preserves it and the used
  choice. The next native round retains the primary and grants one fresh choice.
- `kgb_zi_remember_weapons 1` remembers only for this connection. Disconnection,
  slot reuse and map/plugin reload start at M4A1. With either this flag or
  `kgb_zi_weapon_menu` at 0, the next round returns to M4A1. Mid-life flag changes
  do not grant weapons or clear a used choice.
- Existing `kgb_zi_weapon_menu`, `kgb_zi_auto_weapon_menu` and
  `kgb_zi_zombie_nightvision` remain default 1. All previous core gameplay
  settings remain unchanged. The new remember flag is also default 1.
- Zombie NVG starts off; native `nightvision`/N toggles it. Cleanup clears the
  owner and exact connected first-person followers' active effects, preserving
  observer goggles ownership. Other targets/modes are untouched.
- `/zombie` remains the rules/status command. A shared menu may dispatch these
  exact commands; it must not implement another inventory or NVG controller.

## Focused genuine-client checks

1. Complete native VGUI and legacy `setinfo _vgui_menus 0` team/class onboarding.
   Leave an onboarding menu open beyond two ticks and verify deferral. Confirm
   the first-life M4A1, automatic menu/current hint, 15-second visible expiry,
   manual `/guns` reopening, and no automatic reopening loop. Repeat with the
   automatic flag off and with an existing radio/AMXX menu.
2. Choose AK47, MP5 and M3 across native rounds; explicitly select M4A1 once.
   Observe primary + USP/knife, normal firing/reload/reserve HUD and unchanged
   health/armor. Retry `/guns`, raw selections and drop: no second grant/box.
   After each native reset, verify the prior primary is granted automatically
   and exactly one different choice works. Expiry/dismissal keeps the remembered
   primary. Existing stationary fake helpers do not measure every weapon's
   reserve; use the genuine HUD or explicit supported measurement.
3. After choosing, die during preparation and naturally respawn: same primary,
   no new choice. In a later round die while the choice is unused: a fresh
   usable choice remains available after the ordinary human respawn. Observe
   both actual selection and inventory; a menu frame alone is insufficient.
4. Demonstrate pending/open menu disconnect **before its known 15-second expiry**,
   then normal reconnect. The same person starts with M4A1 and a fresh choice.
   With a second authorized genuine person if available, reuse the slot and
   repeat. Attempt delayed old input after reconnect/round reset; no old grant
   or pending action may affect the new owner. State any unavailable second-
   person/stale-callback case explicitly; do not infer it from a team menu.
5. Open a menu at the infection deadline, select at/after expiry, and convert a
   menu-owning human with genuine knife input. Infection closes all owned menus;
   zombies/surviving humans/dead/spectator clients cannot choose. Repeat the
   direct and legacy active team lock and spectator allowance.
6. Toggle remember off before native reset: M4A1 returns and one choice remains.
   Select another primary, die in preparation, verify that round's choice still
   persists. Restore remember, select a primary, disable menus and reset: M4A1
   returns and requests/callbacks cannot grant. Restore flags afterward.
7. As a genuine zombie, use native N off/on/off and check initially-off respawn,
   death, normal human reset, disconnect/reconnect and map change. Disable NVG
   before a fresh infection: no goggles/overlay. Restore before continuing.
8. With a genuine first-person observer, toggle the observed zombie's native N,
   then exercise cleanup through round end, target death and target leaving.
   The observer must lose the green overlay immediately at cleanup and keep
   normal target/mode behavior. Verify an unrelated target/chase observer is
   unaffected. One genuine observer plus a strictly fake-owned, native-command
   test fixture can qualify observed rendering only if its setup is explicit;
   a fake observer alone cannot. Record this case untested without an actual
   observer client. No helper may write a human's role, view or inventory.

## Integration and representative regression

Boot the exact candidate with the exact intended configuration on the three
canonical infection maps, verify ordinary onboarding and one choice/reset loop
on each. Confirm representative genuine knife conversion, native death/respawn,
unshortened 180-second human survival, final-human infection, single-point win
and normal reset, with no AMXX/runtime faults. Source review must establish that
unchanged round/damage/score contracts match the retained earlier evidence;
repeat additional core cases when a new change, failure or concern justifies it.
Do not call prior component evidence a new managed installer acceptance.

After the coordinated Platform recipe exists, require its actual UI install,
exact runtime/core/config/maps, remembered-choice setting, helper absence,
startup/history identity and normal boot/genuine join. Perform managed removal
and reinstall ownership checks for the new identity. Preserve edited user files
and startup choices. Restore all temporary fixtures/CVars/bindings and the
approved baseline; verify restoration independently. No source, artifact or
release is approved solely by compiler tests or this plan.
