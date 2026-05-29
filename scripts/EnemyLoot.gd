class_name EnemyLoot
extends RefCounted

# Pure loot-drop decision lifted out of `Enemy.drop_loot` (PRD-05).
#
# The roll used to be tangled with `randf()` calls inside the node, so the
# "22% of kills drop something, and bombs are half as likely as the rest" rule
# could only be confirmed by playing. Splitting the decision out makes it
# deterministic and unit-testable: the node rolls the dice, this decides.
#
# Pure: no node, Input, or Engine dependencies; safe to unit-test.

const DEFAULT_DROP_CHANCE: float = 0.22
const DEFAULT_BOMB_KEEP_CHANCE: float = 0.5


# Decide which loot scene (if any) a kill drops.
#   pool             - candidate pickup scenes.
#   drop_roll        - roll in [0,1); below `drop_chance` something drops.
#   pick_roll        - roll in [0,1) selecting which pool member.
#   bomb_roll        - roll in [0,1); a bomb survives only if below
#                      `bomb_keep_chance`, halving bomb drops by default.
# Returns the chosen scene, or null when nothing drops.
static func loot_roll(
	pool: Array,
	drop_roll: float,
	pick_roll: float,
	bomb_roll: float,
	drop_chance: float = DEFAULT_DROP_CHANCE,
	bomb_keep_chance: float = DEFAULT_BOMB_KEEP_CHANCE
) -> PackedScene:
	if pool.is_empty() or drop_roll >= drop_chance:
		return null
	var idx: int = clampi(int(pick_roll * pool.size()), 0, pool.size() - 1)
	var scene: PackedScene = pool[idx]
	if scene == null:
		return null
	if "Bomb" in scene.resource_path and bomb_roll >= bomb_keep_chance:
		return null
	return scene
