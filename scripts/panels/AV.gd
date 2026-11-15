class_name AV
extends RefCounted
## AVIONICS INSTRUMENT KIT: the shared look of every equipment display in the game.
## Every element is a Control with a minimum size, so it is laid out by containers
## (VBox / HBox / Grid / Margin): nothing is positioned by hand and nothing can overlap.
##
##   AV.Display  - a whole equipment screen: dark glass background, header strip with the unit's
##                 code, name and status lamp, a body for instruments, and a footer strip.
##                 Subclasses override build() once and refresh() four times a second.
##   AV.Gauge    - round dial (240°) with green/amber/red bands, ticks, needle and a big readout
##   AV.Meter    - horizontal segmented bar with tick marks and an optional limit marker
##   AV.Readout  - small label over a big number (with unit)
##   AV.Lamp     - annunciator tile (lit / unlit), like a real caution & warning panel
##   AV.Trend    - scrolling line graph (e.g. signal strength)
##   AV.Polar    - azimuth / elevation sky plot (antenna tracking)
##   AV.Section  - a framed group of related instruments with a small caption
## Status levels used everywhere: 0 = normal (green), 1 = caution (amber), 2 = warning (red),
## 3 = critical (red, flashing), -1 = information (cyan).

const BG_TOP := Color("#06101c")
const BG_BOT := Color("#02060c")
const GRID := Color(0.4, 0.7, 1.0, 0.035)
const FRAME := Color("#1c3349")
const LABEL := Color("#8fa7bd")
const DIMTXT := Color("#4d6378")
const INFO := Color("#38bdf8")
const OK := Color("#34d399")
const WARN := Color("#fbbf24")
const BAD := Color("#f87171")
const WHITE := Color("#eef6ff")

static func level_color(level: int) -> Color:
	match level:
		0: return OK
		1: return WARN
		2, 3: return BAD
	return INFO

static func font(kind := "mono") -> Font:
	return FUI.font({"mono": "JetBrainsMono-Medium", "mono_semi": "JetBrainsMono-SemiBold", "sans": "Inter-Regular", "sans_med": "Inter-Medium", "sans_semi": "Inter-SemiBold"}.get(kind, "Inter-Regular"))

