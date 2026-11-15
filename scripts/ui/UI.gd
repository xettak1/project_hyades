class_name UI
extends RefCounted
## Small helpers so every screen looks the same.

const COLOR_BG := Color(0.05, 0.07, 0.12)
const COLOR_PANEL := Color(0.10, 0.13, 0.20)
const COLOR_ACCENT := Color(0.30, 0.65, 1.0)
const COLOR_GOOD := Color(0.35, 0.80, 0.45)
const COLOR_WARN := Color(0.95, 0.75, 0.25)
const COLOR_BAD := Color(0.95, 0.35, 0.35)
const COLOR_MUTED := Color(0.65, 0.70, 0.80)

static func label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", panel_style(Color(0.08, 0.13, 0.23, 0.96), Color(0.3, 0.65, 1.0, 0.55), 1))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.12, 0.24, 0.4, 0.98), Color(0.3, 0.65, 1.0), 1))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.16, 0.3, 0.46, 1.0), Color(0.95, 0.75, 0.25), 1))
	b.add_theme_stylebox_override("focus", panel_style(Color(0.1, 0.18, 0.3, 1.0), Color(0.95, 0.75, 0.25), 1))
	return b

static func panel_style(color: Color = COLOR_PANEL, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	s.border_color = border
	s.set_border_width_all(border_w)
	return s

static func panel(color: Color = COLOR_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color))
	return p

static func margin_color(margin: float) -> Color:
	if margin < 0.0:
		return COLOR_BAD
	if margin < 0.2:
		return COLOR_WARN
	return COLOR_GOOD

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

## One line of key numbers for a part, e.g. "1.0 kg   uses 4.0 W   $0.50M".
static func stats_text(p: Dictionary) -> String:
	var bits: Array = []
	if p.has("mass"): bits.append("%.1f kg" % p["mass"])
	if p.get("power", 0.0) > 0.0: bits.append("uses %.1f W" % p["power"])
	if p.has("power_gen"): bits.append("makes %.0f W in sunlight" % p["power_gen"])
	if p.has("energy"): bits.append("stores %.0f Wh" % p["energy"])
	if p.has("data"): bits.append("%.1f GB/day of images" % p["data"])
	if p.has("mbps"): bits.append("%s Mbps" % str(p["mbps"]))
	if p.has("storage"): bits.append("%.0f GB storage" % p["storage"])
	if p.has("cost"): bits.append("$%.2fM" % p["cost"])
	return "   ".join(bits)
