@tool
extends EditorScript

func _run() -> void:
	var json_path = "res://assets/sprites/explosions/explosions.json"
	var tex_path = "res://assets/sprites/explosions/explosions.png"
	
	if not FileAccess.file_exists(json_path):
		print("Error: JSON not found")
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		print("JSON Parse Error")
		return
		
	var data = json.data
	var texture = load(tex_path)
	
	var frames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", false) 
	frames.set_animation_speed("default", 24.0)
	
	# Filter keys for 'expl_01' and sort them
	var keys = []
	for key in data["frames"].keys():
		if key.begins_with("expl_01"):
			keys.append(key)
	keys.sort()
	
	for key in keys:
		var frame_data = data["frames"][key]["frame"]
		var rect = Rect2(frame_data["x"], frame_data["y"], frame_data["w"], frame_data["h"])
		
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = texture
		atlas_tex.region = rect
		
		frames.add_frame("default", atlas_tex)
	
	var err = ResourceSaver.save(frames, "res://objects/ExplosionFrames.tres")
	if err == OK:
		print("Success: Generated res://objects/ExplosionFrames.tres with " + str(keys.size()) + " frames.")
	else:
		print("Error saving resource: " + str(err))
