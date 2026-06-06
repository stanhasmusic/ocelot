extends Node

signal on_score_updated(new_score: int)
signal on_spawn_score_updated(spawn_score: int)
signal on_combo_changed(new_multiplier: int)
signal on_boss_health_changed(current: int, max_hp: int)
signal on_boss_spawned(max_hp: int, is_named: bool)
signal on_boss_died
signal on_lives_changed(new_lives: int)
signal on_bomb_count_changed(new_count: int)
signal on_coins_changed(new_total: int)
signal on_checkpoint_banked(stage_index: int)
# PRD-03 input-aware controls. `scheme` drives the movement branch (POSITIONAL /
# VELOCITY); `device` is the finer EventKind (MOUSE/TOUCH/JOYPAD/KEY) the HUD
# uses for prompt glyphs and touch-button visibility.
signal on_input_scheme_changed(new_scheme: int)
signal on_input_device_changed(new_device: int)

const SAVE_PATH: String = "user://savegame.tres"
const BUS_TRIM_DB: Array[float] = [0.0, 0.0, -10.0]  # Master, Music, SFX

# Hangar effect curves + placeholder prices (PRD-08). The single spend seam
# (purchase_tier) and the apply-side getters read these; PRD-11 retunes the
# .tres without code.
const HANGAR_TUNABLES: HangarTunables = preload("res://resources/HangarTunables.tres")
# Gadget loadout registry + prices + effect knobs (PRD-09). The buy/equip seams
# read the prices; Player reads the effect knobs. PRD-11 retunes the .tres.
const GADGET_CATALOG: GadgetCatalog = preload("res://resources/GadgetCatalog.tres")
# Payout side of the economy (PRD-11): per-level income floors, no-death/collection
# faucets, convoy value, terminal coins→score rate. The thin level_complete seam
# reads these through the pure CoinEarnings; Enemy reads convoy_coin_value.
const ECONOMY_TUNABLES: EconomyTunables = preload("res://resources/EconomyTunables.tres")
# The campaign array, trimmed honest (PRD-14): one real level for now. It grows
# as Levels 2-4 land. "Campaign complete" + the terminal coins->score cash-out
# fire after Pacific, exercising those end-of-campaign paths for real.
const LEVELS: Array[String] = [
	"res://scenes/LevelPacific.tscn",
]

var score: int = 0
var spawn_score: int = 0
# Coins collected this run (PRD-05 drop hook feeds this). In-memory tally that
# commits into the persisted `coins` wallet once per level via bank_run_coins()
# (PRD-07); economy balancing of payouts is PRD-11.
var run_coins: int = 0
var combo_count: int = 0
var high_score: int = 0
var level_stars: Dictionary = {}
var last_level_stars: int = 0
var last_level_new_record: bool = false
# Coins routed to score by the terminal cash-out on campaign completion (PRD-11).
# Surfaced on the final LevelComplete; 0 on every non-final clear.
var last_coin_cashout: int = 0
var _level_start_lives: int = 3
# Whether the player has died anywhere in the current level (PRD-11 no-death
# faucet). Set in Player.die(); reset at level start, paired with _level_start_lives.
var died_this_level: bool = false
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
# Playthrough tier (ADR-0011 / PRD-07): persists within a campaign run, wiped by
# New Game. `coins` is the banked wallet the Hangar (PRD-08/09) spends; the
# in-run `run_coins` above commits into it once per level via bank_run_coins().
var has_playthrough: bool = false
var campaign_level: int = 1  # 1-based furthest level reached
var coins: int = 0
# First-clear ledger (PRD-11): level indices already cleared this Playthrough.
# level_complete() banks a level's payout only on its first appearance here; a
# replay banks nothing. Persisted; wiped by New Game.
var cleared_levels: Array = []
# Reserved Hangar slots — persisted + reset here so PRD-08/09 need no migration.
# Opaque to this PRD; shapes are owned by those PRDs.
var owned_tiers: Dictionary = {}
var owned_gadgets: Array = []
var equipped_loadout: Array = []
# Gadget slot capacity (PRD-09). Persisted; defaults to MIN_SLOTS so a pre-PRD-09
# save reads as 1 slot with no migration. equipped_loadout never exceeds this.
var gadget_slots: int = GadgetLoadout.MIN_SLOTS
var current_level: String = "res://scenes/LevelPacific.tscn"
var next_level: String = ""
var lives: int = 3

# Active control scheme + device (PRD-03). Read by the player controller (scheme)
# and the HUD (device); seeded to the default so frame-one is controllable.
var input_scheme: int = InputScheme.DEFAULT_SCHEME
var input_device: int = InputScheme.EventKind.MOUSE

# Furthest safe resume point reached this run (PRD-02). Persisted across restarts
# via save_data/load_data (PRD-07). LevelBase records into it; respawn reads it.
var checkpoint: CheckpointState = CheckpointState.new()

