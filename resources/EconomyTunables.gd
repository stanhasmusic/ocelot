class_name EconomyTunables
extends Resource

# The *payout* side of the economy (PRD-11, #39), the lockstep partner to the
# *price* side in HangarTunables / GadgetCatalog. Every magnitude lives here so
# the budget tunes in a tight loop without code, in the HangarTunables mould.
# Grilled 2026-06-03 against ADR-0011 (Guns spine + two bounded skill faucets).
#
# All per-level arrays are indexed 0→3 for L1 (Beachhead) → L4 (Naval finale).
# There are 4 levels but only 3 Hangar visits (none after the L4 finale), so
# L1–L3 income is spendable and L4 income is stranded — it cashes to score via
# coin_to_score_rate (the terminal coins→score bridge).

# --- Base income: the guaranteed Guns-pacing floor ---
# Topped up at level-complete: collect coins during the level, and if the run
# total is below this floor you are topped up to it. So even a no-collect,
# die-every-level run affords Guns 0→3 (60/100/160 = 320). Cumulative L1–L3 floor
# = 350, a thin ~30 margin over Guns. Missing coins costs slack, never Guns.
@export var base_income: Array[int] = [70, 110, 170, 200]

# --- No-death bonus: the survival faucet ---
# Awarded per-level when that level is cleared without a death (per-level so a
# run that dies in L3 still banks L1+L2 if those were clean). Sum L1–L3 = 120 of
# the ~230 clean slack budget. L4's bonus routes to score. This is a playerbase
# dial — raise it if playtests find slack too scarce for the audience.
@export var no_death_bonus: Array[int] = [30, 40, 50, 60]

# --- Collection pool: the engagement faucet ---
# Coins droppable *above* the base_income floor per level (ambient drops +
# Convoy bursts). Collecting them is kept as slack; a messy-but-grabby player can
# still turn this faucet (you collect before you die), which is how a shaky
# player gets coin-rich enough to buy survivability (ADR-0011). Sum L1–L3 = 110,
# the other half of the ~230 budget — realized in full only by an engaged /
# Coin-Magnet player; without the Magnet you realize roughly half.
@export var collection_pool: Array[int] = [30, 40, 40, 90]

# --- Convoy: the risk/reward spike inside the collection pool ---
# Each convoy unit (path-following ground traffic, ADR-0009/PRD-05) drops one
# guaranteed coin of this value — the reward is the whole point, so convoy units
# skip the random loot roll. ~1 convoy of ~4 units per level ≈ half the
# collection pool. Placement / escape timers belong to the level PRDs (13/14).
@export var convoy_coin_value: int = 6

# --- Terminal coins→score bridge ---
# At campaign completion, every unspent coin converts to a one-time score bonus
# at this rate (the arcade end-of-run mop-up). Kept a modest mop-up rate so
# hoarding-for-score never competes with spending-to-survive.
@export var coin_to_score_rate: int = 10
