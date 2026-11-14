extends CanvasLayer
## Minimal on-screen overlay: crosshair, "press E" prompt, short messages, controls hint.

var _prompt: Label
var _message: Label
var _msg_time := 0.0

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

	_message = UI.label("", 22)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.size = Vector2(900, 80)
	_message.position += Vector2(-450, 24)
	add_child(_message)

	var hint := UI.label("WASD move   Mouse look   E / Click use   Esc menu", 14, UI.COLOR_MUTED)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position += Vector2(16, -36)
	hint.size = Vector2(600, 24)
	add_child(hint)

func set_prompt(text: String) -> void:
	_prompt.text = text

func show_message(text: String, seconds: float = 3.5) -> void:
	_message.text = text
	_msg_time = seconds
	_message.modulate.a = 1.0

func _process(delta: float) -> void:
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time < 0.5:
			_message.modulate.a = maxf(_msg_time / 0.5, 0.0)
