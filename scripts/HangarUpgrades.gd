class_name HangarUpgrades
extends RefCounted

# Pure purchase + tier→effect math for the Hangar stat tracks (PRD-08), in the
# SaveGame / CheckpointState mould: static functions, no node / Input / Engine
# dependencies, so affordability, the tier cap, and effect application all
# unit-test deterministically (ADR-0004). The Hangar node rolls the UI; this
# decides. The four magnitude/price curves live in HangarTunables.

const MAX_TIER: int = 3
const TRACKS: Array[String] = ["guns", "armour", "engine", "bombs"]


# Current tier of a track, defaulting a missing key to 0 — so an empty
# owned_tiers (fresh Playthrough / pre-PRD-08 save) reads as all-zero with no
# migration.
static func tier_of(owned_tiers: Dictionary, track: String) -> int:
	return int(owned_tiers.get(track, 0))


# Price to buy the *next* tier of a track from its current tier, or -1 when the
# track is maxed (tier 3) or unknown.
static func price_for(track: String, current_tier: int, tunables: HangarTunables) -> int:
	if current_tier >= MAX_TIER or current_tier < 0:
		return -1
	var prices: Array = _prices_for(track, tunables)
	if current_tier >= prices.size():
		return -1
	return int(prices[current_tier])


# Decide a tier purchase. Returns { ok, owned_tiers, coins } with *fresh* copies
# so the caller's dictionaries are never mutated. Refuses (ok=false, inputs
# echoed back unchanged) for an unknown track, a maxed track, or when the wallet
# can't afford the next tier — no debt, no over-cap.
static func purchase(
	owned_tiers: Dictionary, coins: int, track: String, tunables: HangarTunables
) -> Dictionary:
	var refused := {"ok": false, "owned_tiers": owned_tiers.duplicate(true), "coins": coins}
	if not TRACKS.has(track):
		return refused
	var current: int = tier_of(owned_tiers, track)
	var price: int = price_for(track, current, tunables)
	if price < 0 or coins < price:
		return refused
	var bought: Dictionary = owned_tiers.duplicate(true)
	bought[track] = current + 1
	return {"ok": true, "owned_tiers": bought, "coins": coins - price}


# --- Apply-side getters (clamp tier into 0–MAX_TIER) ---

# Guns tier is the weapon_level floor directly — the identity, clamped.
static func guns_floor(tier: int) -> int:
	return clampi(tier, 0, MAX_TIER)


static func max_hp_for(tier: int, tunables: HangarTunables) -> int:
	return int(_curve_at(tunables.armour_max_hp, tier))


static func speed_mult_for(tier: int, tunables: HangarTunables) -> float:
	return float(_curve_at(tunables.engine_speed_mult, tier))


static func bomb_max_for(tier: int, tunables: HangarTunables) -> int:
	return int(_curve_at(tunables.bomb_max, tier))


static func bomb_blast_mult_for(tier: int, tunables: HangarTunables) -> float:
	return float(_curve_at(tunables.bomb_blast_mult, tier))


# --- internals ---

static func _prices_for(track: String, tunables: HangarTunables) -> Array:
	match track:
		"guns":
			return tunables.guns_prices
		"armour":
			return tunables.armour_prices
		"engine":
			return tunables.engine_prices
		"bombs":
			return tunables.bombs_prices
	return []


# Read a 4-entry effect curve at a tier, clamping the index so a tier outside
# 0–MAX_TIER never indexes out of range.
static func _curve_at(curve: Array, tier: int) -> Variant:
	var idx: int = clampi(tier, 0, curve.size() - 1)
	return curve[idx]