static func text(c: CanvasItem, pos: Vector2, s: String, size: int, color: Color, kind := "mono", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	c.draw_string(font(kind), pos, s, align, width, size, color)

static func label(s: String, size: int, color: Color = LABEL, kind := "sans_med") -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

## A label that wraps inside its container instead of running off the screen.
static func para(s: String, size: int, color: Color = LABEL, kind := "sans") -> Label:
	var l := label(s, size, color, kind)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func grid(cols: int, hsep := 12, vsep := 12) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", vsep)
	return g

static func expand(c: Control, h := true, v := false) -> Control:
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

# ============================================================================ whole display
class Display extends Control:
	var code := "UNIT-01"            # equipment code shown in the header
	var title := "DISPLAY"
	var accent := AV.INFO
	var status := 0                  # drives the header lamp and the monitor's status LED
	var status_text := "NOMINAL"
	var footer := ""
	var body: VBoxContainer
	var _t := 0.0
	var _blink := 0.0
	const HEAD := 46.0
	const FOOT := 28.0
	const PAD := 18.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		clip_contents = true
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", int(PAD))
		m.add_theme_constant_override("margin_right", int(PAD))
		m.add_theme_constant_override("margin_top", int(HEAD + 12))
		m.add_theme_constant_override("margin_bottom", int(FOOT + 10))
		m.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(m)
		body = AV.vbox(12)
		body.mouse_filter = Control.MOUSE_FILTER_PASS
		m.add_child(body)
		build()
		refresh()

	## Override: add instruments to `body` once.
	func build() -> void:
		pass

	## Override: read real game data and update the instruments (4 times a second).
	func refresh() -> void:
		pass

	func _process(delta: float) -> void:
		_t += delta
		_blink += delta
		if _t >= 0.25:
			_t = 0.0
			refresh()
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# glass background with a faint vertical gradient and a fine grid
		for i in 16:
			var y0 := h * i / 16.0
			draw_rect(Rect2(0, y0, w, h / 16.0 + 1), AV.BG_TOP.lerp(AV.BG_BOT, i / 15.0))
		var g := 32.0
		var x := 0.0
		while x < w:
			draw_line(Vector2(x, HEAD), Vector2(x, h - FOOT), AV.GRID, 1.0)
			x += g
		var y := HEAD
		while y < h - FOOT:
			draw_line(Vector2(0, y), Vector2(w, y), AV.GRID, 1.0)
			y += g
		# header strip
		draw_rect(Rect2(0, 0, w, HEAD), Color("#0a1a2a"))
		draw_rect(Rect2(0, HEAD - 2, w, 2), Color(accent, 0.55))
		draw_rect(Rect2(0, 0, 6, HEAD), accent)
		AV.text(self, Vector2(20, 30), code, 15, Color(accent, 0.85), "mono_semi")
		var cw := AV.font("mono_semi").get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		AV.text(self, Vector2(34 + cw, 31), title, 20, AV.WHITE, "sans_semi")
		# status lamp + text on the right of the header
		var col := AV.level_color(status)
		var lit := status < 3 or fmod(_blink, 0.8) < 0.5
		var st := status_text
		var sw := AV.font("mono_semi").get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var lamp_c := Vector2(w - sw - 34, HEAD / 2.0)
		draw_circle(lamp_c, 8, Color(col, 0.25) if lit else Color(0.1, 0.1, 0.1))
		draw_circle(lamp_c, 5, col if lit else Color(col, 0.25))
		AV.text(self, Vector2(w - sw - 18, 29), st, 14, col, "mono_semi")
		# footer strip
		draw_rect(Rect2(0, h - FOOT, w, FOOT), Color("#07131f"))
		draw_line(Vector2(0, h - FOOT), Vector2(w, h - FOOT), AV.FRAME, 1.0)
		AV.text(self, Vector2(18, h - 9), footer, 12, AV.DIMTXT, "mono")
		var clock := "MET %s" % Time.get_time_string_from_system()
		AV.text(self, Vector2(w - 160, h - 9), clock, 12, AV.DIMTXT, "mono", HORIZONTAL_ALIGNMENT_RIGHT, 142)
		# soft vignette at the edges (screen illumination falls off)
		for i in 6:
			var a := 0.06 * (6 - i) / 6.0
			draw_rect(Rect2(i * 2, i * 2, w - i * 4, h - i * 4), Color(0, 0, 0, a), false, 2.0)

# ============================================================================ framed section
class Section extends PanelContainer:
	var caption := ""
	var content: VBoxContainer
	func _init(cap: String = "", sep := 8) -> void:
		caption = cap
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.02, 0.06, 0.1, 0.7)
		s.border_color = AV.FRAME
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 26 if cap != "" else 12
		s.content_margin_bottom = 12
		add_theme_stylebox_override("panel", s)
		content = AV.vbox(sep)
		add_child(content)
	func _draw() -> void:
		if caption != "":
			AV.text(self, Vector2(14, 17), caption, 12, AV.LABEL, "mono_semi")
			# corner ticks for an engineered look
			var c := Color(AV.INFO, 0.5)
			draw_line(Vector2(0, 0), Vector2(10, 0), c, 2)
			draw_line(Vector2(0, 0), Vector2(0, 10), c, 2)
			draw_line(Vector2(size.x, size.y), Vector2(size.x - 10, size.y), c, 2)
			draw_line(Vector2(size.x, size.y), Vector2(size.x, size.y - 10), c, 2)

