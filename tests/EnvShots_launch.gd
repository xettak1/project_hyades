extends Node
func _ready() -> void:
	var d := preload("res://tests/EnvShots.gd").new()
	get_tree().root.add_child.call_deferred(d)
	d.run.call_deferred(OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "launch")
