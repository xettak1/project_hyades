extends CanvasLayer
## Esc menu inside a mission: resume, restart, choose another mission, quit.

var _root: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0, 0.65)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var p := UI.panel()
	p.custom_minimum_size = Vector2(420, 0)
	center.add_child(p)
	var v := UI.vbox(12)
	p.add_child(v)
	v.add_child(UI.label("PAUSED", 30, UI.COLOR_ACCENT))
	v.add_child(UI.label(MissionState.mission()["name"], 18, UI.COLOR_MUTED))
	_add(v, "Resume", resume)
	_add(v, "Restart this mission", func():
		_unpause()
		MissionState.start_mission(MissionState.mission_id)
		get_tree().reload_current_scene())
	_add(v, "Choose another mission", func():
		_unpause()
		MissionState.open_select = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_add(v, "Quit to title", func():
		_unpause()
		MissionState.open_select = false
		get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_add(v, "Quit game", func(): get_tree().quit())
	_root.visible = false

func _add(v: VBoxContainer, text: String, action: Callable) -> void:
	var b := UI.button(text)
	b.pressed.connect(action)
	v.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _root.visible:
			resume()
		else:
			_root.visible = true
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()

func _unpause() -> void:
	get_tree().paused = false
	_root.visible = false

func resume() -> void:
	_unpause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