# Transient, session-only flag (not persisted): set by continue_playthrough() so
# the first LevelBase entry honours the loaded checkpoint (seed its stage, skip
# the fresh-run reset) instead of restarting the level. Consumed once on entry.
var resuming: bool = false

func _ready() -> void:
	# Ensure audio buses are loaded (Project Settings bug workaround)
	if AudioServer.bus_count <= 1:
		var bus_layout_path = "res://resources/default_bus_layout.tres"
		if ResourceLoader.exists(bus_layout_path):
			AudioServer.set_bus_layout(load(bus_layout_path))
			print("Forced reload of default_bus_layout.tres")

	setup_inputs()
	load_data()
	
	# Apply loaded volumes
	update_volume(0, master_volume)
	update_volume(1, music_volume)
	update_volume(2, sfx_volume)

func update_volume(bus_index: int, value: float) -> void:
	# Update internal var
	match bus_index:
		0: master_volume = value
		1: music_volume = value
		2: sfx_volume = value
	
	# Apply to AudioServer
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value) + BUS_TRIM_DB[bus_index])
	save_data() # Auto-save settings

func setup_inputs() -> void:
	# Define Actions and Events

	
	# Let's use the robust helper method approach directly here for clarity
	_map_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_map_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_map_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_map_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	
	_map_action("shoot", [KEY_SPACE], [], [JOY_AXIS_TRIGGER_RIGHT])
	_map_action("bomb", [KEY_ALT], [JOY_BUTTON_X])
	
	_map_action("ui_accept", [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_map_action("ui_cancel", [KEY_ESCAPE], [JOY_BUTTON_B])
	_map_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	
	# Axis Mappings for Movement (Sticks)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

func _map_action(action: String, keys: Array, buttons: Array, axes: Array = []) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	
	for k in keys:
		var e = InputEventKey.new()
		e.keycode = k
		if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)
		
	for b in buttons:
		var e = InputEventJoypadButton.new()
		e.button_index = b
		if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)

	for a in axes:
		var e = InputEventJoypadMotion.new()
		e.axis = a
		e.axis_value = 1.0
		if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)

func _add_axis(action: String, axis: int, val: float) -> void:
	var e = InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = val
	if not InputMap.action_has_event(action, e): InputMap.action_add_event(action, e)

func get_multiplier() -> int:
	return clampi(1 + combo_count / 5, 1, 5)

func add_score(points: int) -> void:
	combo_count += 1
	spawn_score += points
	score += points * get_multiplier()
	on_score_updated.emit(score)
	on_spawn_score_updated.emit(spawn_score)
	on_combo_changed.emit(get_multiplier())

func add_coins(amount: int) -> void:
	run_coins += amount
	on_coins_changed.emit(run_coins)

func reset_combo() -> void:
	combo_count = 0
	on_combo_changed.emit(1)

func reset_score() -> void:
	score = 0
	spawn_score = 0
	run_coins = 0
	reset_combo()
	on_score_updated.emit(score)

func reset_lives() -> void:
	lives = 3
	_level_start_lives = 3
	died_this_level = false
	on_lives_changed.emit(lives)


# Record progress through a stage so a death mid-level resumes here, not the
# level start. Monotonic via CheckpointState — never moves the player backward.
func bank_checkpoint(stage_index: int, marker: int = CheckpointState.Marker.STAGE_START) -> void:
	checkpoint.record(stage_index, marker)
	on_checkpoint_banked.emit(checkpoint.resume_point()["stage_index"])


func reset_checkpoint() -> void:
	checkpoint.reset()


# Commit the in-run coin tally into the persisted wallet. The single seam where
# run_coins → coins (PRD-07); economy tuning of payouts is PRD-11. Idempotent
# per call — zeroes run_coins so a second call banks nothing.
func bank_run_coins() -> void:
	coins += run_coins
	run_coins = 0
	on_coins_changed.emit(run_coins)


# Bank a level's payout through the first-clear gate (PRD-11). On a level's FIRST
# clear this Playthrough: bank what the player collected (run_coins) plus the
# CoinEarnings payout (floor top-up + no-death bonus), then mark the level
# cleared. On a REPLAY of an already-cleared level: bank nothing (the [Play Again]
# farm stays closed) — kills/score still functioned during the replay. Either way
# the run tally is cleared so it can't double-bank. Does not save; the caller does.
func bank_level_payout(level_idx: int) -> void:
	var already_cleared: bool = level_idx >= 0 and cleared_levels.has(level_idx)
	var added: int = CoinEarnings.level_payout(
		run_coins, level_idx, died_this_level, already_cleared, ECONOMY_TUNABLES
	)
	if not already_cleared:
		coins += run_coins + added
		if level_idx >= 0:
			cleared_levels.append(level_idx)
	run_coins = 0
	on_coins_changed.emit(coins)


