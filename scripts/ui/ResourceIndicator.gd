extends VBoxContainer
## One row of an instrumentation panel: icon, short label, value, optional progress bar,
## coloured by status (0 green, 1 amber, 2 red, 3 flashing red, -1 neutral).

var icon := "info"
var _icon: Control
var _label: Label
var _value: Label
var _bar: Control
var _status := -1

func _init(icon_name: String = "info", label_text: String = "") -> void:
	icon = icon_name
	add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_icon = Icon.new()
	_icon.kind = icon_name
	_icon.custom_minimum_size = Vector2(18, 18)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = FUI.t(label_text, 14, FUI.MUTED, "sans_med")
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.clip_text = true
	_label.custom_minimum_size = Vector2(96, 0)
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_label)
	_value = FUI.t("", 15, FUI.WHITE, "sans_semi")
	row.add_child(_value)
	_bar = Bar.new()
	_bar.custom_minimum_size = Vector2(0, 5)
	_bar.visible = false
	add_child(_bar)

## frac < 0 hides the bar.
func set_value(text: String, status: int = -1, frac: float = -1.0) -> void:
	_status = status
	_value.text = text
	var c := status_color(status)
	_value.add_theme_color_override("font_color", c if status >= 0 else FUI.WHITE)
	_icon.tint = c if status >= 0 else FUI.SKY
	_icon.queue_redraw()
	_bar.visible = frac >= 0.0
	_bar.frac = clampf(frac, 0.0, 1.0)
	_bar.tint = c if status >= 0 else FUI.SKY
	_bar.queue_redraw()

func set_label(t: String) -> void:
	_label.text = t

static func status_color(status: int) -> Color:
	match status:
		0: return FUI.GREEN
		1: return FUI.AMBER
		2: return FUI.RED
		3: return Color("#ff3b3b")
	return FUI.TEXT2

func _process(_d: float) -> void:
	if _status == 3:
		modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5 else 0.45
	else:
		modulate.a = 1.0

class Bar extends Control:
	var frac := 0.0
	var tint := FUI.SKY
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), tint)

