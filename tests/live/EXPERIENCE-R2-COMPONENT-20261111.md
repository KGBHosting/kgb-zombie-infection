# Optional 0.2.0-r2 component smoke — 2026-11-11

**Partial live component results, not release qualification.** The optional
candidate was tested on a reserved development server with one genuine original
Valve Steam CS1.6 client and three owned stationary test doubles. The legally
provisioned `hl.exe` remained unchanged. Human joining state was not forced and
no synthetic damage was used. Only stock `de_dust2` was tested for this candidate.

Candidate source SHA-256:
`e88cab68a6e564dea932fffbf5517733d05f74a8a880e794bcc927ffc00fd7ff`

AMXX 1.9 candidate binary SHA-256:
`fb6049f90c86d9f2ab73bfdfe85dc00aecf42ba53e36162bf68c342c259578dd`

The following bounded results were observed:

- Normal VGUI team/class onboarding stayed visible until the client completed
  the native joining flow. The automatic human menu then rendered four choices.
  No-input expiry cleared the HUD; manual reopening worked without an automatic
  reopening loop.
- AK47, MP5 Navy and M3 selections each produced exactly the chosen primary,
  USP and knife, without changing health or armor. Repeated AK47 choice attempts,
  stale selection input and drop commands preserved the chosen inventory.
- AK47 fired and reloaded through real client input; M3 fired through real
  client input. A human's native death/respawn preserved the selected AK47.
- A human could not enable zombie goggles. On the real client, zombie goggles
  started off and the stock N control toggled them on and off. A zombie could
  not use the human menu or a stale selection. Vision cleared on death; natural
  zombie respawn started with vision off and N available again.
- The 180-second human survival deadline awarded exactly one CT point and
  reset normally to a human loadout with vision cleared.
- Infection closed an open weapon menu belonging to a surviving human. Late
  selection input and `/guns` were rejected during active infection.
- Genuine secondary knife attacks converted two owned human test doubles alive
  with 3000 health and no death. The final infection awarded exactly one T point
  and reset normally; enabled vision cleared before reset.

Evidence limits:

- Entry into the real client's zombie role for the NVG check used an explicit
  administrator role fixture, not an attack from a second genuine client.
- The frozen acceptance helper measures reserve ammunition only for M4A1 and
  USP. Its emitted zeros for AK47, MP5 Navy and M3 mean **unmeasured**, not empty
  reserves. Client HUD observations established AK47 90, MP5 Navy 120 and M3 32.
- The helper's attack telemetry covers knife/M4A1. AK47 and M3 firing evidence
  comes from the client observations/screenshots. An M3 frame with 7 of 8 shells
  was observed through computer use, but no standalone fired-frame PNG was kept.
- An M4A1 selection attempt near the deadline is not counted as a verified
  explicit selection. The default M4A1 loadout was verified.
- Legacy onboarding, alternate maps, disabled-feature settings, reconnect and
  slot reuse, spectator rendering with a second genuine client, and the complete
  release acceptance matrix remain unqualified. These results do not replace
  [EXPERIENCE-ACCEPTANCE.md](EXPERIENCE-ACCEPTANCE.md) or the core release gates.

The optional candidate was removed after the smoke check. The qualified 0.1.3
core was restored, the reserved test server was left offline, and the test
doubles were cleared. The managed recipe and Platform pins were unchanged.
This candidate remains local and unreleased.
