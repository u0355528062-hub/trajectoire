class_name Ambient
extends Node
## Ambiance sonore de la ville au crépuscule : vent, grondement lointain, grillons.

func _ready() -> void:
	for cfg in [[&"amb_wind", -19.0], [&"amb_city", -23.0], [&"amb_crickets", -27.0]]:
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.get_stream(cfg[0])
		p.volume_db = cfg[1]
		p.autoplay = true
		add_child(p)
		p.play()
