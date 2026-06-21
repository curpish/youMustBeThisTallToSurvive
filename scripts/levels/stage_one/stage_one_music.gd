extends AudioStreamPlayer

func _ready() -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	play()
