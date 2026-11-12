# Optional 0.2.0-r2 edge component smoke — 2026-11-11

**Partial live edge results, not release qualification.** This supplements
[the earlier component smoke](EXPERIENCE-R2-COMPONENT-20261111.md) without changing
its historical results. The same frozen optional candidate was exercised on a
reserved development server with one genuine original Valve Steam CS1.6 client
and explicitly labeled stationary test doubles where recorded. Only stock
`de_dust2` was tested. No customer files or client game binaries were changed.

Candidate source SHA-256:
`e88cab68a6e564dea932fffbf5517733d05f74a8a880e794bcc927ffc00fd7ff`

AMXX 1.9 candidate binary SHA-256:
`fb6049f90c86d9f2ab73bfdfe85dc00aecf42ba53e36162bf68c342c259578dd`

Candidate example configuration (not deployed in these live checks), SHA-256:
`307eef31a1125a2fe20cf22fed75e1fb63cf10ae1a53e9ae77cfa7eaf38a7225`

The live checks retained the previous component configuration, SHA-256
`60db0a7f88322c9eb058b975d18a7eb22e439336701557628b6ff5485e733cb6`.
The three feature CVars were varied through controlled runtime commands; all
three were last recorded at 1. The candidate example file was not staged.

Independent review matched the retained local source and binary hashes. The
live binary identity relies on the operator's recorded installation of those
same frozen bytes; the evidence review was not a fresh live binary attestation.

The following bounded results were supported by the retained client views,
server snapshots and operator action records:

- Native legacy team and class menus remained visible across captures separated
  by more than two clock ticks. The weapons menu appeared after the normal
  team/class sequence, followed by an alive, joined human with M4A1/USP/knife.
  This qualifies one observed legacy onboarding sequence on this map.
- With `kgb_zi_auto_weapon_menu 0` and the weapon menu enabled, a fresh round
  retained the normal M4A1 loadout without automatic opening. A subsequent real
  manual `/guns` request displayed the weapons menu. Unsubmitted console text
  and an earlier frame containing no menu were excluded as successful requests.
- Disabling `kgb_zi_weapon_menu` closed a visible owned menu in the supported
  before-expiry sequence. This attribution combines the operator's record of
  a fresh manual open and subsequent disable action with a 12.09848-second
  capture-save gap, shorter than the 15-second timeout. The screenshots alone
  do not timestamp menu creation; no exact next-tick closing latency is claimed.
- A human's manual request while `kgb_zi_weapon_menu 0` produced no weapons
  menu. After re-enabling it, native team chat `/weapons` displayed the menu.
  The operator reported selecting M4A1 with the real key and repeating `/guns`;
  the menu did not reopen, and the human retained exactly M4A1/USP/knife with
  100 health and 50 armor. Because M4A1 is also the default, explicit-choice
  attribution requires that visible menu sequence and action record, not
  inventory alone. This supports one repeat rejection, not exhaustive spam.
- With `kgb_zi_zombie_nightvision 0` set before a fresh infection, the genuine
  client became a knife-only zombie and a real N-key attempt produced no green
  night-vision overlay. Infection used an explicit administrator role fixture.
  This tests a disabled fresh grant, not combat conversion or revocation from
  an already-equipped living zombie.
- The operator-reported same genuine player disconnected and reconnected with
  a new temporary user ID in the same server slot. Native team/class onboarding
  and the default M4A1 loadout were followed by a fresh manual M3 choice, with
  exactly M3/USP/knife and 100 health/50 armor. The client HUD visibly showed
  M3 ammunition 8/32. The frozen helper does not measure M3 reserve ammunition;
  its zero is an unmeasured sentinel. This qualifies the observed new connection
  and fresh choice for the same person, not a different genuine slot occupant.
- At the last retained candidate snapshot, all three feature flags were back
  at 1, the genuine client had disconnected, and no owned test doubles remained
  connected. The mode was waiting with zero participants.

Remaining evidence limits:

- A weapon menu was visible before a disconnect, but the saved timing does
  **not** prove the disconnect happened while that menu was still unexpired.
  Disconnect with an unexpired open menu or a pending automatic menu, and
  subsequent stale-callback rejection, remain unqualified. A reconnect frame
  showing a native team selector is not stale-callback proof.
- A different genuine person reusing the slot, a second genuine observer's
  night-vision rendering/cleanup, the three original infection maps, and the
  complete core and experience matrices remain unqualified for this candidate.
- Capture-save times support the recorded sequences; they are not embedded
  server command timestamps. No exhaustive timing, concurrency or phase-race
  coverage is claimed.

A separate guarded restoration record verified the previous 0.1.3 core and all
eight retained baseline files, the pinned runtime and marker, a 12-slot
`de_dust2` startup, restored temporary settings, and an offline server. The three
owned test doubles had been cleared. Test-only helper binaries remained staged
for component use; this does not claim final helper removal or a managed
reinstall. The candidate remains unreleased, with no Platform pin change.
These observations do not replace [EXPERIENCE-ACCEPTANCE.md](EXPERIENCE-ACCEPTANCE.md)
or the core release gates.
