extends Node
## Headless smoke test: starts a sector near the boss timer with god mode and auto upgrades.

func _ready() -> void:
	Game.debug["god"] = "1"
	Game.debug["t"] = "116"
	Game.debug["lv"] = "10"
	Game.debug["autopick"] = "1"
	Game.debug["trace"] = "1"
	Game.main = self
	start_run(int(OS.get_environment("PF_LEVEL")) if OS.get_environment("PF_LEVEL") != "" else 0)


func start_run(i: int) -> void:
	Game.level_index = i
	add_child(preload("res://scripts/game/run.gd").new())


func show_menu() -> void:
	pass