# ============================================================================ round gauge
class Gauge extends Control:
	var caption := ""
	var unit := ""
	var lo := 0.0
	var hi := 100.0
	var value := 0.0
	var shown := 0.0                 # animated needle
	var fmt := "%.0f"
	var level := 0
	## Coloured bands as fractions of the dial: [[from, to, color], ...]
	var bands: Array = []
	var marker := -1.0               # optional limit marker (value units)
	func _init(cap: String = "", u: String = "", a := 0.0, b := 100.0, f := "%.0f", min_px := Vector2(190, 170)) -> void:
		caption = cap
		unit = u
		lo = a
		hi = b
		fmt = f
		custom_minimum_size = min_px
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	func set_value(v: float, lvl: int = 0) -> void:
		value = v
		level = lvl
	func _process(delta: float) -> void:
		shown = lerpf(shown, value, clampf(delta * 6.0, 0.0, 1.0))
		queue_redraw()
	func _ang(f: float) -> float:
		return deg_to_rad(150.0 + 240.0 * clampf(f, 0.0, 1.0))
	func _draw() -> void:
		# the whole dial (arc top to caption) always fits inside this control
		var r := maxf(minf(size.x * 0.5 - 12.0, (size.y - 66.0) / 1.5), 20.0)
		var c := Vector2(size.x * 0.5, 10.0 + r + maxf((size.y - 66.0 - r * 1.5) * 0.4, 0.0))
		draw_arc(c, r, _ang(0), _ang(1), 64, Color(1, 1, 1, 0.08), 12.0, true)
		for b in bands:
			draw_arc(c, r, _ang(b[0]), _ang(b[1]), 32, Color(b[2], 0.55), 12.0, true)
		for i in 11:
			var a := _ang(i / 10.0)
			var d := Vector2(cos(a), sin(a))
			var big := i % 5 == 0
			draw_line(c + d * (r - 18 - (6 if big else 0)), c + d * (r - 10), Color(AV.LABEL, 0.9 if big else 0.5), 2.0 if big else 1.0, true)
		if marker >= lo:
			var am := _ang((marker - lo) / maxf(hi - lo, 0.0001))
			var dm := Vector2(cos(am), sin(am))
			draw_line(c + dm * (r - 16), c + dm * (r + 8), AV.WHITE, 3.0, true)
		var f := (shown - lo) / maxf(hi - lo, 0.0001)
		var an := _ang(f)
		var col := AV.level_color(level)
		draw_arc(c, r + 9, _ang(0), an, 48, Color(col, 0.9), 3.0, true)
		var tip := c + Vector2(cos(an), sin(an)) * (r - 14)
		draw_line(c, tip, col, 3.5, true)
		draw_circle(c, 7, Color("#1d2b3a"))
		draw_circle(c, 4, col)
		var val := fmt % value
		var vs := int(clampf(r * 0.34, 18, 46))
		AV.text(self, Vector2(0, c.y + r * 0.5), val, vs, AV.WHITE, "mono_semi", HORIZONTAL_ALIGNMENT_CENTER, size.x)
		AV.text(self, Vector2(0, c.y + r * 0.5 + 20), unit, 14, AV.LABEL, "mono", HORIZONTAL_ALIGNMENT_CENTER, size.x)
		AV.text(self, Vector2(0, size.y - 6), caption, 15, AV.LABEL, "sans_semi", HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ============================================================================ bar meter
class Meter extends Control:
	var caption := ""
	var readout := ""
	var frac := 0.0
	var shown := 0.0
	var level := 0
	var limit := -1.0                # 0..1 position of a limit marker
	var segments := 30
	var limit_text := ""
	func _init(cap: String = "", h := 70.0) -> void:
		caption = cap
		custom_minimum_size = Vector2(220, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func set_value(f: float, text_value: String, lvl: int = 0) -> void:
		frac = f
		readout = text_value
		level = lvl
	func _process(delta: float) -> void:
		shown = lerpf(shown, frac, clampf(delta * 6.0, 0.0, 1.0))
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		AV.text(self, Vector2(0, 17), caption, 16, AV.LABEL, "sans_semi")
		AV.text(self, Vector2(0, 18), readout, 19, AV.WHITE if level <= 0 else AV.level_color(level), "mono_semi", HORIZONTAL_ALIGNMENT_RIGHT, w)
		var y := 28.0
		var bh := size.y - y - 22.0
		draw_rect(Rect2(0, y, w, bh), Color(1, 1, 1, 0.04))
		draw_rect(Rect2(0, y, w, bh), AV.FRAME, false, 1.0)
		var gap := 2.0
		var sw := (w - 4 - gap * (segments - 1)) / segments
		var col := AV.level_color(level)
		for i in segments:
			var on := (i + 0.5) / segments <= clampf(shown, 0.0, 1.0)
			draw_rect(Rect2(2 + i * (sw + gap), y + 2, sw, bh - 4), col if on else Color(col, 0.07))
		for i in 11:
			var tx := w * i / 10.0
			draw_line(Vector2(tx, y + bh), Vector2(tx, y + bh + (5 if i % 5 == 0 else 3)), AV.DIMTXT, 1.0)
		if limit >= 0.0:
			var lx := clampf(limit, 0.0, 1.0) * w
			draw_line(Vector2(lx, y - 3), Vector2(lx, y + bh + 6), AV.WHITE, 2.0)
			if limit_text != "":
				AV.text(self, Vector2(lx - 160, y + bh + 18), limit_text, 12, AV.WHITE, "mono_semi", HORIZONTAL_ALIGNMENT_RIGHT, 156)

# ============================================================================ digital readout
class Readout extends Control:
	var caption := ""
	var value := "--"
	var unit := ""
	var color := AV.WHITE
	var big := 34
	func _init(cap: String = "", u: String = "", size_px := 34, min_w := 150.0) -> void:
		caption = cap
		unit = u
		big = size_px
		custom_minimum_size = Vector2(min_w, size_px + 32)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func set_value(v: String, c: Color = AV.WHITE) -> void:
		value = v
		color = c
		queue_redraw()
	func _draw() -> void:
		AV.text(self, Vector2(0, 15), caption, 15, AV.LABEL, "sans_semi")
		var f := AV.font("mono_semi")
		var vw := f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		# fit long values: shrink rather than spill out of the box
		var s := big
		while vw > size.x - 8 and s > 12:
			s -= 2
			vw = f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		draw_string(f, Vector2(0, 20 + s), value, HORIZONTAL_ALIGNMENT_LEFT, -1, s, color)
		if unit != "" and vw + 70 < size.x:
			AV.text(self, Vector2(vw + 8, 20 + s), unit, 15, AV.LABEL, "mono")

# ============================================================================ annunciator lamp
class Lamp extends Control:
	var caption := ""
	var level := -2                  # -2 = unlit
	var _t := 0.0
	func _init(cap: String = "", min_px := Vector2(120, 44)) -> void:
		caption = cap
		custom_minimum_size = min_px
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	func set_state(lvl: int, cap: String = "") -> void:
		level = lvl
		if cap != "":
			caption = cap
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lit := level > -2 and (level < 3 or fmod(_t, 0.8) < 0.5)
		var col := AV.level_color(level) if level > -2 else Color("#30404f")
		draw_rect(r, Color("#05090e"))
		if lit:
			draw_rect(r.grow(-3), Color(col, 0.22))
			draw_rect(r.grow(-3), Color(col, 0.9), false, 2.0)
		else:
			draw_rect(r.grow(-3), Color("#0b141d"))
			draw_rect(r.grow(-3), Color(col, 0.6), false, 1.0)
		var tc := Color(col.lightened(0.35), 1.0) if lit else Color("#3d5163")
		var f := AV.font("mono_semi")
		var s := clampi(int(size.y * 0.32), 13, 19)
		while f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > size.x - 12 and s > 9:
			s -= 1
		draw_string(f, Vector2(0, size.y / 2 + s * 0.36), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, s, tc)

# ============================================================================ trend graph
class Trend extends Control:
	var caption := ""
	var values: Array = []
	var max_points := 90
	var lo := 0.0
	var hi := 1.0
	var color := AV.INFO
	var threshold := -1.0
	func _init(cap: String = "", a := 0.0, b := 1.0, min_px := Vector2(260, 130)) -> void:
		caption = cap
		lo = a
		hi = b
		custom_minimum_size = min_px
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func push(v: float) -> void:
		values.append(v)
		while values.size() > max_points:
			values.pop_front()
		queue_redraw()
	func _draw() -> void:
		AV.text(self, Vector2(0, 14), caption, 13, AV.LABEL, "sans_semi")
		var r := Rect2(0, 22, size.x, size.y - 22)
		draw_rect(r, Color(0, 0, 0, 0.35))
		draw_rect(r, AV.FRAME, false, 1.0)
		for i in range(1, 4):
			var y := r.position.y + r.size.y * i / 4.0
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.05), 1.0)
		if threshold >= lo:
			var ty := r.end.y - (threshold - lo) / maxf(hi - lo, 0.0001) * r.size.y
			draw_dashed_line(Vector2(r.position.x, ty), Vector2(r.end.x, ty), Color(AV.WARN, 0.7), 1.0, 6.0)
		if values.size() < 2:
			return
		var pts := PackedVector2Array()
		for i in values.size():
			var x := r.position.x + r.size.x * i / float(max_points - 1)
			var y := r.end.y - clampf((float(values[i]) - lo) / maxf(hi - lo, 0.0001), 0.0, 1.0) * (r.size.y - 4) - 2
			pts.append(Vector2(x, y))
		var fill := pts.duplicate()
		fill.append(Vector2(pts[pts.size() - 1].x, r.end.y))
		fill.append(Vector2(pts[0].x, r.end.y))
		draw_colored_polygon(fill, Color(color, 0.12))
		draw_polyline(pts, color, 2.0, true)
		draw_circle(pts[pts.size() - 1], 4, color)

