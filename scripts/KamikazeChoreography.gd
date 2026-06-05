class_name KamikazeChoreography
extends RefCounted

# Pure choreography math for the Kamikaze wing (PRD-13), in the SpawnPlan /
# IntroSchedule / BossState mould: no nodes, Input, or Engine — just geometry and
# a schedule, so GUT drives it deterministically (ADR-0004). The `KamikazeWing`
# coordinator consumes these to lay out its formation and time its staggered
# dives; the dive *line* itself reuses the already-tested
# `FirePattern.aimed_direction` at the commit instant.
#
# Two answers live here:
#   - formation layout: `(count, spacing, shape) -> member offsets about the anchor`
#   - commit schedule:   `(count, hold, stagger) -> per-member commit times`

# Formation shapes. VEE is the default signature look (a centred chevron, tip
# toward the player); LINE is the degenerate flat row, handy as a fallback and to
# keep the `shape` parameter honestly meaningful.
enum Shape { VEE, LINE }

# How far each step out from centre also trails *back* (down, +y) in a VEE, as a
# fraction of `spacing`. Internal aesthetic of the chevron, not a feel knob.
const VEE_DEPTH_RATIO: float = 0.5


# `count` member offsets relative to the wing anchor, symmetric about it.
#
# Lane `i - centre` places each member left/right of centre at `lane * spacing`;
# in a VEE the |lane| also trails back so the formation reads as a chevron. A
# single member sits exactly on the anchor. Spacing scales the whole spread
# linearly. `count <= 0` returns empty.
static func member_offsets(count: int, spacing: float, shape: Shape) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 0:
		return out
	var centre: float = (count - 1) / 2.0
	for i in count:
		var lane: float = i - centre
		var x: float = lane * spacing
		var y: float = 0.0
		if shape == Shape.VEE:
			y = absf(lane) * spacing * VEE_DEPTH_RATIO
		out.append(Vector2(x, y))
	return out


# `count` per-member commit times: the first member commits after `hold_time`
# (the settle beat once the formation is formed), each subsequent member
# `stagger_gap` later. Monotonic for a positive gap, so dives land one at a time
# down the formation. `count <= 0` returns empty; `count == 1` yields a single
# time at `hold_time`.
static func commit_times(count: int, hold_time: float, stagger_gap: float) -> Array[float]:
	var out: Array[float] = []
	for i in count:
		out.append(hold_time + i * stagger_gap)
	return out
