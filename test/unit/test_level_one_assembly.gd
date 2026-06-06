extends GutTest

# Cheap, headless, no-render wiring guard for the assembled Level 1 (PRD-14). No
# combat is instantiated — it reads the stage configs as resources, the boss
# scenes' part structure via SceneState, the Pacific background resource, and the
# level scene's wiring, so the heavy prototype purge + rewire can't silently
# break the assembly. Content balance/feel is feel-tested (ADR-0004), not here.

const STAGE_CONFIGS := [
	"res://resources/stage_configs/level01_stage0.tres",
	"res://resources/stage_configs/level01_stage1.tres",
	"res://resources/stage_configs/level01_stage2.tres",
]
const EXPECTED_BOSS := [
	"res://actors/Warship.tscn",
	"res://actors/CoastalGun.tscn",
	"res://actors/CoastalFortress.tscn",
]
const PART_SCENE := "res://actors/BossPart.tscn"
const PACIFIC_BG := "res://resources/level_backgrounds/level_pacific.tres"
const PACIFIC_BG_SCENE := "res://objects/PacificScrollingBackground.tscn"
const LEVEL_SCENE := "res://scenes/LevelPacific.tscn"


func test_stage_configs_are_wired() -> void:
	for path in STAGE_CONFIGS:
		var cfg: StageConfig = load(path)
		assert_not_null(cfg, path)
		assert_not_null(cfg.intro_timeline, "%s intro_timeline" % path)
		assert_not_null(cfg.boss_scene, "%s boss_scene" % path)
		assert_gt(cfg.enemy_scenes.size(), 0, "%s enemy_scenes non-empty" % path)
		assert_eq(
			cfg.enemy_weights.size(), cfg.enemy_scenes.size(), "%s weights match scenes" % path
		)


func test_each_stage_points_at_its_boss() -> void:
	for i in STAGE_CONFIGS.size():
		var cfg: StageConfig = load(STAGE_CONFIGS[i])
		assert_eq(cfg.boss_scene.resource_path, EXPECTED_BOSS[i], STAGE_CONFIGS[i])


# Count is_core vs weak-point BossPart instances in a boss scene without
# instantiating it (the same SceneState read the tier test uses for archetypes).
func _count_parts(scene_path: String) -> Dictionary:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var core := 0
	var non_core := 0
	for i in state.get_node_count():
		var inst: PackedScene = state.get_node_instance(i)
		if inst == null or inst.resource_path != PART_SCENE:
			continue
		var is_core := false
		for j in state.get_node_property_count(i):
			if state.get_node_property_name(i, j) == "is_core":
				is_core = bool(state.get_node_property_value(i, j))
		if is_core:
			core += 1
		else:
			non_core += 1
	return {"core": core, "non_core": non_core}


func test_coastal_fortress_is_one_core_two_weakpoints() -> void:
	var parts := _count_parts("res://actors/CoastalFortress.tscn")
	assert_eq(parts["core"], 1, "fortress core count")
	assert_eq(parts["non_core"], 2, "fortress weak-point count")


# Guards the CONTEXT "degenerate boss" definition: a mini-boss is a single
# core-only part with no weak-points/phases.
func test_mini_bosses_are_core_only() -> void:
	for path in ["res://actors/Warship.tscn", "res://actors/CoastalGun.tscn"]:
		var parts := _count_parts(path)
		assert_eq(parts["core"], 1, "%s core count" % path)
		assert_eq(parts["non_core"], 0, "%s weak-point count" % path)


func test_pacific_background_has_three_strips_and_arena() -> void:
	var bg: LevelBackground = load(PACIFIC_BG)
	assert_not_null(bg, PACIFIC_BG)
	assert_eq(bg.stage_backgrounds.size(), 3, "stage_backgrounds count")
	assert_not_null(bg.boss_arena_texture, "boss_arena_texture")


func test_level_scene_wires_three_stages_and_pacific_bg() -> void:
	var state: SceneState = (load(LEVEL_SCENE) as PackedScene).get_state()
	var stages_val: Variant = null
	var bg_val: Variant = null
	for j in state.get_node_property_count(0):
		var pname := state.get_node_property_name(0, j)
		if pname == "stages":
			stages_val = state.get_node_property_value(0, j)
		elif pname == "background_scene":
			bg_val = state.get_node_property_value(0, j)
	assert_not_null(stages_val, "stages property set")
	assert_eq((stages_val as Array).size(), 3, "three stages wired")
	assert_not_null(bg_val, "background_scene set")
	assert_eq((bg_val as PackedScene).resource_path, PACIFIC_BG_SCENE, "pacific bg wired")
