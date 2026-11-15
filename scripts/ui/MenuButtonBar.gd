class_name MenuButtonBar
extends Button
## Main-menu button: a dark copper bar with a bright tab on the left, a notched right end
## and slanted (italic) capital letters. Slides right and lights up on hover.

const COPPER := Color(0.86, 0.45, 0.16)
const COPPER_HI := Color(1.0, 0.66, 0.3)
const FILL := Color(0.24, 0.11, 0.04, 0.82)
const FILL_HI := Color(0.45, 0.2, 0.06, 0.92)

var _hover := 0.0

func _init(label: String = "", size_px := Vector2(380, 46)) -> void:
	text = ""
	tooltip_text = ""
	custom_minimum_size = size_px
	focus_mode = Control.FOCUS_ALL
	flat = true
	set_meta("label", label)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())

static func slanted_font() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = FUI.font("Inter-SemiBold")
	f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)  # italic slant
	f.spacing_glyph = 2
	return f

func _process(delta: float) -> void:
	var want := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	if absf(_hover - want) > 0.001:
		_hover = move_toward(_hover, want, delta * 6.0)
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var dx := 10.0 * _hover
	var cut := 12.0
	var alpha := 0.45 if disabled else 1.0
	var fill := FILL.lerp(FILL_HI, _hover)
	fill.a *= alpha
	var edge := COPPER.lerp(COPPER_HI, _hover)
	edge.a *= alpha
	# body with a notched top-right corner
	var pts := PackedVector2Array([
		Vector2(dx + 4, 2), Vector2(dx + w - cut - 14, 2), Vector2(dx + w - 14, cut + 2),
		Vector2(dx + w - 14, h - 2), Vector2(dx + 4, h - 2)])
	draw_colored_polygon(pts, fill)
	# soft highlight along the top
	draw_rect(Rect2(dx + 4, 2, w - cut - 18, h * 0.35), Color(1, 0.75, 0.45, 0.06 + 0.06 * _hover))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(edge, 0.85 * alpha), 1.6, true)
	# left tab
	draw_rect(Rect2(dx, 0, 6, h), edge)
	# right bracket
	draw_polyline(PackedVector2Array([Vector2(dx + w - 8, 4), Vector2(dx + w - 2, 4), Vector2(dx + w - 2, h - 4), Vector2(dx + w - 8, h - 4)]), edge, 2.0)
	# text
	var f := slanted_font()
	var fs := int(h * 0.56)
	var label: String = get_meta("label", "")
	var col := Color(1, 0.95, 0.88, alpha).lerp(Color(1, 1, 1, alpha), _hover)
	draw_string(f, Vector2(dx + 22, h * 0.5 + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5 * alpha))
	draw_string(f, Vector2(dx + 21, h * 0.5 + fs * 0.33), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
