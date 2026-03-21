extends Node

var music_player: AudioStreamPlayer
var sfx_pool: Node

func _ready() -> void:
	# Create Music Player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	# Create SFX Pool Container
	sfx_pool = Node.new()
	sfx_pool.name = "SFXPool"
	add_child(sfx_pool)

func play_music(stream: AudioStream, fade_duration: float = 1.0) -> void:
	if music_player.stream == stream and music_player.playing:
		return
		
	# Setup Tween for crossfade (fade out -> swap -> fade in)
	var tween = create_tween()
	
	if music_player.playing:
		# Fade out
		tween.tween_property(music_player, "volume_db", -80.0, fade_duration * 0.5)
	
	# Callback to swap track and restart
	tween.tween_callback(func():
		music_player.stop()
		music_player.stream = stream
		music_player.volume_db = -80.0 # Start silent
		music_player.play()
	)
	
	# Fade in
	tween.tween_property(music_player, "volume_db", 0.0, fade_duration * 0.5)

func play_sfx(stream: AudioStream) -> void:
	if stream == null: return
	
	var player: AudioStreamPlayer = null
	
	# Iterate pool to play sound
	for child in sfx_pool.get_children():
		if child is AudioStreamPlayer and not child.playing:
			player = child
			break
			
	# Dynamic Pooling: Create new if all busy
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(sfx_pool.get_child_count())
		player.bus = "SFX"
		sfx_pool.add_child(player)
		
	player.stream = stream
	player.play()
