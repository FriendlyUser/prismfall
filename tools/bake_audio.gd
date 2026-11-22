extends Node
## Offline tool: run this scene headless to (re)generate res://audio/*.wav from the synth in Sfx.

func _ready() -> void:
	var dir := ProjectSettings.globalize_path("res://audio")
	DirAccess.make_dir_recursive_absolute(dir)
	Sfx.bake(dir)
	print("baked audio into ", dir)
	get_tree().quit()
