extends StaticBody3D
## A part sitting on a shelf. Look at it to read its specs, press E to install it.

var category: String
var part_id: String
var _label: Label3D
var _model: Node3D
var _focused := false

func setup(cat: String, id: String) -> void:
	category = cat
	part_id = id
	_model = PartModels.for_part(cat, id)
	add_child(_model)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.55, 0.55, 0.55)
	shape.shape = bs
	shape.position.y = 0.25
	add_child(shape)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0012
	_label.font_size = 32
	_label.outline_size = 8
	_label.width = 700
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.position = Vector3(0, 0.62, 0)
	add_child(_label)
	MissionState.design_changed.connect(_refresh)
	_refresh()

func _installed() -> bool:
	return MissionState.picks.get(category) == part_id

func _refresh() -> void:
	var p := GameData.part(category, part_id)
	var head: String = p["name"]
	if _installed():
		head = head + "\n(INSTALLED)"
		_label.modulate = Color(0.5, 1.0, 0.6)
	else:
		_label.modulate = Color(1, 1, 1)
	if _focused:
		_label.font_size = 30
		_label.no_depth_test = true
		_label.render_priority = 10
		_label.position.y = 0.95
		_label.text = "%s\n[%s]" % [head, p.get("tier", "")]
	else:
		_label.font_size = 32
		_label.no_depth_test = false
		_label.render_priority = 0
		_label.position.y = 0.62
		_label.text = head

func _process(delta: float) -> void:
	if _focused:
		_model.rotate_y(delta * 1.2)

func on_focus(focused: bool) -> void:
	_focused = focused
	if focused:
		get_tree().call_group("tutor", "on_part_focus", category)
		get_tree().call_group("decision", "show_part", category, part_id)
	else:
		get_tree().call_group("decision", "hide_part", category, part_id)
	if not focused:
		_model.rotation = Vector3.ZERO
	_refresh()

func get_prompt() -> String:
	if _installed():
		return "Already installed"
	return "[E] Install %s" % GameData.part(category, part_id)["name"]

func interact() -> void:
	if MissionState.phase != "design":
		get_tree().call_group("hud", "show_message", "Mission in progress. Wait for the results before changing the spacecraft.")
		return
	if _installed():
		return
	MissionState.pick(category, part_id)
	get_tree().call_group("hud", "show_message", "Installed: " + GameData.part(category, part_id)["name"])
