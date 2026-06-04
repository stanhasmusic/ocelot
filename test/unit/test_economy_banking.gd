extends GutTest

# PRD-11 — the GameManager banking seam (bank_level_payout) that gates the
# first-clear payout. Exercises the autoload like test_coin_banking; saves and
# restores the wallet, run tally, first-clear ledger, and death flag so the suite
# leaves no residue and never touches disk (bank_level_payout itself never saves).
# Reads the seeded EconomyTunables (L1 floor 70 / +30 no-death, L2 floor 110).

var _saved_coins: int
var _saved_run_coins: int
var _saved_cleared: Array
var _saved_died: bool


func before_each() -> void:
	_saved_coins = GameManager.coins
	_saved_run_coins = GameManager.run_coins
	_saved_cleared = GameManager.cleared_levels.duplicate()
	_saved_died = GameManager.died_this_level
	# Start each case from a clean, un-cleared, no-death slate.
	GameManager.coins = 0
	GameManager.run_coins = 0
	GameManager.cleared_levels = []
	GameManager.died_this_level = false


func after_each() -> void:
	GameManager.coins = _saved_coins
	GameManager.run_coins = _saved_run_coins
	GameManager.cleared_levels = _saved_cleared
	GameManager.died_this_level = _saved_died


# --- first clear ---

func test_first_clean_clear_banks_floor_plus_bonus_and_marks_cleared() -> void:
	GameManager.run_coins = 0
	GameManager.bank_level_payout(0)
	assert_eq(GameManager.coins, 100, "no-collect clean clear banks the L1 floor + bonus")
	assert_eq(GameManager.run_coins, 0, "the run tally is cleared")
	assert_true(GameManager.cleared_levels.has(0), "the level is recorded in the first-clear ledger")


func test_first_clear_keeps_above_floor_overage_plus_bonus() -> void:
	GameManager.run_coins = 100  # above the 70 floor
	GameManager.bank_level_payout(0)
	assert_eq(GameManager.coins, 130, "the 100 collected is kept, only +30 bonus added (no clawback)")


func test_death_forfeits_the_bonus_but_keeps_the_floor() -> void:
	GameManager.died_this_level = true
	GameManager.run_coins = 0
	GameManager.bank_level_payout(0)
	assert_eq(GameManager.coins, 70, "a death banks the floor only, no no-death bonus")


# --- the first-clear gate (anti-grind) ---

func test_replaying_a_cleared_level_banks_nothing() -> void:
	GameManager.cleared_levels = [0]
	GameManager.run_coins = 50
	GameManager.coins = 200
	GameManager.bank_level_payout(0)
	assert_eq(GameManager.coins, 200, "replaying a cleared level banks nothing — farm stays closed")
	assert_eq(GameManager.run_coins, 0, "the run tally is still cleared on a replay")


func test_each_level_is_gated_independently() -> void:
	GameManager.bank_level_payout(0)  # L1 first clear: +100
	GameManager.run_coins = 0
	GameManager.bank_level_payout(1)  # L2 first clear: floor 110 + bonus 40 = 150
	assert_eq(GameManager.coins, 250, "a fresh level still pays out after an earlier one was banked")
	assert_true(GameManager.cleared_levels.has(1), "L2 is now recorded too")
