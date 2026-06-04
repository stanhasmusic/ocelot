extends GutTest

# PRD-11 — the pure payout module (CoinEarnings): floor top-up, no-death bonus,
# first-clear gate, and terminal coins→score cash-out. Same "assert external
# behaviour, not private state" discipline as the PRD-07/08 tests; no autoload or
# scene dependencies — a fresh EconomyTunables.new() carries the seeded budget
# (base_income [70,110,170,200], no_death_bonus [30,40,50,60], rate 10).

var _t: EconomyTunables


func before_each() -> void:
	_t = EconomyTunables.new()


# --- floor_topup ---

func test_topup_fills_the_whole_floor_when_nothing_collected() -> void:
	assert_eq(CoinEarnings.floor_topup(0, 0, _t), 70, "collect 0 → topped up to the full L1 floor")


func test_topup_fills_only_the_shortfall_below_floor() -> void:
	assert_eq(CoinEarnings.floor_topup(50, 0, _t), 20, "collect 50 of a 70 floor → 20 top-up")


func test_topup_is_zero_at_or_above_floor() -> void:
	assert_eq(CoinEarnings.floor_topup(70, 0, _t), 0, "collect exactly the floor → no top-up")
	assert_eq(CoinEarnings.floor_topup(100, 0, _t), 0, "above the floor → no top-up (overage kept)")


func test_topup_reads_per_level_floor() -> void:
	assert_eq(CoinEarnings.floor_topup(0, 1, _t), 110, "L2 floor is 110")
	assert_eq(CoinEarnings.floor_topup(0, 2, _t), 170, "L3 floor is 170")


func test_topup_clamps_out_of_range_level_to_nearest_floor() -> void:
	assert_eq(CoinEarnings.floor_topup(0, 99, _t), 200, "a level past the table reads the last floor")


# --- no_death_bonus ---

func test_no_death_bonus_paid_on_a_clean_clear() -> void:
	assert_eq(CoinEarnings.no_death_bonus(0, false, _t), 30, "clean L1 clear pays the +30 bonus")
	assert_eq(CoinEarnings.no_death_bonus(2, false, _t), 50, "clean L3 clear pays the +50 bonus")


func test_no_death_bonus_zero_when_died() -> void:
	assert_eq(CoinEarnings.no_death_bonus(0, true, _t), 0, "a death forfeits the bonus")


# --- level_payout (floor top-up + no-death, behind the first-clear gate) ---

func test_first_clear_clean_pays_floor_plus_bonus() -> void:
	# collect 0, clean, first clear of L1 → 70 floor + 30 bonus = 100 added.
	assert_eq(CoinEarnings.level_payout(0, 0, false, false, _t), 100, "clean clear pays floor + bonus")


func test_first_clear_with_death_pays_floor_only() -> void:
	assert_eq(CoinEarnings.level_payout(0, 0, true, false, _t), 70, "a death keeps the floor only")


func test_first_clear_above_floor_adds_only_the_bonus() -> void:
	# collect 100 (above the 70 floor): top-up is 0, so only the +30 bonus is added
	# (the 100 collected is already in the wallet, not part of this return).
	assert_eq(CoinEarnings.level_payout(100, 0, false, false, _t), 30, "above floor: bonus only")


func test_already_cleared_level_pays_nothing() -> void:
	assert_eq(CoinEarnings.level_payout(0, 0, false, true, _t), 0, "replay banks nothing (clean run)")
	assert_eq(CoinEarnings.level_payout(500, 0, false, true, _t), 0, "replay banks nothing (collect)")


# --- score_cashout ---

func test_cashout_converts_unspent_coins_at_the_rate() -> void:
	assert_eq(CoinEarnings.score_cashout(50, _t), 500, "50 unspent coins → 500 score at rate 10")


func test_cashout_of_nothing_is_zero() -> void:
	assert_eq(CoinEarnings.score_cashout(0, _t), 0, "no unspent coins → no score bonus")
	assert_eq(CoinEarnings.score_cashout(-5, _t), 0, "a negative wallet never yields negative score")
