## Parent

#1 — Tactical fixes: audio stacking, Stage 1 banner, stage indexing

## What to build

Extend `SoundManager.play_sfx` so that identical sound effects can no longer stack arbitrarily. Two changes to the function:

1. **Per-stream concurrency cap.** If there are already `MAX_PER_STREAM` (= 4) pool players currently playing the same `AudioStream` as the incoming request, the new play is silently rejected. No queue, no fallback.
2. **Pitch jitter.** When a play is accepted, set `player.pitch_scale = randf_range(0.95, 1.05)` so that repeated copies of the same sample decorrelate and stop summing as a single coherent peak.

Both `MAX_PER_STREAM` and the pitch-jitter range live as `const`s at the top of `SoundManager.gd` so they're tunable in one place. Existing pool reuse + dynamic-grow behaviour is unchanged.

End-to-end behaviour: triggering 10 identical explosions in the same frame results in at most 4 simultaneous instances of that sample, each at a slightly different pitch.

## Acceptance criteria

- [ ] `MAX_PER_STREAM` constant exists at the top of `SoundManager.gd` with value 4
- [ ] Pitch jitter range constants exist at the top of `SoundManager.gd` (e.g. `PITCH_JITTER_MIN = 0.95`, `PITCH_JITTER_MAX = 1.05`)
- [ ] `play_sfx` counts currently-playing pool members with matching `stream` and rejects the call when the count is ≥ `MAX_PER_STREAM`
- [ ] On accepted plays, `player.pitch_scale` is set via `randf_range(PITCH_JITTER_MIN, PITCH_JITTER_MAX)`
- [ ] Music playback and the music-crossfade path are not affected
- [ ] Manual verification: triggering a screen-clearing bomb in Level 1 results in ≤ 4 simultaneous copies of the explosion sample with audibly varied pitch

## Blocked by

None — can start immediately.

## Notes

- Independent of slice A; the two layers compound. If A alone resolves the squash subjectively, this slice still ships — the cap is also a correctness guard against future content that spawns many same-stream SFX in a frame (large bombs, screen-clearing power-ups).
