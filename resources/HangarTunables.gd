class_name HangarTunables
extends Resource

# Effect curves + placeholder prices for the four Hangar stat tracks (PRD-08).
# Every magnitude lives here so the catch-up curve (ADR-0010) tunes in a tight
# loop without code. Prior art: PlayerTunables, StageConfig.
#
# Each track is 0→3. The effect arrays are indexed by tier (4 entries, tier 0
# is the all-zero baseline). The price arrays are indexed by *current* tier
# (3 entries: the cost to reach tier 1, 2, 3) — tier 3 is the cap, so there is
# no fourth price. The price arrays are PRD-11's (#39) real tuning surface;
# PRD-08 ships only the conservative flat placeholders below.

# Guns tier is the identity of weapon_level (tier *is* the fire stage), so it
# needs no curve — see HangarUpgrades.guns_floor.
@export var armour_max_hp: Array[int] = [4, 5, 6, 7]
@export var engine_speed_mult: Array[float] = [1.0, 1.08, 1.16, 1.24]
@export var bomb_max: Array[int] = [3, 4, 5, 6]
@export var bomb_blast_mult: Array[float] = [1.0, 1.15, 1.30, 1.45]

# Per-track price curves (PRD-11 grill, 2026-06-03). Index = current tier; value
# = cost to buy the next tier. Guns (60/100/160 = 320) is the spine the base
# income paces. Armour/Engine are *survival slack*: a cheap 50-coin entry so a
# coin-rich-but-shaky player can buy one tier of safety net (ADR-0011's catch-up
# role). Bombs is *expression slack* — priced a touch higher, surplus flex, not a
# lifeline. Two survival tracks to t2 (2×140) exceeds the ~230 clean slack budget,
# so a single Playthrough kits a specialist-with-a-splash, never a maxed board.
@export var guns_prices: Array[int] = [60, 100, 160]
@export var armour_prices: Array[int] = [50, 90, 150]
@export var engine_prices: Array[int] = [50, 90, 150]
@export var bombs_prices: Array[int] = [60, 110, 170]
