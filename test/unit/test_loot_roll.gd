extends GutTest

# Guards the pure loot-drop decision lifted out of Enemy.drop_loot (PRD-05).
# Deterministic: the rolls that used to be live randf() calls are injected, so
# the "22% drop, bombs half as likely" rule is asserted instead of playtested.
# Uses the real pickup scenes so the "Bomb in resource_path" filter is exercised
# against genuine resource paths rather than a hand-made fake.

# A surviving non-bomb pickup stands in for the generic "something dropped"
# case (the legacy PowerUp fixture was retired with PRD-08).
const REPAIR := preload("res://objects/RepairPickup.tscn")
const BOMB := preload("res://objects/BombPickup.tscn")


func test_empty_pool_never_drops() -> void:
	var pool: Array[PackedScene] = []
	assert_null(EnemyLoot.loot_roll(pool, 0.0, 0.0, 0.0), "no candidates, no drop")


func test_roll_above_drop_chance_returns_null() -> void:
	var pool: Array[PackedScene] = [REPAIR]
	# 0.5 >= the 0.22 default drop chance -> nothing drops.
	assert_null(EnemyLoot.loot_roll(pool, 0.5, 0.0, 0.0))


func test_roll_below_drop_chance_returns_a_pool_member() -> void:
	var pool: Array[PackedScene] = [REPAIR]
	assert_eq(EnemyLoot.loot_roll(pool, 0.1, 0.0, 0.0), REPAIR)


func test_pick_roll_selects_across_the_pool() -> void:
	var pool: Array[PackedScene] = [REPAIR, REPAIR]
	# pick_roll near 1.0 selects the last index (clamped, never out of range).
	assert_eq(EnemyLoot.loot_roll(pool, 0.0, 0.99, 0.0), pool[1])
	assert_eq(EnemyLoot.loot_roll(pool, 0.0, 0.0, 0.0), pool[0])


func test_bomb_survives_when_under_the_keep_chance() -> void:
	var pool: Array[PackedScene] = [BOMB]
	# bomb_roll 0.1 < 0.5 keep chance -> the bomb drops.
	assert_eq(EnemyLoot.loot_roll(pool, 0.0, 0.0, 0.1), BOMB)


func test_bomb_is_filtered_when_over_the_keep_chance() -> void:
	var pool: Array[PackedScene] = [BOMB]
	# bomb_roll 0.9 >= 0.5 keep chance -> the bomb is dropped from the drop.
	assert_null(EnemyLoot.loot_roll(pool, 0.0, 0.0, 0.9), "bombs are half as likely")


func test_non_bomb_ignores_the_bomb_roll() -> void:
	var pool: Array[PackedScene] = [REPAIR]
	# A high bomb_roll must not suppress a non-bomb pickup.
	assert_eq(EnemyLoot.loot_roll(pool, 0.0, 0.0, 0.99), REPAIR)


func test_bomb_keep_chance_one_never_filters() -> void:
	var pool: Array[PackedScene] = [BOMB]
	# Truck path passes bomb_keep_chance = 1.0; bombs are never rarity-filtered.
	assert_eq(EnemyLoot.loot_roll(pool, 0.0, 0.0, 0.99, 0.3, 1.0), BOMB)