# ============================================================================ antenna sky plot
class Polar extends Control:
	var caption := ""
	var track: Array = []            # [[az_deg, el_deg], ...] the predicted pass
	var az := 0.0
	var el := -1.0                   # below 0 = satellite not in view
	var pointing := Vector2(-1, -1)  # where the dish points [az, el]
	func _init(cap: String = "", min_px := Vector2(220, 220)) -> void:
		caption = cap
		custom_minimum_size = min_px
	func _xy(c: Vector2, r: float, a: float, e: float) -> Vector2:
		var rr := r * (1.0 - clampf(e, 0.0, 90.0) / 90.0)
		var ar := deg_to_rad(a - 90.0)
		return c + Vector2(cos(ar), sin(ar)) * rr
	func _draw() -> void:
		AV.text(self, Vector2(0, 14), caption, 13, AV.LABEL, "sans_semi")
		var r := minf(size.x, size.y - 24) * 0.5 - 14
		var c := Vector2(size.x * 0.5, 24 + r + 10)
		draw_circle(c, r, Color(0, 0.05, 0.08, 0.6))
		for k in [1.0, 0.667, 0.333]:
			draw_arc(c, r * k, 0, TAU, 64, Color(AV.INFO, 0.25), 1.0, true)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(AV.INFO, 0.18), 1.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(AV.INFO, 0.18), 1.0)
		for d in [["N", Vector2(0, -r - 4)], ["E", Vector2(r + 8, 4)], ["S", Vector2(0, r + 14)], ["W", Vector2(-r - 12, 4)]]:
			AV.text(self, c + d[1] - Vector2(4, 0), d[0], 12, AV.LABEL, "mono_semi")
		if track.size() > 1:
			var pts := PackedVector2Array()
			for p in track:
				pts.append(_xy(c, r, p[0], p[1]))
			draw_polyline(pts, Color(AV.WHITE, 0.35), 1.5, true)
		if pointing.y >= 0.0:
			var pp := _xy(c, r, pointing.x, pointing.y)
			draw_arc(pp, 11, 0, TAU, 24, AV.WARN, 2.0, true)
			draw_line(pp - Vector2(16, 0), pp + Vector2(16, 0), Color(AV.WARN, 0.7), 1.0)
			draw_line(pp - Vector2(0, 16), pp + Vector2(0, 16), Color(AV.WARN, 0.7), 1.0)
		if el >= 0.0:
			var sp := _xy(c, r, az, el)
			draw_circle(sp, 6, AV.OK)
			draw_circle(sp, 11, Color(AV.OK, 0.25))
