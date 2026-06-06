extends GutTest

# PRD-07 (Story 3) — Continue re-enters at the saved checkpoint stage. Covers the
# GameManager side of the seam: continue_playthrough() must flag `resuming`, leave
# the loaded checkpoint intact (LevelBase seeds its stage from it), and route to
# the campaign_level scene. The LevelBase consume itself is scene-coupled and
# verified in the in-editor playtest. Exercises the autoload; saves and restores
# all mutated state so the suite leaves no residue. continue_playthrough() never
# writes to disk (only start_new_playthrough/level_complete do).

var _saved_resuming: bool
var _saved_campaign_level: int
var _saved_score: int
var _saved_spawn_score: int
var _saved_run_coins: int
var _saved_combo: int
var _saved_lives: int
var _saved_start_lives: int
var _saved_resume: Dictionary


func before_each() -> void:
	_saved_resuming = GameManager.resuming
	_saved_campaign_level = GameManager.campaign_level
	_saved_score = GameManager.score
	_saved_spawn_score = GameManager.spawn_score
	_saved_run_coins = GameManager.run_coins
	_saved_combo = GameManager.combo_count
	_saved_lives = GameManager.lives
	_saved_start_lives = GameManager._level_start_lives
	_saved_resume = GameManager.checkpoint.resume_point()


func after_each() -> void:
	GameManager.resuming = _saved_resuming
	GameManager.campaign_level = _saved_campaign_level
	GameManager.score = _saved_score
	GameManager.spawn_score = _saved_spawn_score
	GameManager.run_coins = _saved_run_coins
	GameManager.combo_count = _saved_combo
	GameManager.lives = _saved_lives
	GameManager._level_start_lives = _saved_start_lives
	GameManager.checkpoint.reset()
	GameManager.checkpoint.record(_saved_resume["stage_index"], _saved_resume["marker"])


func test_continue_sets_resuming_flag() -> void:
	GameManager.resuming = false
	GameManager.continue_playthrough()
	assert_true(
		GameManager.resuming, "continue flags resuming so the level honours the saved checkpoint"
	)


func test_continue_leaves_checkpoint_intact() -> void:
	GameManager.checkpoint.reset()
	GameManager.checkpoint.record(2, CheckpointState.Marker.STAGE_START)
	GameManager.continue_playthrough()
	assert_eq(GameManager.checkpoint.resume_point()["stage_index"], 2,
		"continue does not reset the checkpoint — the level seeds its stage from it")


func test_continue_routes_to_campaign_level_scene() -> void:
	# Routes to the furthest level reached (1-based campaign_level), clamped to the
	# real campaign size. Indexed via a runtime var (not a literal) so it survives
	# a single-level campaign today (PRD-14) and a growing one later.
	GameManager.campaign_level = 2
	var path := GameManager.continue_playthrough()
	var expected_idx := clampi(2, 1, GameManager.LEVELS.size()) - 1
	assert_eq(path, GameManager.LEVELS[expected_idx],
		"continue routes to the furthest level reached (clamped to campaign size)")


func test_continue_clamps_cleared_campaign_to_last_level() -> void:
	GameManager.campaign_level = GameManager.LEVELS.size() + 1  # campaign cleared
	var path := GameManager.continue_playthrough()
	assert_eq(path, GameManager.LEVELS[GameManager.LEVELS.size() - 1],
		"a cleared campaign clamps Continue to the last real level")
