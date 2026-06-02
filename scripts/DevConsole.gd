extends CanvasLayer

# Dev console (testing tool, never shipped).
#
# A global overlay for skipping to game states fast and toggling cheats while
# playtesting. Autoloaded as a CanvasLayer so it floats above every scene and
# survives scene changes; guarded by OS.is_debug_build() so an exported release
# build disables it entirely.
#
# Design rule: this tool touches NO game code. Every action drives an existing
# seam (GameManager / CheckpointState / the spawner) or pokes live nodes found by
# group at runtime (Player.is_invincible, Enemy.hp). So it can be deleted whole
# with zero ripple, and a stray cheat can never leak into shipped behaviour.
#
# Toggle the panel with the backtick (`) key.

const TOGGLE_KEY: int = KEY_QUOTELEFT  # the ` key, unmapped by the game
const STAGES_PER_LEVEL: int = 3        # mirrors LevelBase.TOTAL_STAGES (no class_name to import)
const ARCHETYPES: Array = [
	["Fighter", "res://actors/Fighter.tscn"],
	["AceFighter", "res://actors/AceFighter.tscn"],
	["Bomber", "res://actors/Bomber.tscn"],
	["Interceptor", "res://actors/Interceptor.tscn"],
	["Helicopter", "res://actors/Helicopter.tscn"],
	["RocketLauncher", "res://actors/RocketLauncher.tscn"],
	["Tank", "res://actors/Tank.tscn"],
	["Ship", "res://actors/Ship.tscn"],
	["EliteEscort", "res://actors/EliteEscort.tscn"],
]

var _cheats: Dictionary = {"invincible": false, "infinite_bombs": false, "one_shot": false}
var _panel: Control
var _coins_value: Label
var _tier_values: Dictionary = {}     # track -> Label
var _lives_value: Label
var _bombs_value: Label
var _archetype_picker: OptionButton


func _ready() -> void:
	if not OS.is_debug_build():
		# Inert in release: no UI, no polling, no input handling.
		set_process(false)
		set_process_input(false)
		return
	layer = 128                                  # above everything
	process_mode = Node.PROCESS_MODE_ALWAYS      # works even while the game is paused
	_build_ui()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()


# Cheats are re-asserted every frame against whatever Player/enemies currently
# exist, so they survive respawns, scene changes, and invincibility timers
# without the game scripts knowing the console exists.
func _process(_delta: float) -> void:
	if not (_cheats["invincible"] or _cheats["infinite_bombs"] or _cheats["one_shot"]):
		return
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player:
		if _cheats["invincible"]:
			player.is_invincible = true
		if _cheats["infinite_bombs"] and player.get("bomb_count") != null and player.bomb_count < 9:
			player.bomb_count = 9
			GameManager.report_bomb_count(9)
	if _cheats["one_shot"]:
		for e in get_tree().get_nodes_in_group("Enemies"):
			if e.get("hp") != null and e.hp > 1:
				e.hp = 1


# --- UI construction (code-built; no .tscn to keep the tool self-contained) ---

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 10
	_panel.offset_right = -10
	_panel.offset_top = 10
	_panel.modulate = Color(1, 1, 1, 0.96)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 540)
	_panel.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	_header(col, "DEV CONSOLE  (` to close)")

	# 1. Scene / stage jumps
	_header(col, "— Jump —")
	var levels := _row(col)
	for i in GameManager.LEVELS.size():
		_button(levels, "L%d" % (i + 1), _goto_level.bind(i))
	_button(levels, "Hangar", _open_hangar)
	var stages := _row(col)
	for s in STAGES_PER_LEVEL:
		_button(stages, "Stage %d" % (s + 1), _jump_to_stage.bind(s))
	_button(stages, "Restart", _restart_scene)

	# 2. State setup
	_header(col, "— State —")
	_coins_value = _stepper_row(col, "Coins", func(d): _add_coins(d * 100), "±100")
	for track in HangarUpgrades.TRACKS:
		_tier_values[track] = _stepper_row(
			col, str(track).capitalize(), func(d): _bump_tier(track, d), ""
		)
	_lives_value = _stepper_row(col, "Lives", func(d): _add_lives(d), "")
	_bombs_value = _stepper_row(col, "Bombs", func(d): _add_bombs(d), "")

	# 3. God-mode toggles
	_header(col, "— Toggles —")
	_check(col, "Invincible", "invincible")
	_check(col, "Infinite bombs", "infinite_bombs")
	_check(col, "One-shot kills", "one_shot")

	# 4. Encounter control
	_header(col, "— Encounter —")
	var enc := _row(col)
	_button(enc, "Spawn boss", _spawn_boss)
	_button(enc, "Clear screen", _clear_screen)
	_button(enc, "+1000 score", func(): GameManager.add_score(1000))
	var spawn := _row(col)
	_archetype_picker = OptionButton.new()
	for entry in ARCHETYPES:
		_archetype_picker.add_item(entry[0])
	spawn.add_child(_archetype_picker)
	_button(spawn, "Spawn", _spawn_archetype)


