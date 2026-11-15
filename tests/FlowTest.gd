extends Node
func _ready() -> void:
	var d := preload("res://tests/FlowDriver.gd").new()
	get_tree().root.add_child.call_deferred(d)
	d.run.call_deferred()