# --- Hangar stat tracks (PRD-08) ---

# Current tier of a Hangar track ("guns"/"armour"/"engine"/"bombs"), defaulting
# a missing key to 0 — an empty owned_tiers reads as all-zero, no migration.
func tier(track: String) -> int:
	return HangarUpgrades.tier_of(owned_tiers, track)


# The single seam where coins leave the wallet for a tier. Delegates the
# decision to the pure HangarUpgrades.purchase; on success deducts coins, bumps
# the tier, persists, and announces the new wallet. Refuses (returns false, no
# mutation) when maxed or unaffordable.
func purchase_tier(track: String) -> bool:
	var result: Dictionary = HangarUpgrades.purchase(owned_tiers, coins, track, HANGAR_TUNABLES)
	if not result["ok"]:
		return false
	owned_tiers = result["owned_tiers"]
	coins = result["coins"]
	save_data()
	on_coins_changed.emit(coins)
	return true


# Engine-tier multiplier applied to the player's top speed (read once at level
# start, on both control branches — the accessibility dial, PRD-08).
func speed_multiplier() -> float:
	return HangarUpgrades.speed_mult_for(tier("engine"), HANGAR_TUNABLES)


# --- Hangar gadget loadout (PRD-09) ---

# Buy a gadget slot (1→3). The single seam where coins leave the wallet for a
# slot; delegates the decision to the pure GadgetLoadout. On success raises
# capacity, deducts coins, persists, announces the wallet. Refuses (false, no
# mutation) at the cap or when unaffordable.
func purchase_gadget_slot() -> bool:
	var result: Dictionary = GadgetLoadout.purchase_slot(gadget_slots, coins, GADGET_CATALOG)
	if not result["ok"]:
		return false
	gadget_slots = result["gadget_slots"]
	coins = result["coins"]
	save_data()
	on_coins_changed.emit(coins)
	return true


# Buy a gadget. Delegates to the pure GadgetLoadout; on success marks it owned,
# deducts coins, persists, announces the wallet. Refuses (false, no mutation) for
# an unknown / already-owned id or when unaffordable — no debt, no double-buy.
func purchase_gadget(id: String) -> bool:
	var result: Dictionary = GadgetLoadout.purchase_gadget(
		owned_gadgets, coins, id, GADGET_CATALOG
	)
	if not result["ok"]:
		return false
	owned_gadgets = result["owned_gadgets"]
	coins = result["coins"]
	save_data()
	on_coins_changed.emit(coins)
	return true


# Equip an owned gadget into a free slot (free, reversible). Refuses (false, no
# mutation) for an unowned / already-equipped id or a full loadout. Persists so
# the loadout survives a relaunch.
func equip_gadget(id: String) -> bool:
	var result: Dictionary = GadgetLoadout.equip(
		owned_gadgets, equipped_loadout, gadget_slots, id
	)
	if not result["ok"]:
		return false
	equipped_loadout = result["equipped_loadout"]
	save_data()
	return true


# Unequip a gadget back into ownership (free). Refuses (false, no mutation) for an
# id that is not currently equipped. Persists.
func unequip_gadget(id: String) -> bool:
	var result: Dictionary = GadgetLoadout.unequip(equipped_loadout, id)
	if not result["ok"]:
		return false
	equipped_loadout = result["equipped_loadout"]
	save_data()
	return true


# Begin a fresh Playthrough (New Game): wipe the Playthrough tier, keep the
# Profile tier (high score + volumes). Returns the scene path of level 1 so the
# caller can change scenes. Does not itself change scenes.
func start_new_playthrough() -> String:
	has_playthrough = true
	campaign_level = 1
	coins = 0
	cleared_levels = []
	level_stars = {}
	owned_tiers = {}
	owned_gadgets = []
	equipped_loadout = []
	gadget_slots = GadgetLoadout.MIN_SLOTS
	current_level = LEVELS[0]
	next_level = ""
	resuming = false  # fresh start — the level resets its checkpoint as usual
	reset_checkpoint()
	reset_score()
	reset_lives()
	save_data()
	return LEVELS[0]


# Resume the saved Playthrough at its furthest level (Continue). Returns that
# level's scene path; clamps to the last real level if the campaign was cleared.
# Leaves the loaded checkpoint intact and flags `resuming` so the level re-enters
# at the saved stage rather than the level start (PRD-07, Story 3).
func continue_playthrough() -> String:
	reset_score()
	reset_lives()
	resuming = true
	var idx = clampi(campaign_level, 1, LEVELS.size()) - 1
	return LEVELS[idx]

func add_life() -> void:
	lives += 1
	on_lives_changed.emit(lives)