func _header(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)


func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	return r


func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


# A labelled "[ - ] value [ + ]" stepper. `cb` receives +1 / -1. Returns the
# value Label so callers that show live state (coins, tiers) can update it.
func _stepper_row(parent: Node, label: String, cb: Callable, plus_hint: String) -> Label:
	var r := _row(parent)
	var name_l := Label.new()
	name_l.text = label
	name_l.custom_minimum_size = Vector2(110, 0)
	r.add_child(name_l)
	_button(r, "-", func(): cb.call(-1); _refresh())
	var value := Label.new()
	value.custom_minimum_size = Vector2(60, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(value)
	_button(r, "+", func(): cb.call(1); _refresh())
	if plus_hint != "":
		var hint := Label.new()
		hint.text = plus_hint
		hint.modulate = Color(1, 1, 1, 0.5)
		r.add_child(hint)
	return value


func _check(parent: Node, label: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = _cheats[key]
	c.toggled.connect(func(on): _cheats[key] = on)
	parent.add_child(c)


# Repaint the live-state labels (coins + tiers) from GameManager.
func _refresh() -> void:
	if _coins_value:
		_coins_value.text = str(GameManager.coins)
	for track in _tier_values:
		_tier_values[track].text = str(GameManager.tier(track))
	if _lives_value:
		_lives_value.text = str(GameManager.lives)
	if _bombs_value:
		var player: Node = get_tree().get_first_node_in_group("Player")
		_bombs_value.text = str(player.bomb_count) if (player and player.get("bomb_count") != null) else "—"


# --- Actions (every one drives an existing seam) ---

func _goto_level(i: int) -> void:
	GameManager.has_playthrough = true
	GameManager.campaign_level = maxi(GameManager.campaign_level, i + 1)
	GameManager.current_level = GameManager.LEVELS[i]
	GameManager.next_level = ""
	GameManager.resuming = false
	GameManager.checkpoint.reset()
	GameManager.reset_score()
	GameManager.reset_lives()
	_change_scene(GameManager.LEVELS[i])


func _open_hangar() -> void:
	# Point next_level at the level after the current one so Deploy goes somewhere
	# sensible; fall back to level 1.
	var idx: int = GameManager.LEVELS.find(GameManager.current_level)
	if idx >= 0 and idx + 1 < GameManager.LEVELS.size():
		GameManager.next_level = GameManager.LEVELS[idx + 1]
	else:
		GameManager.next_level = GameManager.LEVELS[0]
	_change_scene("res://ui/Hangar.tscn")


# Reload the current level seeded to re-enter at stage `idx`, reusing the same
# checkpoint+resuming path Continue uses (LevelBase honours it on _ready).
func _jump_to_stage(idx: int) -> void:
	var path: String = get_tree().current_scene.scene_file_path
	if not GameManager.LEVELS.has(path):
		return  # only meaningful inside a level
	GameManager.checkpoint.reset()
	GameManager.checkpoint.record(idx, CheckpointState.Marker.STAGE_START)
	GameManager.resuming = true
	GameManager.reset_score()
	GameManager.reset_lives()
	_change_scene(path)


func _restart_scene() -> void:
	_change_scene(get_tree().current_scene.scene_file_path)


func _add_coins(amount: int) -> void:
	GameManager.coins = maxi(0, GameManager.coins + amount)


func _bump_tier(track: String, delta: int) -> void:
	var next: int = clampi(GameManager.tier(track) + delta, 0, HangarUpgrades.MAX_TIER)
	GameManager.owned_tiers[track] = next


func _add_lives(delta: int) -> void:
	GameManager.lives = maxi(0, GameManager.lives + delta)
	GameManager.on_lives_changed.emit(GameManager.lives)


func _add_bombs(delta: int) -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player and player.get("bomb_count") != null:
		player.bomb_count = maxi(0, player.bomb_count + delta)
		GameManager.report_bomb_count(player.bomb_count)


func _spawn_boss() -> void:
	var spawner: Node = get_tree().current_scene.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("_on_boss_threshold_reached"):
		spawner._on_boss_threshold_reached()


func _clear_screen() -> void:
	for group in ["Enemies", "EnemyProjectiles"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()


func _spawn_archetype() -> void:
	var entry: Array = ARCHETYPES[_archetype_picker.selected]
	var scene: PackedScene = load(entry[1])
	if scene == null:
		return
	var node: Node = scene.instantiate()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	node.global_position = Vector2(vp.x * 0.5, 100)
	get_tree().current_scene.add_child(node)


func _change_scene(path: String) -> void:
	_panel.visible = false
	get_tree().change_scene_to_file(path)
