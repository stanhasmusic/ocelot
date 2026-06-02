extends GutTest

# PRD-08 — the pure Hangar purchase + tier→effect math (HangarUpgrades) plus the
# owned_tiers persistence/default guarantees. Same "assert external behaviour,
# not private state" discipline as the PRD-07 save tests; no autoload or scene
# dependencies — a fresh HangarTunables.new() carries the table defaults.

const SAVE_ROUNDTRIP_PATH := "user://test_hangar_owned_tiers.tres"

var _t: HangarTunables


func before_each() -> void:
	_t = HangarTunables.new()


func after_each() -> void:
	if FileAccess.file_exists(SAVE_ROUNDTRIP_PATH):
		DirAccess.remove_absolute(SAVE_ROUNDTRIP_PATH)


# --- price_for ---

func test_price_for_walks_the_track_then_caps() -> void:
	assert_eq(HangarUpgrades.price_for("guns", 0, _t), 60, "tier 0→1 costs 60")
	assert_eq(HangarUpgrades.price_for("guns", 1, _t), 100, "tier 1→2 costs 100")
	assert_eq(HangarUpgrades.price_for("guns", 2, _t), 160, "tier 2→3 costs 160")
	assert_eq(HangarUpgrades.price_for("guns", 3, _t), -1, "a maxed track has no next price")


func test_price_for_unknown_track_is_minus_one() -> void:
	assert_eq(HangarUpgrades.price_for("rockets", 0, _t), -1, "unknown track has no price")


# --- purchase: success ---

func test_purchase_increments_track_and_deducts_price() -> void:
	var result := HangarUpgrades.purchase({}, 200, "armour", _t)
	assert_true(result["ok"], "an affordable buy succeeds")
	assert_eq(result["owned_tiers"]["armour"], 1, "the track tier bumps to 1")
	assert_eq(result["coins"], 140, "200 - 60 price = 140 left")


func test_purchase_with_exactly_enough_floors_the_wallet() -> void:
	var result := HangarUpgrades.purchase({"engine": 1}, 100, "engine", _t)
	assert_true(result["ok"], "exact-price buy succeeds")
	assert_eq(result["owned_tiers"]["engine"], 2, "tier bumps from 1 to 2")
	assert_eq(result["coins"], 0, "the wallet floors to 0, never negative")


# --- purchase: refusal (no mutation) ---

func test_purchase_refused_when_unaffordable() -> void:
	var result := HangarUpgrades.purchase({}, 59, "guns", _t)
	assert_false(result["ok"], "can't afford the 60 price")
	assert_eq(result["coins"], 59, "coins unchanged on refusal")
	assert_eq(HangarUpgrades.tier_of(result["owned_tiers"], "guns"), 0, "tier unchanged on refusal")


func test_purchase_refused_at_cap() -> void:
	var result := HangarUpgrades.purchase({"bombs": 3}, 9999, "bombs", _t)
	assert_false(result["ok"], "a maxed track refuses even with a full wallet")
	assert_eq(HangarUpgrades.tier_of(result["owned_tiers"], "bombs"), 3, "tier stays at the cap")


func test_purchase_refused_for_unknown_track() -> void:
	var result := HangarUpgrades.purchase({}, 9999, "rockets", _t)
	assert_false(result["ok"], "an unknown track is refused")


func test_purchase_does_not_mutate_caller_dictionary() -> void:
	var owned := {"guns": 1}
	# Success path: caller's dict must be left untouched (fresh copy returned).
	HangarUpgrades.purchase(owned, 1000, "guns", _t)
	assert_eq(owned, {"guns": 1}, "the input dictionary is not mutated on success")
	# Refusal path likewise.
	HangarUpgrades.purchase(owned, 0, "guns", _t)
	assert_eq(owned, {"guns": 1}, "the input dictionary is not mutated on refusal")


# --- tier→effect getters ---

func test_max_hp_curve_matches_table_and_is_monotonic() -> void:
	assert_eq(HangarUpgrades.max_hp_for(0, _t), 4)
	assert_eq(HangarUpgrades.max_hp_for(1, _t), 5)
	assert_eq(HangarUpgrades.max_hp_for(2, _t), 6)
	assert_eq(HangarUpgrades.max_hp_for(3, _t), 7)
	var prev := 0
	for tier in range(0, 4):
		var hp := HangarUpgrades.max_hp_for(tier, _t)
		assert_true(hp > prev, "max_hp increases every tier")
		prev = hp


func test_speed_mult_baseline_is_identity() -> void:
	assert_eq(HangarUpgrades.speed_mult_for(0, _t), 1.0, "tier 0 leaves speed unchanged")
	assert_almost_eq(HangarUpgrades.speed_mult_for(3, _t), 1.24, 0.001, "tier 3 speed mult")


func test_bomb_getters_match_table() -> void:
	assert_eq(HangarUpgrades.bomb_max_for(0, _t), 3)
	assert_eq(HangarUpgrades.bomb_max_for(3, _t), 6)
	assert_eq(HangarUpgrades.bomb_blast_mult_for(0, _t), 1.0)
	assert_almost_eq(HangarUpgrades.bomb_blast_mult_for(3, _t), 1.45, 0.001)


func test_guns_floor_is_identity_clamped() -> void:
	assert_eq(HangarUpgrades.guns_floor(2), 2, "guns tier is the weapon_level floor")
	assert_eq(HangarUpgrades.guns_floor(-1), 0, "clamped below 0")
	assert_eq(HangarUpgrades.guns_floor(99), HangarUpgrades.MAX_TIER, "clamped to the cap")


func test_getters_clamp_out_of_range_tiers() -> void:
	# A tier outside 0–3 must never index the curve out of range.
	assert_eq(HangarUpgrades.max_hp_for(99, _t), HangarUpgrades.max_hp_for(3, _t))
	assert_eq(HangarUpgrades.max_hp_for(-5, _t), HangarUpgrades.max_hp_for(0, _t))


# --- owned_tiers default / persistence ---

func test_empty_owned_tiers_reads_as_all_zero() -> void:
	# The no-migration guarantee: a fresh/pre-PRD-08 slot is {} and reads zero.
	for track in HangarUpgrades.TRACKS:
		assert_eq(HangarUpgrades.tier_of({}, track), 0, "%s defaults to 0" % track)


func test_owned_tiers_round_trips_through_save() -> void:
	var s := SaveGame.new()
	s.schema_version = SaveGame.SCHEMA_VERSION
	s.owned_tiers = {"guns": 2, "armour": 1, "engine": 3, "bombs": 0}
	assert_eq(ResourceSaver.save(s, SAVE_ROUNDTRIP_PATH), OK, "save succeeds")

	var loaded := ResourceLoader.load(
		SAVE_ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	assert_eq(HangarUpgrades.tier_of(loaded.owned_tiers, "guns"), 2, "guns tier persists")
	assert_eq(HangarUpgrades.tier_of(loaded.owned_tiers, "engine"), 3, "engine tier persists")


func test_new_game_reset_zeroes_all_tracks() -> void:
	var s := SaveGame.new()
	s.owned_tiers = {"guns": 3, "armour": 2, "engine": 1, "bombs": 3}
	s.reset_playthrough()
	for track in HangarUpgrades.TRACKS:
		assert_eq(HangarUpgrades.tier_of(s.owned_tiers, track), 0, "%s reset to 0" % track)
