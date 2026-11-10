# KGB Zombie Infection

An independent **classic infection** gamemode for Counter-Strike 1.6, using
stock maps and assets. Version **0.1.1 is a development candidate**. Compiler and
source checks do not prove live gameplay; see [TESTING.md](TESTING.md).

Humans start together with an M4A1, USP, knife, 100 health and 50 armor. After a
15 second preparation countdown, a shuffled 20% of the living players become
zombies (at least one; always leave one human). Zombies have a knife, 3000 health,
300 speed, reduced gravity and a green glow. A direct zombie knife hit converts
a human immediately. Humans must survive for three minutes; zombies win when
no living humans remain. Killed players and late joins return as zombies after
three seconds. Zombies keep respawning, so killing one does not end the round.
Human weapons reload normally with unlimited reserve ammunition.

Spectators stay spectators. Waiting for enough players is automatic; joins
restart the preparation countdown without requiring an administrator. The HUD
shows preparation/survival time and living role counts; `/zombie` explains the
rules. Team switching is locked during infection, except switching to spectator.

Version 0.1.1 enforces the active-round team lock at ReGameDLL's shared
`HandleMenu_ChooseTeam` hook. Direct commands, VGUI and legacy text menus now
reach the same decision; spectating stays allowed. Version 0.1.0's command-only
lock could be bypassed through legacy `menuselect`; its immutable release is
retained for provenance, and development installs should use 0.1.1.

This is not Zombie Escape: there are no escape objectives, zombie classes,
bosses, custom maps, models, sounds, shop/economy or FastDL dependencies.

## Install on a development server

Requirements: legally provisioned Counter-Strike 1.6 server assets,
ReGameDLL_CS exposing `mp_round_infinite`, ReAPI **5.29.0.358+**, AMX Mod X
**1.9.0.5303+**, and its CStrike, Fakemeta, Fun and Ham Sandwich modules.
Do not run another core gamemode, respawn manager, team manager or weapon/loadout
plugin alongside this mode.

1. Run `./scripts/build.sh`, or obtain the AMXX and SHA-256 sidecar from the
   matching development release. Verify the sidecar before installation.
2. Copy `compiled/kgb_zombie_infection.amxx` into
   `cstrike/addons/amxmodx/plugins/` and enable it in `plugins.ini`.
3. Copy `configs/kgb_zombie_infection.cfg.example` to
   `cstrike/addons/amxmodx/configs/kgb_zombie_infection.cfg`.
4. Restart on a stock map such as `de_dust2`, then check `amxx plugins`,
   `amxx modules` and `amx_zi_status`. The plugin fails closed if the required
   `mp_round_infinite 1` is missing.

ReGameDLL's `mp_round_infinite 1` disables native scenario round endings.
Only this plugin's survival/infection outcomes end these rounds. Its sample
configuration also disables purchases, C4, map weapons and automatic engine
respawns. **Restore the previous server CVars when removing this standalone
plugin**, or reinstall a different managed gamemode. The Panel managed recipe
owns these values when installed through KGB Platform.

`amx_zi_status` reports the current phase, counts and remaining survival time.
`amx_zi_infect <name or #userid>` requires AMXX configuration access and only
works on living humans during an active infection; it cannot skip preparation.
AMXX logs contain aggregate start/end outcomes, not player names or identifiers
except an explicitly requested admin infection's user IDs.

## Configuration

All defaults are in the example configuration. Values are bounded in code:

| CVar suffix (`kgb_zi_`) | Default | Accepted range |
| --- | --- | --- |
| `min_players` | 2 | 2 to server capacity |
| `infection_delay` | 15 seconds | 3–120 seconds |
| `survival_time` | 180 seconds | 15–1800 seconds |
| `zombie_ratio` | 0.20 | 0.05–0.90; at least one human remains |
| `zombie_health` | 3000 | 100–100000 |
| `zombie_speed` | 300 | 150–400; respect `sv_maxspeed` |
| `zombie_gravity` | 0.80 | 0.25–1.00 |
| `human_health` | 100 | 1–1000 |
| `human_armor` | 50 | 0–1000 |
| `respawn_delay` | 3 seconds | 1–30 seconds, evaluated on a 1 second tick |

`display_name` and `chat_prefix` control player-facing branding. Changing the
preparation/survival duration takes effect on the next phase; role stats take
effect on the next spawn/infection. There is no unsafe live enable/disable toggle.

## Build and checks

Docker, curl, unzip, tar and Python 3 are needed. The build downloads only
checksum-pinned public official AMXX/ReAPI archives. The 32-bit compiler runs in
a digest-pinned, network-disabled, read-only Debian container.

```sh
./scripts/check-source-capabilities.sh
./scripts/check-compatibility.sh     # AMXX 1.9 and 1.10; warnings are errors
./scripts/check-reproducibility.sh   # two independent clean AMXX 1.9 builds
```

The oldest supported compiler (1.9) produces the release artifact. The release
workflow repeats both compiler checks and independent reproducibility, then
publishes a clearly marked prerelease. Compiler caches and AMXX binaries are
ignored in Git. [PROVENANCE.md](PROVENANCE.md) records sources and licenses.

## License

GPL-3.0-or-later. Derived from the publicly available KGB Zombie Escape Core
0.1.3, with attribution and provenance retained. No customer code, configuration
or assets were consulted or copied. Valve game content is not redistributed.
