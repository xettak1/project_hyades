extends CanvasLayer
## MISSION TUTOR: the communications console fixed at the BOTTOM of the screen, in every level.
## Pure UI: it shows lines of dialogue with a typing animation, a Next and a Skip button,
## a stage indicator and the current task. What to say is decided by TutorDialogueManager.
##   Enter / Next  : finish typing, or go to the next line
##   Backspace / Skip : skip the rest of a long explanation
##   T             : collapse / expand the console

signal next_pressed
signal skip_pressed

const HEIGHT := 128.0
const COLLAPSED := 34.0
const CHARS_PER_SEC := 70.0

var _panel: PanelContainer
var _avatar: Control
var _name: Label
var _stage: Label
var _text: Label
var _todo: Label
var _next: Button
var _skip: Button
var _keys: Label
var _body: Control
var _mini: Label
var _typing := 0.0
var _collapsed := false
var _blink := 0.0
var _kind := "step"

func _ready() -> void:
	layer = 6
	add_to_group("mission_tutor")
	_panel = PanelContainer.new()
	var s := FUI.box(Color(0.025, 0.05, 0.1, 0.94), Color(FUI.AMBER, 0.45), 10, 10)
	s.border_width_top = 3
	s.content_margin_left = 14
	s.content_margin_right = 14
	_panel.add_theme_stylebox_override("panel", s)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 12
	_panel.offset_right = -12
	_panel.offset_bottom = -8
	_panel.offset_top = -8 - HEIGHT
	add_child(_panel)

	var row := FUI.hb(14)
	_panel.add_child(row)
	_body = row
	_avatar = _Avatar.new()
	_avatar.custom_minimum_size = Vector2(76, 76)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_avatar)

	var mid := FUI.vb(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var head := FUI.hb(10)
	_name = FUI.t("MISSION TUTOR", 13, FUI.AMBER, "mono_semi")
	head.add_child(_name)
	_stage = FUI.t("", 11, FUI.SKY, "mono_semi")
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", FUI.box(Color(FUI.SKY, 0.1), Color(FUI.SKY, 0.35), 4, 2))
	chip.get_theme_stylebox("panel").content_margin_left = 8
	chip.get_theme_stylebox("panel").content_margin_right = 8
	chip.add_child(_stage)
	head.add_child(chip)
	head.add_child(FUI.grow())
	_keys = FUI.t("WASD move · mouse look · E use · T hide tutor · Esc menu", 10, FUI.DIM, "mono")
	head.add_child(_keys)
	mid.add_child(head)
	_text = FUI.t("", 17, FUI.WHITE, "sans_med")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_text)
	_todo = FUI.t("", 14, FUI.GREEN, "sans_semi")
	mid.add_child(_todo)

	var btns := FUI.vb(6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next = _btn("NEXT  ⏎", FUI.AMBER)
	_next.pressed.connect(func(): next_pressed.emit())
	btns.add_child(_next)
	_skip = _btn("SKIP  ⌫", FUI.MUTED)
	_skip.pressed.connect(func(): skip_pressed.emit())
	btns.add_child(_skip)
	row.add_child(btns)

	_mini = FUI.t("", 12, FUI.AMBER, "mono_semi")
	_mini.visible = false
	_panel.add_child(_mini)

func _btn(text: String, c: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(118, 34)
	b.add_theme_font_override("font", FUI.font("JetBrainsMono-SemiBold"))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", c)
	b.add_theme_stylebox_override("normal", FUI.box(Color(c, 0.08), Color(c, 0.5), 6, 6))
	b.add_theme_stylebox_override("hover", FUI.box(Color(c, 0.18), c, 6, 6))
	b.add_theme_stylebox_override("pressed", FUI.box(Color(c, 0.3), c, 6, 6))
	return b

# ---------------------------------------------------------------- API
## Show one line. kind: "step" (guided task), "reaction" (responds to a decision), "alert" (a problem).
func show_line(text: String, stage: String, todo: String = "", can_next := true, can_skip := false, kind := "step") -> void:
	_kind = kind
	_text.text = text
	_text.visible_ratio = 0.0
	_typing = 0.0
	_stage.text = stage
	_todo.text = ("▶ " + todo) if todo != "" else ""
	_todo.visible = todo != ""
	_next.visible = can_next
	_skip.visible = can_skip
	var col: Color = {"step": FUI.WHITE, "reaction": Color("#bae6fd"), "alert": Color("#fca5a5"), "good": Color("#a7f3d0")}.get(kind, FUI.WHITE)
	_text.add_theme_color_override("font_color", col)
	var border: Color = {"alert": FUI.RED, "good": FUI.GREEN, "reaction": FUI.SKY}.get(kind, FUI.AMBER)
	(_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(border, 0.6)
	_name.add_theme_color_override("font_color", border)
	(_avatar as _Avatar).tint = border
	_mini.text = "MISSION TUTOR · %s · press T to open" % stage
	_avatar.queue_redraw()

func is_typing() -> bool:
	return _text.visible_ratio < 1.0

func finish_typing() -> void:
	_text.visible_ratio = 1.0

func set_collapsed(c: bool) -> void:
	_collapsed = c
	_body.visible = not c
	_mini.visible = c
	_panel.offset_top = -8 - (COLLAPSED if c else HEIGHT)

func toggle() -> void:
	set_collapsed(not _collapsed)

func is_collapsed() -> bool:
	return _collapsed

## Pixels the tutor takes at the bottom of the screen (other UI keeps clear of it).
func used_height() -> float:
	return (COLLAPSED if _collapsed else HEIGHT) + 16.0

func _process(delta: float) -> void:
	if _text.visible_ratio < 1.0 and _text.text.length() > 0:
		_typing += delta * CHARS_PER_SEC
		_text.visible_ratio = clampf(_typing / float(_text.text.length()), 0.0, 1.0)
	_blink += delta
	(_avatar as _Avatar).talking = is_typing()
	_avatar.queue_redraw()

## Mission-control headset icon, drawn in code (no image file needed).
class _Avatar extends Control:
	var tint := FUI.AMBER
	var talking := false
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		draw_circle(c, r, Color(tint, 0.12))
		draw_arc(c, r, 0, TAU, 48, Color(tint, 0.7), 2.0, true)
		# head
		draw_circle(c + Vector2(0, -6), r * 0.3, Color(tint, 0.85))
		# shoulders
		draw_arc(c + Vector2(0, r * 0.62), r * 0.55, PI * 1.08, PI * 1.92, 24, Color(tint, 0.85), 5.0, true)
		# headset band + mic
		draw_arc(c + Vector2(0, -6), r * 0.42, PI * 1.05, PI * 1.95, 20, FUI.WHITE, 2.5, true)
		draw_line(c + Vector2(r * 0.4, -4), c + Vector2(r * 0.15, 8), FUI.WHITE, 2.0, true)
		# signal waves while talking
		if talking:
			var t := Time.get_ticks_msec() / 1000.0
			for i in 3:
				var a := fmod(t * 2.0 + i * 0.33, 1.0)
				draw_arc(c + Vector2(r * 0.55, -r * 0.55), 4.0 + a * 10.0, -PI * 0.6, PI * 0.1, 10, Color(tint, 1.0 - a), 1.5, true)
