class_name CoinEarnings
extends RefCounted

# Pure payout math for the coin economy (PRD-11), the payout-side mirror of
# HangarUpgrades (which owns the price side). Static functions, no node / scene /
# autoload dependencies, so the floor top-up, the no-death bonus, the first-clear
# gate, and the score cash-out all unit-test deterministically (ADR-0004). The
# GameManager seam rolls the wiring; this decides. Every magnitude is read from
# EconomyTunables, per-level arrays indexed 0→N for L1→Ln.


# The floor top-up: the shortfall between a level's base-income floor and what the
# player collected this level — max(0, floor - collected). Collecting at or above
# the floor tops up nothing (the overage is kept as slack, never clawed back), so
# missing pickups costs slack, never the guaranteed Guns-pacing floor.
static func floor_topup(collected: int, level_idx: int, tunables: EconomyTunables) -> int:
	var floor_income: int = _at(tunables.base_income, level_idx)
	return maxi(0, floor_income - collected)


# The survival faucet: the per-level bonus for clearing a level without a death,
# or 0 if the player died anywhere in the level. Per-level, so a run that dies
# late still keeps the bonus for the earlier levels it cleared cleanly.
static func no_death_bonus(level_idx: int, died_this_level: bool, tunables: EconomyTunables) -> int:
	if died_this_level:
		return 0
	return _at(tunables.no_death_bonus, level_idx)


# The total *added* payout banked at a clear, on top of whatever the player
# already collected into the wallet: floor top-up + no-death bonus. The
# first-clear gate — a level already cleared this Playthrough banks 0, regardless
# of collection or clean play, so replaying a level can never re-open a coin farm.
static func level_payout(
	collected: int, level_idx: int, died: bool, already_cleared: bool, tunables: EconomyTunables
) -> int:
	if already_cleared:
		return 0
	return floor_topup(collected, level_idx, tunables) + no_death_bonus(level_idx, died, tunables)


# The terminal coins→score bridge: on campaign completion every unspent coin
# converts to a one-time score bonus at the tunable rate. One-way and terminal;
# coins and score stay distinct during play.
static func score_cashout(unspent_coins: int, tunables: EconomyTunables) -> int:
	return maxi(0, unspent_coins) * tunables.coin_to_score_rate


# Read a per-level array at a level index, clamping the index so a level outside
# the table's range reads the nearest end value instead of indexing out of range.
static func _at(arr: Array, level_idx: int) -> int:
	if arr.is_empty():
		return 0
	return int(arr[clampi(level_idx, 0, arr.size() - 1)])