func level_complete() -> void:
	current_level = get_tree().current_scene.scene_file_path
	var idx = LEVELS.find(current_level)
	var is_final: bool = not (idx >= 0 and idx + 1 < LEVELS.size())
	if not is_final:
		next_level = LEVELS[idx + 1]
		campaign_level = max(campaign_level, idx + 2) # 1-based furthest reached
	else:
		next_level = ""
		campaign_level = max(campaign_level, LEVELS.size() + 1) # campaign cleared

	# Bank this level's payout through the first-clear gate (PRD-11): a first clear
	# pays collected + floor top-up + no-death bonus and marks the level cleared; a
	# replay banks nothing. Replaces the old unconditional bank_run_coins().
	bank_level_payout(idx)

	# Star rating: 3 = no lives lost, 2 = lost 1, 1 = lost 2+
	var lives_lost = _level_start_lives - lives
	last_level_stars = clampi(3 - lives_lost, 1, 3)

	# Persist best star count per level
	if idx >= 0:
		var key = str(idx)
		level_stars[key] = max(level_stars.get(key, 0), last_level_stars)

	# Terminal coins→score (PRD-11): on clearing the final level, every unspent
	# coin cashes out to a one-time score bonus (the arcade end-of-run mop-up), so
	# finale coins and any surplus still count for ranking. Folded into score
	# before the record check so a cash-out can set a new high score.
	last_coin_cashout = 0
	if is_final:
		last_coin_cashout = CoinEarnings.score_cashout(coins, ECONOMY_TUNABLES)
		if last_coin_cashout > 0:
			score += last_coin_cashout
			on_score_updated.emit(score)

	# New record check
	last_level_new_record = score > high_score
	if last_level_new_record:
		high_score = score

	_level_start_lives = lives  # snapshot for next level's star calc
	died_this_level = false     # reset the no-death faucet for the next level
	save_data()
	get_tree().call_deferred("change_scene_to_file", "res://ui/LevelComplete.tscn")

func game_over() -> void:
	if score > high_score:
		high_score = score
		save_data()
	current_level = get_tree().current_scene.scene_file_path
	get_tree().call_deferred("change_scene_to_file", "res://ui/GameOver.tscn")

func save_data() -> void:
	var save_game = SaveGame.new()
	save_game.schema_version = SaveGame.SCHEMA_VERSION
	# Profile tier
	save_game.high_score = high_score
	save_game.master_volume = master_volume
	save_game.music_volume = music_volume
	save_game.sfx_volume = sfx_volume
	# Playthrough tier
	save_game.has_playthrough = has_playthrough
	save_game.campaign_level = campaign_level
	save_game.coins = coins
	save_game.cleared_levels = cleared_levels
	save_game.level_stars = level_stars
	save_game.checkpoint = checkpoint.serialize()
	save_game.owned_tiers = owned_tiers
	save_game.owned_gadgets = owned_gadgets
	save_game.equipped_loadout = equipped_loadout
	save_game.gadget_slots = gadget_slots
	ResourceSaver.save(save_game, SAVE_PATH)

func load_data() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		save_data() # Create initial save if none exists
		return
	var save_game = load(SAVE_PATH) as SaveGame
	if not save_game:
		print("Error loading save data. File may be corrupted or script path changed. Creating new save.")
		save_data()
		return
	SaveGame.migrate(save_game)
	# Profile tier
	high_score = save_game.high_score
	master_volume = save_game.master_volume
	music_volume = save_game.music_volume
	sfx_volume = save_game.sfx_volume
	# Playthrough tier
	has_playthrough = save_game.has_playthrough
	campaign_level = save_game.campaign_level
	coins = save_game.coins
	cleared_levels = save_game.cleared_levels
	level_stars = save_game.level_stars
	checkpoint.deserialize(save_game.checkpoint)
	owned_tiers = save_game.owned_tiers
	owned_gadgets = save_game.owned_gadgets
	equipped_loadout = save_game.equipped_loadout
	gadget_slots = save_game.gadget_slots

# `is_named` distinguishes the level's named boss from a mini-boss (PRD-14): only
# a named boss swaps the background to the boss arena (and, later, hard-swaps to
# boss music — PRD-16). Mini-bosses still show the aggregate health bar.
func report_boss_spawned(max_hp: int, is_named: bool = false) -> void:
	on_boss_spawned.emit(max_hp, is_named)

func report_boss_health(current: int, max_hp: int) -> void:
	on_boss_health_changed.emit(current, max_hp)

func report_boss_died() -> void:
	on_boss_died.emit()

func report_bomb_count(count: int) -> void:
	on_bomb_count_changed.emit(count)

func report_input_scheme(scheme: int) -> void:
	if scheme != input_scheme:
		input_scheme = scheme
		on_input_scheme_changed.emit(scheme)

func report_input_device(device: int) -> void:
	if device != input_device:
		input_device = device
		on_input_device_changed.emit(device)
