extends StaticBody3D
## A physical push button on a console. Lights up when "lit" is true.

var action: Callable
var text: String
var is_lit := false
var _cap: MeshInstance3D
var _cap_mat: StandardMaterial3D
var _color: Color
var _label: Label3D
var _press_t := 0.0

func setup(label_text: String, color: Color, on_press: Callable, big: bool = false) -> void:
	text = label_text
	action = on_press
	_color = color
	var r := 0.12 if big else 0.07
	add_child(PartModels.cyl(r + 0.02, r + 0.03, 0.04, PartModels.dark(), Vector3(0, 0.02, 0)))
	_cap_mat = PartModels.mat(color.darkened(0.4), 0.1, 0.4)
	_cap = PartModels.cyl(r, r, 0.04, _cap_mat, Vector3(0, 0.06, 0))
	add_child(_cap)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r * 2.6, 0.15, r * 2.6)
	shape.shape = bs
	shape.position.y = 0.05
	add_child(shape)
	_label = Label3D.new()
	_label.text = label_text
	_label.font_size = 40 if not big else 56
	_label.pixel_size = 0.0016
	_label.outline_size = 8
	_label.rotation_degrees = Vector3(-50, 0, 0)
	_label.position = Vector3(0, 0.05, r + 0.1)
	add_child(_label)
	set_lit(false)

func set_lit(on: bool) -> void:
	is_lit = on
	_cap_mat.albedo_color = _color if on else _color.darkened(0.55)
	_cap_mat.emission_enabled = on
	_cap_mat.emission = _color
	_cap_mat.emission_energy_multiplier = 1.5

func _process(delta: float) -> void:
	if _press_t > 0.0:
		_press_t -= delta
		_cap.position.y = 0.04 if _press_t > 0.0 else 0.06

func on_focus(_f: bool) -> void:
	pass

func get_prompt() -> String:
	return "[E] " + text.replace("\n", " ")

func interact() -> void:
	_press_t = 0.15
	if action.is_valid():
		action.call()
