class_name SpawnPlan
extends RefCounted

# Pure decision logic for the stage director (PRD-04).
#
# `SpawnDirector` is a node wired to a Timer and the scene tree, which makes its
# *decisions* awkward to assert. This module lifts those decisions out as pure
# functions — weighted selection, the score-driven interval ramp, the aimed-shot
# anti-frustration gap, the one-shot boss trigger, and the aimed classifier — so
# they can be unit-tested with plain data and no running Timer or scene.
#
# No node, Input, or Timer dependencies. The director keeps the state (RNG,
# last-aimed timestamp, trigger flag); this module only computes the answers.


# Select an index into `weights` for a roll in [0, 1).
#
# `roll_unit` is the caller's random sample (e.g. `randf()`); the function scales
# it across the cumulative weight so a heavier weight claims a wider slice.
# Empty weights return -1. A non-positive total (all zero / negative) degenerates
# to uniform selection so a mis-authored weight array still spawns *something*.
static func weighted_index(weights: Array[float], roll_unit: float) -> int:
	var n: int = weights.size()
	if n == 0:
		return -1
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return clampi(int(roll_unit * n), 0, n - 1)
	var r: float = roll_unit * total
	var cumulative: float = 0.0
	for i: int in n:
		cumulative += weights[i]
		if r <= cumulative:
			return i
	return n - 1


# Current spawn interval for the stage's progress toward the boss.
#
# Lerps `interval_start` → `interval_end` as `stage_score` climbs from 0 to the
# boss threshold, so spawns get tighter as the stage builds. A non-positive
# threshold can't define a ramp, so we return the end (fastest) interval.
static func spawn_interval(
	interval_start: float, interval_end: float, stage_score: int, boss_threshold: int
) -> float:
	if boss_threshold <= 0:
		return interval_end
	var t: float = clampf(float(stage_score) / float(boss_threshold), 0.0, 1.0)
	return lerpf(interval_start, interval_end, t)


# Whether the director may spawn another enemy this tick: the on-screen count is
# still below the concurrency cap. Keeps "max N enemies on screen" from regressing
# into a swarm. Mirrors the director's `_active_enemies < max` guard exactly.
static func can_spawn(active_enemies: int, max_concurrent: int) -> bool:
	return active_enemies < max_concurrent


# Whether an aimed candidate must be suppressed because the last aimed enemy
# spawned too recently (the anti-frustration spacing). A `min_gap` of 0 disables
# the rule, so aimed shots are never blocked.
static func aimed_blocked(now: float, last_aimed_time: float, min_gap: float) -> bool:
	return min_gap > 0.0 and (now - last_aimed_time) < min_gap


# Whether the boss should spawn this frame: at/above the threshold and not yet
# triggered. Pairing the "already triggered" flag in keeps it a one-shot.
static func boss_should_fire(stage_score: int, threshold: int, already_triggered: bool) -> bool:
	return not already_triggered and stage_score >= threshold


# Data-driven aimed classifier: an enemy is "aimed" when its declared primary
# threat tier is AIMED. Replaces the old filename string-match, so renaming or
# adding aimed enemies can't silently break the spacing rule.
static func tier_is_aimed(tier: int) -> bool:
	return tier == ThreatTier.Tier.AIMED
