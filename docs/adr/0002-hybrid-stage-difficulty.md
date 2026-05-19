# Stages use a hybrid scripted-intro + procedural-body difficulty model

Each stage opens with a hand-authored "stage intro" (~30–45 s) — a timeline of spawns that introduces the stage's new enemy or pattern in isolation — then hands off to a procedural body where enemies are drawn from a weighted spawn table with per-stage difficulty knobs (`spawn_rate`, `enemy_weights`, `projectile_speed_mult`, `max_concurrent_enemies`, `min_gap_between_aimed_shots`). Bosses still trigger off the existing score threshold.

We picked this over pure procedural (Level 1 was unplayable for a non-gamer because the opening had no onramp — see [[project-ocelot-target-audience]]) and pure scripted timelines (too much per-level content to maintain, no replay variety). Hybrid gives us a guaranteed gentle onramp where it matters — the first ~30s — and keeps the rest cheap to author per new level via a `.tres` knob set.

Consequence: each new stage needs **both** a scripted intro timeline and a knob set. Adding a new enemy type means deciding which stage's intro will teach it before mixing it into procedural pools.
