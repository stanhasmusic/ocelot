class_name BossState
extends RefCounted

# Pure boss decision logic (PRD-12): the parts tree, the core gate, phase
# resolution, aggregate health, and defeat — no nodes, Input, or Engine. Built
# as data so GUT drives it deterministically (ADR-0004), in the HangarUpgrades /
# GadgetLoadout mould. The Boss node composes parts as a scene and asks this
# brain what is damageable, what phase the fight is in, and whether it has died.
#
# A boss is a tree of parts; exactly one is the core. The non-core parts are the
# weak-points. The core is invulnerable until every weak-point is destroyed (the
# hard gate, distinct from armor). Phases are driven purely by weak-point
# destruction: phase = 1 + (weak-points destroyed), so N weak-points give N+1
# phases and the final phase ("core exposed") is all weak-points gone. A
# mini-boss is the degenerate core-only case and falls out with no special code.
#
# `armor` is carried per part but inert this PRD — PRD-10 makes it bite; damage
# is applied flat (clamped at 0) here.

# Each entry: { id, max_hp, current_hp, is_core, armor }.
var _parts: Array[Dictionary] = []
var _index: Dictionary = {}  # id -> position in _parts


# Register a part. `id` is any unique handle (the Boss passes the child node
# name). Exactly one part should be flagged `is_core`. `max_hp` below 1 is
# clamped to 1 so every part is destroyable.
func add_part(id: Variant, max_hp: int, is_core: bool = false, armor: int = 0) -> void:
	var hp: int = maxi(max_hp, 1)
	_index[id] = _parts.size()
	_parts.append(
		{
			"id": id,
			"max_hp": hp,
			"current_hp": hp,
			"is_core": is_core,
			"armor": maxi(armor, 0),
		}
	)


func has_part(id: Variant) -> bool:
	return _index.has(id)


func part_ids() -> Array:
	var out: Array = []
	for p in _parts:
		out.append(p["id"])
	return out


func is_alive(id: Variant) -> bool:
	return _index.has(id) and _parts[_index[id]]["current_hp"] > 0


func is_core(id: Variant) -> bool:
	return _index.has(id) and bool(_parts[_index[id]]["is_core"])


func current_hp(id: Variant) -> int:
	return int(_parts[_index[id]]["current_hp"]) if _index.has(id) else 0


func weakpoint_count() -> int:
	var n: int = 0
	for p in _parts:
		if not p["is_core"]:
			n += 1
	return n


func destroyed_weakpoint_count() -> int:
	var n: int = 0
	for p in _parts:
		if not p["is_core"] and p["current_hp"] <= 0:
			n += 1
	return n


# True with zero weak-points too (the mini-boss case), so the core is exposed
# from the start there.
func all_weakpoints_destroyed() -> bool:
	return destroyed_weakpoint_count() == weakpoint_count()


# The "core exposed" beat: every weak-point destroyed.
func is_core_exposed() -> bool:
	return all_weakpoints_destroyed()


# The core gate. A living weak-point is always damageable; the core is
# damageable iff every weak-point is destroyed. A dead part is never damageable.
func is_damageable(id: Variant) -> bool:
	if not is_alive(id):
		return false
	if _parts[_index[id]]["is_core"]:
		return all_weakpoints_destroyed()
	return true


# Apply flat damage to a part. Returns { ok, destroyed, current_hp }. A no-op
# (ok=false) against a non-damageable part — a gated core, a dead part, or a
# non-positive amount — leaves all state unchanged.
func apply_damage(id: Variant, amount: int) -> Dictionary:
	if amount <= 0 or not is_damageable(id):
		return {"ok": false, "destroyed": false, "current_hp": current_hp(id)}
	var part: Dictionary = _parts[_index[id]]
	part["current_hp"] = maxi(int(part["current_hp"]) - amount, 0)
	return {
		"ok": true,
		"destroyed": part["current_hp"] == 0,
		"current_hp": int(part["current_hp"]),
	}


# Resolved purely from destroyed weak-points: phase 1 with none destroyed, +1
# per weak-point destroyed. Order-independent (it counts). The final phase
# (all weak-points destroyed → core exposed) equals phase_count().
func current_phase() -> int:
	return 1 + destroyed_weakpoint_count()


func phase_count() -> int:
	return 1 + weakpoint_count()


# Monotonic aggregate: `current` = sum of every part's remaining HP (dead parts
# contribute 0), `max` = sum of every part's HP at spawn.
func aggregate_hp() -> Dictionary:
	var cur: int = 0
	var mx: int = 0
	for p in _parts:
		cur += int(p["current_hp"])
		mx += int(p["max_hp"])
	return {"current": cur, "max": mx}


# True once the core is destroyed. Destroying weak-points alone never defeats.
func is_defeated() -> bool:
	for p in _parts:
		if p["is_core"]:
			return p["current_hp"] <= 0
	return false