## Small line icons drawn in code, so no image files are needed.
class Icon extends Control:
	var kind := "info"
	var tint := FUI.SKY
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := Vector2(w / 2, h / 2)
		var col := tint
		match kind:
			"money":
				draw_circle(c, w * 0.45, Color(col, 0.2))
				draw_arc(c, w * 0.45, 0, TAU, 20, col, 1.5, true)
				draw_string(FUI.font("JetBrainsMono-SemiBold"), Vector2(w * 0.28, h * 0.78), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.7), col)
			"mass":
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, h * 0.9), Vector2(w * 0.8, h * 0.9), Vector2(w * 0.68, h * 0.35), Vector2(w * 0.32, h * 0.35)]), Color(col, 0.6))
				draw_arc(Vector2(c.x, h * 0.28), w * 0.14, 0, TAU, 12, col, 1.5, true)
			"rocket":
				draw_colored_polygon(PackedVector2Array([Vector2(c.x, 0), Vector2(w * 0.72, h * 0.4), Vector2(w * 0.72, h * 0.8), Vector2(w * 0.28, h * 0.8), Vector2(w * 0.28, h * 0.4)]), Color(col, 0.75))
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.28, h * 0.6), Vector2(w * 0.1, h * 0.95), Vector2(w * 0.3, h * 0.82)]), col)
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.72, h * 0.6), Vector2(w * 0.9, h * 0.95), Vector2(w * 0.7, h * 0.82)]), col)
			"orbit":
				draw_circle(c, w * 0.18, Color(col, 0.8))
				draw_arc(c, w * 0.44, 0, TAU, 24, col, 1.5, true)
				draw_circle(c + Vector2(w * 0.44, 0).rotated(-0.8), w * 0.1, FUI.WHITE)
			"ready":
				draw_circle(c, w * 0.45, Color(col, 0.25))
				draw_polyline(PackedVector2Array([Vector2(w * 0.25, h * 0.52), Vector2(w * 0.43, h * 0.7), Vector2(w * 0.76, h * 0.3)]), col, 2.0, true)
			"battery":
				draw_rect(Rect2(w * 0.1, h * 0.28, w * 0.72, h * 0.44), col, false, 1.5)
				draw_rect(Rect2(w * 0.82, h * 0.4, w * 0.08, h * 0.2), col)
				draw_rect(Rect2(w * 0.16, h * 0.34, w * 0.5, h * 0.32), Color(col, 0.7))
			"sun":
				draw_circle(c, w * 0.2, col)
				for i in 8:
					var d := Vector2(1, 0).rotated(i * TAU / 8)
					draw_line(c + d * w * 0.3, c + d * w * 0.46, col, 1.5, true)
			"bolt":
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.6, 0), Vector2(w * 0.2, h * 0.55), Vector2(w * 0.48, h * 0.55), Vector2(w * 0.38, h), Vector2(w * 0.82, h * 0.4), Vector2(w * 0.52, h * 0.4)]), col)
			"storage":
				for i in 3:
					draw_rect(Rect2(w * 0.15, h * (0.12 + i * 0.29), w * 0.7, h * 0.22), Color(col, 0.35 + i * 0.2))
			"camera":
				draw_rect(Rect2(w * 0.08, h * 0.3, w * 0.84, h * 0.55), Color(col, 0.6))
				draw_rect(Rect2(w * 0.3, h * 0.18, w * 0.3, h * 0.14), col)
				draw_circle(Vector2(c.x, h * 0.58), w * 0.18, FUI.BG)
				draw_arc(Vector2(c.x, h * 0.58), w * 0.18, 0, TAU, 14, col, 1.5, true)
			"progress":
				draw_arc(c, w * 0.4, -PI / 2, PI, 20, col, 2.5, true)
				draw_arc(c, w * 0.4, PI, PI * 1.5, 8, Color(col, 0.25), 2.5, true)
			"station":
				draw_arc(Vector2(c.x, h * 0.45), w * 0.4, PI * 0.15, PI * 0.85, 14, col, 2.0, true)
				draw_line(Vector2(c.x, h * 0.55), Vector2(c.x, h * 0.95), col, 2.0)
				draw_line(Vector2(w * 0.25, h * 0.95), Vector2(w * 0.75, h * 0.95), col, 2.0)
			"signal":
				for i in 4:
					var bh := h * (0.25 + i * 0.22)
					draw_rect(Rect2(w * (0.08 + i * 0.23), h - bh, w * 0.16, bh), Color(col, 0.4 + i * 0.2))
			"clock":
				draw_arc(c, w * 0.42, 0, TAU, 20, col, 1.5, true)
				draw_line(c, c + Vector2(0, -h * 0.28), col, 1.5)
				draw_line(c, c + Vector2(w * 0.22, 0), col, 1.5)
			"down":
				draw_line(Vector2(c.x, h * 0.08), Vector2(c.x, h * 0.75), col, 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.25, h * 0.55), Vector2(w * 0.75, h * 0.55), Vector2(c.x, h * 0.9)]), col)
			"map":
				for i in 3:
					for j in 3:
						draw_rect(Rect2(w * (0.06 + i * 0.31), h * (0.06 + j * 0.31), w * 0.27, h * 0.27), Color(col, 0.3 + 0.2 * ((i + j) % 3)))
			"flood":
				for i in 2:
					var y := h * (0.4 + i * 0.3)
					var pts := PackedVector2Array()
					for k in 9:
						pts.append(Vector2(w * k / 8.0, y + sin(k * 1.6) * h * 0.08))
					draw_polyline(pts, col, 2.0, true)
			"leaf":
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.15, h * 0.85), Vector2(w * 0.3, h * 0.25), Vector2(w * 0.85, h * 0.12), Vector2(w * 0.7, h * 0.7)]), Color(col, 0.7))
				draw_line(Vector2(w * 0.15, h * 0.85), Vector2(w * 0.7, h * 0.35), FUI.BG, 1.0)
			"missing":
				draw_arc(c, w * 0.42, 0, TAU, 20, col, 1.5, true)
				draw_line(c + Vector2(-w * 0.25, -h * 0.25), c + Vector2(w * 0.25, h * 0.25), col, 2.0)
			"impact":
				var pts2 := PackedVector2Array()
				for i in 10:
					var r := w * (0.46 if i % 2 == 0 else 0.2)
					pts2.append(c + Vector2(0, -r).rotated(i * TAU / 10))
				draw_colored_polygon(pts2, col)
			_:
				draw_circle(c, w * 0.3, col)
