# Public provenance and distribution

Customer addon names were inspected read-only for feature inspiration. No
customer code, configuration or assets are reused or distributed. The 0.2.0
night-vision and weapon-menu implementation is original code using the public
upstream contracts below. No Valve content or third-party custom maps/models/sounds are bundled.
The operator supplies the legally provisioned stock Counter-Strike game files.

## Runtime source

The new `src/kgb_zombie_infection.sma` is a GPL-3.0-or-later derivative of the
publicly accessible KGB Zombie Escape Core, **not customer server files**:

- Public commit: [`9e4b308195a97b7b2b2a67d23dd2d3a991fea872`](https://github.com/KGBHosting/kgb-zombie-escape-core/tree/9e4b308195a97b7b2b2a67d23dd2d3a991fea872).
- [Original source](https://github.com/KGBHosting/kgb-zombie-escape-core/blob/9e4b308195a97b7b2b2a67d23dd2d3a991fea872/src/kgb_zombie_escape.sma),
  SHA-256 `9046300d07eac356f8a28a1a877b84265862845a74330977c94aa1040106f3e9`.
- [GPL license](https://github.com/KGBHosting/kgb-zombie-escape-core/blob/9e4b308195a97b7b2b2a67d23dd2d3a991fea872/LICENSE),
  SHA-256 `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.
- `scripts/build.sh`, compiler matrix/reproducibility scripts and the initial
  release workflow derive from that same licensed public commit. Names, minimum
  supported compiler, warning policy and reproducibility release gate were
  adapted for this independent mode. Attribution and GPL terms are retained.

GPL permits modification/distribution under its terms. This repository provides
the complete corresponding source, license and reproducible build instructions
alongside the separately named development artifact. Existing Escape releases
and identities are untouched.

## Build dependencies (downloaded, not bundled)

`scripts/build.sh` verifies each archive before extraction:

| Dependency | Public pinned artifact | SHA-256 |
| --- | --- | --- |
| AMXX 1.9.0.5303 | [Official base archive](https://www.amxmodx.org/amxxdrop/1.9/amxmodx-1.9.0-git5303-base-linux.tar.gz) | `1ed6898ced2c1fcf225c288b94effc19917e987b284e42911587738ee3c93699` |
| AMXX 1.10.0.5479 | [Official release archive](https://github.com/alliedmodders/amxmodx/releases/download/1.10.0.5479/amxmodx-1.10.0-git5479-base-linux.tar.gz) | `425b53256dbad0ddaeb7935f771d07d85b6c146ed7d1e72d815221042030602d` |
| ReAPI 5.29.0.358 | [Official release archive](https://github.com/rehlds/ReAPI/releases/download/5.29.0.358/reapi-bin-5.29.0.358.zip) | `f33a7435540bea8706db3fa948e51a85b511f5b18c383b97402a204dc5419195` |
| Debian 32-bit compiler container | [Official Debian image](https://hub.docker.com/_/debian) | OCI digest `sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171` |

AMXX's [public include license notice](https://github.com/alliedmodders/amxmodx/blob/13c14c008cd13ddaf053f6f61e22cc231fab93b7/plugins/include/amxmodx.inc)
states GPL version 3 or higher with additional exceptions; see the
[official full license](https://alliedmods.net/amxmodx-license).
ReAPI's [GPL v3 license](https://github.com/rehlds/ReAPI/blob/1c448d06e8c1cebaea061d6b81b94e85f6262649/LICENSE)
and the GPL-3.0-or-later mode permit this GPLv3 combination. These compiler/module
archives and the container image are not redistributed in this project's release.

## Verified engine contracts

These public upstream files were read to avoid guessing engine behavior:

- ReGameDLL_CS [`dist/game.cfg`](https://github.com/rehlds/ReGameDLL_CS/blob/70307312cde05cec5d73a3d3a384b4bdac3d5fe2/dist/game.cfg):
  `mp_round_infinite 1` blocks native scenario endings; `mp_infinite_ammo 2`
  preserves reloads with unlimited reserve; `mp_forcerespawn 0` disables engine
  auto-respawn. SHA-256 `13cd04dea67600f4036e5826485ea413568b2d094dff4f10611aa126ea909a29`.
- ReGameDLL_CS [`wpn_knife.cpp`](https://github.com/rehlds/ReGameDLL_CS/blob/70307312cde05cec5d73a3d3a384b4bdac3d5fe2/regamedll/dlls/wpn_shared/wpn_knife.cpp):
  knife hits pass the player as inflictor/attacker and `DMG_BULLET | DMG_NEVERGIB`.
  SHA-256 `7db100213953c20c04c55579503a4fe36e081472f363ca241f4a47e71e3931bb`.
- ReAPI [5.29.0.358 headers](https://github.com/rehlds/ReAPI/tree/1c448d06e8c1cebaea061d6b81b94e85f6262649/reapi/extra/amxmodx/scripting/include)
  define `rg_round_end`, `m_bFreezePeriod`, `m_iJoiningState` and `JOINED`.
- ReAPI [`natives_misc.cpp` (459–535)](https://github.com/rehlds/ReAPI/blob/1c448d06e8c1cebaea061d6b81b94e85f6262649/reapi/src/natives/natives_misc.cpp#L459-L535):
  `rg_round_end` calls `EndRoundMessage` and `TerminateRound`, without adding a
  scoreboard point. `rg_update_teamscores` adds to the game-rules CT/T counters
  and calls `UpdateTeamScores` to broadcast the display update. Version 0.1.2
  explicitly awards the appropriate point once before termination. SHA-256
  `c1a1d39fb9622b54ea1d1497f222638443739733b1c46c558f18080f62f0d16b`.
- ReGameDLL_CS [`multiplay_gamerules.cpp` (1333–1393)](https://github.com/rehlds/ReGameDLL_CS/blob/70307312cde05cec5d73a3d3a384b4bdac3d5fe2/regamedll/dlls/multiplay_gamerules.cpp#L1333-L1393):
  the native win handlers perform their score increments separately from
  `EndRoundMessage`/`TerminateRound`; draw does not increment. SHA-256
  `3475593b32f99359aac0036d7f11ac52f88995633228da6b0490d36c745a736d`.
- ReGameDLL_CS [`client.cpp`](https://github.com/rehlds/ReGameDLL_CS/blob/70307312cde05cec5d73a3d3a384b4bdac3d5fe2/regamedll/dlls/client.cpp)
  defines the BOOL `HandleMenu_ChooseTeam` hook (1811+) and routes legacy
  `menuselect` (2924+) and direct `jointeam` (3403+) through it. False prevents
  the choice from being handled. SHA-256
  `d912b775263fb69b795ef6ac1daf03507fac4531e61a9fa6c593720d5bf95ac5`.

- ReAPI [`hook_callback.cpp`](https://github.com/rehlds/ReAPI/blob/1c448d06e8c1cebaea061d6b81b94e85f6262649/reapi/src/hook_callback.cpp)
  dispatches `HandleMenu_ChooseTeam` with `callForward<BOOL>`. ReGameDLL's
  engine `BOOL` is an integer, so the ReAPI return-type contract is
  `ATYPE_INTEGER`, not the distinct C++-boolean `ATYPE_BOOL`. A real development
  client team-choice attempt on 0.1.2 exposed native error 10 from
  `SetHookChainReturn`, with expected `ATYPE_INTEGER` / supplied `ATYPE_BOOL`.
  Version 0.1.3 returns integer zero before `HC_SUPERCEDE`; compiler success
  alone cannot catch or qualify this runtime contract.

These references inform implementation. They do not prove that an arbitrary
customer/runtime installation matches the required versions; validate runtime
identity and complete the development gameplay checklist before promotion.

## Version 0.2.0 public interface references

These sources informed API usage; no third-party addon implementation was copied:

- AMXX [`cs_set_user_nvg`](https://www.amxmodx.org/api/cstrike/cs_set_user_nvg),
  [`cstrike.inc`](https://github.com/alliedmodders/amxmodx/blob/844eebd471635c197f5f4fffb71c2ea0628310fd/plugins/include/cstrike.inc)
  (SHA-256 `710d45b89454d4f5818a86ea3f8c6c4aa1cfb4e3d63c79470c79ae397d747031`),
  and [`CstrikeNatives.cpp`](https://github.com/alliedmodders/amxmodx/blob/844eebd471635c197f5f4fffb71c2ea0628310fd/modules/cstrike/cstrike/CstrikeNatives.cpp)
  (SHA-256 `06ce269c1ffbf96caad1c0035c2e433d882c50d3efc2b7c11a6de894abaa09bd`)
  confirm that this native changes goggles ownership, not the active effect.
  Their [license](https://github.com/alliedmodders/amxmodx/blob/844eebd471635c197f5f4fffb71c2ea0628310fd/public/licenses/LICENSE.txt)
  is GPL-3.0-or-later with the published AMXX/Half-Life exceptions (SHA-256
  `421628f28f790d3874b4843eea43ca4b2aa7913779161ef4e33fb408a361746c`).
- ReGameDLL_CS [`client.cpp`, stock nightvision handling](https://github.com/rehlds/ReGameDLL_CS/blob/70307312cde05cec5d73a3d3a384b4bdac3d5fe2/regamedll/dlls/client.cpp#L3447-L3514)
  updates `m_bNightVisionOn` and sends the one-byte `NVGToggle` message. The
  original implementation grants goggles initially off and leaves N toggling
  and observer updates to that engine path. Cleanup clears both ownership and
  active state, including the matching off message.
- ReAPI's pinned [member declarations](https://github.com/rehlds/ReAPI/blob/1c448d06e8c1cebaea061d6b81b94e85f6262649/reapi/extra/amxmodx/scripting/include/reapi_gamedll_const.inc)
  expose the typed `m_bNightVisionOn` boolean and the engine `m_iMenu` /
  `m_iJoiningState` members. No guessed private-data offsets are used.
- Official AMXX [`menu_display`](https://www.amxmodx.org/api/newmenus/menu_display),
  [`menu_cancel`](https://www.amxmodx.org/api/newmenus/menu_cancel),
  [`menu_destroy`](https://www.amxmodx.org/api/newmenus/menu_destroy) and
  [`player_menu_info`](https://www.amxmodx.org/api/newmenus/player_menu_info)
  document the timeout, synchronous cancellation callback, resource ownership
  and old/new menu detection contracts. Engine VGUI menus are separately
  checked through ReAPI before an automatic menu may appear.
- AMXX's pinned [`newmenus.cpp`](https://github.com/alliedmodders/amxmodx/blob/844eebd471635c197f5f4fffb71c2ea0628310fd/amxmodx/newmenus.cpp)
  distinguishes input expiration (`menu_display` stores `menuexpire`) from the
  displayed menu lifetime. `player_menu_info` reports stored menu handles
  without checking expiration. Therefore the mode's existing one-second clock
  closes expired owned menus explicitly, and `/guns` performs the same check
  before testing for other open menus. Both paths retain userid/round ownership
  checks; callbacks additionally reject input at or after the owned deadline.

Public visibility alone is not permission to redistribute code or custom
assets. No Zombie Plague fork, customer plugin or external weapon/menu addon is
bundled. The candidate does not implement Zombie Plague's `zp_*` API and cannot
load its dependent classes, shops, grenades or custom weapons as drop-ins.

## Test-only instrumentation

`tests/live/kgb_zi_acceptance_helper.sma` is first-party GPL-3.0-or-later test
code. It is opt-in, is not shipped as a runtime release asset, and uses only
stock engine fake clients as explicitly labeled test doubles. No customer data,
custom assets or externally sourced code is included. Fake enrollment initializes
the model/class and joining state that fake clients lack; the actual human
completes the normal Valve join flow. Subsequent helpers never change a human's
state or the product's role/loadout. Optional fake-only health setup is labeled
in the output and cannot qualify default health behavior.

AMXX's pinned [`CstrikeNatives.cpp`](https://github.com/alliedmodders/amxmodx/blob/13c14c008cd13ddaf053f6f61e22cc231fab93b7/modules/cstrike/cstrike/CstrikeNatives.cpp#L733-L751)
validates ammo-bearing weapon IDs; the helper avoids asking reserve-ammo for a
knife, which has no ammo index. File SHA-256
`06ce269c1ffbf96caad1c0035c2e433d882c50d3efc2b7c11a6de894abaa09bd`.
