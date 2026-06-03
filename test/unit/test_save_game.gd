extends GutTest

# PRD-07 — the two-tier save schema's pure data transforms (migrate / reset)
# plus an on-disk serialize round-trip. No autoload or scene dependencies.

const TEST_PATH := "user://test_savegame_roundtrip.tres"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _profile_filled() -> SaveGame:
	var s := SaveGame.new()
	s.high_score = 12345
	s.master_volume = 0.8
	s.music_volume = 0.6
	s.sfx_volume = 0.4
	return s


# --- Schema versioning ---

func test_fresh_savegame_defaults_to_oldest_schema() -> void:
	# The default must be the floor so an un-versioned (v1) file on disk — which
	# never stored schema_version — loads as v1 and triggers migration.
	assert_eq(SaveGame.new().schema_version, 1, "default schema_version is the v1 floor")
	# PRD-09: a pre-PRD-09 save never stored gadget_slots, so the field defaults to
	# 1 slot (no migration, no crash) — the empty-slot default guarantee.
	assert_eq(SaveGame.new().gadget_slots, 1, "default gadget_slots is the 1-slot floor")


# --- Migration (v1 → v2) ---

func test_migrate_maps_unlocked_level_to_campaign_level() -> void:
	var s := _profile_filled()
	s.schema_version = 1
	s.unlocked_level = 3
	SaveGame.migrate(s)
	assert_eq(s.campaign_level, 3, "unlocked_level becomes campaign_level")
	assert_true(s.has_playthrough, "a v1 save is treated as a Playthrough in progress")
	assert_eq(s.schema_version, SaveGame.SCHEMA_VERSION, "schema is bumped to current")


func test_migrate_preserves_profile_tier() -> void:
	var s := _profile_filled()
	s.schema_version = 1
	s.unlocked_level = 2
	SaveGame.migrate(s)
	assert_eq(s.high_score, 12345, "high score preserved across migration")
	assert_eq(s.master_volume, 0.8, "master volume preserved")
	assert_eq(s.music_volume, 0.6, "music volume preserved")
	assert_eq(s.sfx_volume, 0.4, "sfx volume preserved")


func test_migrate_clamps_unlocked_level_floor() -> void:
	var s := SaveGame.new()
	s.schema_version = 1
	s.unlocked_level = 0
	SaveGame.migrate(s)
	assert_eq(s.campaign_level, 1, "campaign_level never falls below 1")


func test_migrate_is_noop_for_current_schema() -> void:
	var s := SaveGame.new()
	s.schema_version = SaveGame.SCHEMA_VERSION
	s.campaign_level = 4
	s.has_playthrough = true
	SaveGame.migrate(s)
	assert_eq(s.campaign_level, 4, "current-schema save is left untouched")


# --- New Game reset (Playthrough wiped, Profile kept) ---

func test_reset_playthrough_zeroes_playthrough_tier() -> void:
	var s := _profile_filled()
	s.has_playthrough = true
	s.campaign_level = 3
	s.coins = 500
	s.level_stars = {"0": 3}
	s.checkpoint = {"stage_index": 2, "marker": 1}
	s.owned_tiers = {"guns": 2}
	s.owned_gadgets = ["flare"]
	s.equipped_loadout = ["flare"]
	s.gadget_slots = 3
	s.reset_playthrough()
	assert_false(s.has_playthrough, "has_playthrough cleared")
	assert_eq(s.campaign_level, 1, "campaign_level back to 1")
	assert_eq(s.coins, 0, "coin wallet emptied")
	assert_eq(s.level_stars, {}, "level stars cleared")
	assert_eq(s.checkpoint, {}, "checkpoint cleared")
	assert_eq(s.owned_tiers, {}, "owned tiers cleared")
	assert_eq(s.owned_gadgets, [], "owned gadgets cleared")
	assert_eq(s.equipped_loadout, [], "equipped loadout cleared")
	assert_eq(s.gadget_slots, 1, "gadget slots back to 1 (PRD-09)")


func test_reset_playthrough_keeps_profile_tier() -> void:
	var s := _profile_filled()
	s.coins = 999
	s.reset_playthrough()
	assert_eq(s.high_score, 12345, "high score survives New Game")
	assert_eq(s.master_volume, 0.8, "volumes survive New Game")


# --- On-disk round-trip ---

func test_save_load_round_trip_preserves_all_fields() -> void:
	var s := _profile_filled()
	s.schema_version = SaveGame.SCHEMA_VERSION
	s.has_playthrough = true
	s.campaign_level = 2
	s.coins = 250
	s.level_stars = {"0": 3, "1": 2}
	s.checkpoint = {"stage_index": 1, "marker": 1}
	s.owned_tiers = {"armour": 1}
	s.owned_gadgets = ["coin_magnet", "flare"]
	s.equipped_loadout = ["coin_magnet"]
	s.gadget_slots = 2
	assert_eq(ResourceSaver.save(s, TEST_PATH), OK, "save succeeds")

	var loaded := ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame
	assert_not_null(loaded, "save file loads back as a SaveGame")
	assert_eq(loaded.schema_version, SaveGame.SCHEMA_VERSION, "schema_version round-trips")
	assert_eq(loaded.high_score, 12345, "high score round-trips")
	assert_eq(loaded.campaign_level, 2, "campaign_level round-trips")
	assert_eq(loaded.coins, 250, "coins round-trip")
	assert_eq(loaded.checkpoint, {"stage_index": 1, "marker": 1}, "checkpoint round-trips")
	assert_eq(loaded.level_stars, {"0": 3, "1": 2}, "level stars round-trip")
	assert_eq(loaded.owned_tiers, {"armour": 1}, "owned tiers round-trip")
	# PRD-09 loadout round-trip: slots, ownership, and the equipped subset persist.
	assert_eq(loaded.gadget_slots, 2, "gadget slot capacity round-trips")
	assert_eq(loaded.owned_gadgets, ["coin_magnet", "flare"], "owned gadgets round-trip")
	assert_eq(loaded.equipped_loadout, ["coin_magnet"], "equipped loadout round-trips")
