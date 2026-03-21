extends AnimatedSprite2D

@export var explosion_sfx: AudioStream = load("res://assets/audio/Sound Effects/explcls1.wav")

func _ready() -> void:
	animation_finished.connect(queue_free)
	play("default")
	
	# Play Sound
	SoundManager.play_sfx(explosion_sfx)
