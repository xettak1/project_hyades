extends CanvasLayer
## Minimal on-screen overlay: crosshair, "press E" prompt and short messages (below the crosshair).

var _prompt: Label
var _message: Label
var _msg_time := 0.0
var _levels := {}
var _blink := 0.0

func _ready() -> void:
	add_to_group("hud")
	var cross := UI.label("+", 28)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.size = Vector2(40, 40)
	cross.position -= Vector2(20, 20)
	add_child(cross)

	_prompt = UI.label("", 20, UI.COLOR_WARN)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(700, 40)
	_prompt.position += Vector2(-350, 40)
	add_child(_prompt)

	# Messages and alerts: centred in the lower middle, between the side cards, on a dark plate.
	_message = UI.label("", 19)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.anchor_left = 0.5
	_message.anchor_right = 0.5
	_message.anchor_top = 0.5
	_message.anchor_bottom = 0.5
	_message.offset_left = -240
	_message.offset_right = 240
	_message.offset_top = 70
	_message.offset_bottom = 110
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.02, 0.04, 0.09, 0.85)
	plate.set_corner_radius_all(8)
	plate.content_margin_left = 14
	plate.content_margin_right = 14
	plate.content_margin_top = 8
	plate.content_margin_bottom = 8
	_message.add_theme_stylebox_override("normal", plate)
	add_child(_message)

	for r in MissionState.assess():
		_levels[r["id"]] = r["level"]
	# Warning alerts after a decision now come from the Mission Tutor, the Decision card and the
	# instrumentation panel, so the HUD no longer pops its own.

func set_prompt(text: String) -> void:
	_prompt.text = text

func show_message(text: String, seconds: float = 3.5, color: Color = Color.WHITE) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_msg_time = seconds
	_message.modulate.a = 1.0

func _process(delta: float) -> void:
	_message.visible = _msg_time > 0.0 and _message.text != ""
	_blink += delta
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time < 0.5:
			_message.modulate.a = maxf(_msg_time / 0.5, 0.0)
