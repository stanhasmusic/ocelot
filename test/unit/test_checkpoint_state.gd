extends GutTest

const STAGE_START := CheckpointState.Marker.STAGE_START
const POST_INTRO := CheckpointState.Marker.POST_INTRO


func _new_state() -> CheckpointState:
	return CheckpointState.new()


func test_fresh_state_resumes_at_stage_zero_start() -> void:
	var state := _new_state()
	var point := state.resume_point()
	assert_eq(point["stage_index"], 0, "fresh state resumes at stage 0")
	assert_eq(point["marker"], STAGE_START, "fresh state resumes at stage start")


func test_recording_later_stage_advances_resume_point() -> void:
	var state := _new_state()
	state.record(2, STAGE_START)
	assert_eq(state.resume_point()["stage_index"], 2, "resume point advances to recorded stage")


func test_recording_earlier_stage_does_not_move_backward() -> void:
	var state := _new_state()
	state.record(3, STAGE_START)
	state.record(1, STAGE_START)
	assert_eq(state.resume_point()["stage_index"], 3, "earlier stage never moves resume point back")


func test_post_intro_advances_within_same_stage() -> void:
	var state := _new_state()
	state.record(1, STAGE_START)
	state.record(1, POST_INTRO)
	var point := state.resume_point()
	assert_eq(point["stage_index"], 1, "stage unchanged")
	assert_eq(point["marker"], POST_INTRO, "marker advances past intro within the same stage")


func test_marker_does_not_regress_within_same_stage() -> void:
	var state := _new_state()
	state.record(1, POST_INTRO)
	state.record(1, STAGE_START)
	assert_eq(state.resume_point()["marker"], POST_INTRO, "marker never regresses within a stage")


func test_recording_same_point_is_idempotent() -> void:
	var state := _new_state()
	state.record(2, POST_INTRO)
	state.record(2, POST_INTRO)
	var point := state.resume_point()
	assert_eq(point["stage_index"], 2)
	assert_eq(point["marker"], POST_INTRO)


func test_later_stage_start_beats_earlier_stage_post_intro() -> void:
	var state := _new_state()
	state.record(1, POST_INTRO)
	state.record(2, STAGE_START)
	var point := state.resume_point()
	assert_eq(point["stage_index"], 2, "a later stage always wins regardless of marker")
	assert_eq(point["marker"], STAGE_START)


func test_reset_returns_to_origin() -> void:
	var state := _new_state()
	state.record(2, POST_INTRO)
	state.reset()
	var point := state.resume_point()
	assert_eq(point["stage_index"], 0, "reset returns to stage 0")
	assert_eq(point["marker"], STAGE_START, "reset returns to stage start")


# --- Persistence round-trip (PRD-07) ---

func test_serialize_round_trips_through_a_dictionary() -> void:
	var state := _new_state()
	state.record(2, POST_INTRO)
	var restored := _new_state()
	restored.deserialize(state.serialize())
	var point := restored.resume_point()
	assert_eq(point["stage_index"], 2, "stage survives a serialize/deserialize round-trip")
	assert_eq(point["marker"], POST_INTRO, "marker survives a serialize/deserialize round-trip")


func test_deserialize_empty_dictionary_falls_back_to_origin() -> void:
	var state := _new_state()
	state.record(3, POST_INTRO)
	state.deserialize({})
	var point := state.resume_point()
	assert_eq(point["stage_index"], 0, "empty payload restores stage 0")
	assert_eq(point["marker"], STAGE_START, "empty payload restores stage start")


func test_deserialize_partial_dictionary_defaults_missing_marker() -> void:
	var state := _new_state()
	state.deserialize({"stage_index": 2})
	var point := state.resume_point()
	assert_eq(point["stage_index"], 2, "present field is restored")
	assert_eq(point["marker"], STAGE_START, "missing marker defaults to stage start")
