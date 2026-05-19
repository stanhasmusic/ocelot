## Parent

#1 — Tactical fixes: audio stacking, Stage 1 banner, stage indexing

## What to build

Retune the SFX and Master bus limiters in the project's audio bus layout so that summed sound effects are tamed by a gentle gain-reduction curve instead of being brick-walled at the ceiling. The current configuration has each limiter's threshold equal to (or within 0.1 dB of) its ceiling, which produces the audible "squash" the player hears during dense combat. New settings give the limiters real headroom to work with.

End-to-end behaviour: during a screen-clearing bomb in Level 1 (≥6 simultaneous explosions), music should remain at perceived full volume and individual explosions should remain identifiable, without the master mix audibly pumping.

Settings:

- SFX bus limiter: `threshold_db = -8.0`, `ceiling_db = -1.0`
- Master bus limiter: `threshold_db = -3.0`, `ceiling_db = -0.5`

No code changes; this is a pure config edit to `resources/default_bus_layout.tres`.

## Acceptance criteria

- [ ] SFX bus `AudioEffectLimiter` has `threshold_db = -8.0` and `ceiling_db = -1.0`
- [ ] Master bus `AudioEffectLimiter` has `threshold_db = -3.0` and `ceiling_db = -0.5`
- [ ] No other audio routing changes (Music and SFX still send to Master; bus volumes unchanged)
- [ ] **HITL merge gate**: PR must be reviewed by Stan with a listening test in the editor before merge. Trigger a screen-clearing bomb in Level 1; confirm no audible pump on music and no clipping artefacts on the explosion sum.

## Blocked by

None — can start immediately.

## Notes

- HITL: requires human listening test before merge (the difference between "good" and "good enough" here is subjective and only checkable by ear).
- If the listening test reveals the bus retune alone is insufficient, slice B (source-side concurrency cap) is the next layer — it's already a separate ticket, so no scope expansion here.
