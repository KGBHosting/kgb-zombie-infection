# Optional 0.2.0-r2 manual map smoke — 2026-11-11

These are additional component observations, not release qualification. They
supplement the [earlier edge checks](EXPERIENCE-R2-EDGES-20261111.md) using one
genuine original Valve Steam CS1.6 client and at most three owned, stationary,
explicitly labeled test doubles. Maps were selected with manual `changelevel`:
`zm_kgb_courtyard_v1`, `zm_kgb_depot_v1` and `zm_kgb_containment_v1` from the
canonical 0.1.0 map pack. Managed rotation was not exercised.

The frozen timeout-r2 source (`e88cab68…`) and AMXX 1.9 binary (`fb6049f9…`) were
unchanged. The live configuration remained the retained component configuration
(`60db0a7f…`), not the candidate example (`307eef31…`). Full candidate identities
and the installation-attribution limit remain documented in the earlier note.
No customer content was used.

Independent review of the saved client views, sanitized native events and
operator action records supported seven bounded categories:

1. **Weapon choices.** Fresh manual menus produced genuine selections of AK47
   on Courtyard, MP5 on Depot, M3 after a subsequent native Depot restart, and
   M3 on Containment. Selection confirmations, client views and actual weapon
   state support these choices. Earlier expired automatic-menu attempts are
   excluded. M3 ammunition 8/32 is a client HUD observation, not a validated
   helper reserve-ammunition reading.
2. **Courtyard night vision and respawn.** Native N-key toggling showed the
   zombie view initially off, on and off again. With night vision enabled,
   a native client world death was followed by native zombie respawn about
   3.22 seconds later. The respawned view began off and could be toggled on.
   A subsequent human reset had no green overlay, including after N.
3. **Depot preparation death.** Zombie night vision visibly worked. After
   restart and a confirmed M3 choice, native human world death and respawn
   during preparation retained M3 and the already-used choice: a subsequent
   request was refused. This supports preserving one used choice, not granting
   a second choice after death.
4. **Containment night vision.** On and settled-off views were recorded; a
   partially updated remote frame was rejected as off-state proof. Night vision
   was enabled before the later final infection. A subsequent active-round
   human view and a later waiting human view had no green overlay, including
   the waiting human's N-key attempt. The active-round view is not an immediate
   preparation/reset frame.
5. **Actual knife contacts and win.** In an explicitly extended 1800-second
   test round, the genuine client was initially human and then explicitly
   administrator-infected. Real secondary and primary knife attacks converted
   owned stationary human test doubles into living 3000-HP zombies without
   adding deaths. Native attack/damage events support both contacts. The final
   primary contact changed CT0/T0 to CT0/T1, followed by all four native CT
   spawns about 3.01 seconds later. This was not knife conversion or natural
   initial selection of the genuine client.
6. **Component cleanup.** All owned fixtures disconnected. A later cleanup
   round produced a separate CT1/T1 score; that CT point is not part of the
   final knife win. The client bindings showed F7/F8 unbound; releasing raw
   attack states is operator-reported. The final running snapshot had no
   connected players, waiting mode, twelve slots, default 15/180 timing and
   all three optional feature flags enabled. Four plugins remained running
   at that component snapshot, including the test helpers.
7. **Baseline restoration.** A separate guarded read reported all four temporary
   journals restored, the qualified 0.1.3 core, eight baseline file hashes,
   all fifteen runtime files and marker matching, twelve slots, `de_dust2`
   startup and an offline server. Independent local review matched all eight
   recorded hashes to the earlier baseline and additionally matched the core,
   three canonical maps and dedicated cycle to retained published artifacts.
   Test helpers remained staged only for offline component testing; this is
   not final helper removal or managed-install acceptance.

The following observations remain excluded or limited:

- The unused-choice preparation-death attempt showed an automatic menu behind
  the local pause UI. It does not prove a fresh usable choice or stale-callback
  rejection after death.
- Earlier knife attacks at a 70-unit fixture placement missed. A later close
  setup was near a legitimate 180-second survival timeout. Neither is a
  conversion pass or a calibrated melee-range test.
- The operator recorded restoring 15/180 before the final hit. The retained
  CVar responses confirm those values afterward; their ordering alone does
  not timestamp the setting changes. Client key presses and command timing
  similarly depend on the operator record.

This is one genuine client with stationary test fixtures, not a 32-human or
human-versus-human load test. Managed Reinstall, automatic mapcycle behavior,
a second genuine observer's rendering, different-person slot reuse, live
stale callbacks and disconnect with a demonstrably unexpired or pending menu
remain unqualified. The full [experience acceptance matrix](EXPERIENCE-ACCEPTANCE.md),
release qualification and catalog changes remain separate gates.
