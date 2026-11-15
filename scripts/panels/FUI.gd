class_name FUI
extends RefCounted
## "Flight Ops" design system, matched to the Google Stitch design:
## dark slate cards, Brogame for display text, JetBrains Mono for every number.

const BG := Color("#080d1a")
const HEADER := Color("#0b1222")
const CARD := Color("#0f172a")
const INSET := Color("#0b1222")
const MAP_BG := Color("#070d18")
const BORDER := Color("#1e293b")
const WHITE := Color("#ffffff")
const TEXT := Color("#cbd5e1")
const TEXT2 := Color("#e2e8f0")
const MUTED := Color("#94a3b8")
const DIM := Color("#64748b")
const FAINT := Color("#475569")
const GREEN := Color("#34d399")
const SKY := Color("#38bdf8")
const AMBER := Color("#fbbf24")
const RED := Color("#f87171")

static var _fonts: Dictionary = {}

static func font(name: String) -> Font:
	if not _fonts.has(name):
		var path := "res://assets/fonts/%s.ttf" % name
		_fonts[name] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[name]

## Text label. kind: "sans", "sans_med", "sans_semi", "mono", "mono_med", "mono_semi"
static func t(text: String, size: int, color: Color = TEXT, kind: String = "sans") -> Label:
	var l := Label.new()
	l.text = text
	var f := {"sans": "brogame", "sans_med": "brogame", "sans_semi": "brogame",
		"mono": "JetBrainsMono-Regular", "mono_med": "JetBrainsMono-Medium", "mono_semi": "JetBrainsMono-SemiBold"}
	l.add_theme_font_override("font", font(f.get(kind, "brogame")))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Small uppercase caption like "MISSION ELAPSED TIME".
static func cap(text: String, size: int = 11, color: Color = MUTED) -> Label:
	return t(text.to_upper(), size, color, "sans_med")

static func box(bg: Color, border: Color = BORDER, radius: int = 10, pad: int = 16, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

static func card(pad: int = 18, bg: Color = CARD, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 10, pad))
	return p

## Little tinted chip like "High Precision".
static func chip(text: String, color: Color, mono: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(color.r, color.g, color.b, 0.10), Color(color.r, color.g, color.b, 0.28), 5, 0)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.add_child(t(text, 12, color, "mono_med" if mono else "sans_med"))
	return p

static func dot(color: Color, d: float = 7.0) -> Control:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(d, d)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

static func vline(h: float = 22.0) -> ColorRect:
	var c := ColorRect.new()
	c.color = BORDER
	c.custom_minimum_size = Vector2(1, h)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

static func hline() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(BORDER, 0.8)
	c.custom_minimum_size = Vector2(0, 1)
	return c

static func hb(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vb(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func grow() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## Thin progress / margin bar.
static func bar(fraction: float, color: Color, h: float = 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.001
	b.value = clampf(fraction, 0.0, 1.0)
	b.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1e293b")
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

## Button styled like the Stitch buttons (neutral or tinted).
static func button(text: String, tint: Color = Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font("brogame"))
	b.add_theme_font_size_override("font_size", 13)
	var tinted := tint.a > 0.0
	var base := Color(tint.r, tint.g, tint.b, 0.10) if tinted else Color("#1e293b")
	var edge := Color(tint.r, tint.g, tint.b, 0.35) if tinted else Color("#334155")
	b.add_theme_color_override("font_color", tint if tinted else TEXT2)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_stylebox_override("normal", box(base, edge, 8, 8))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.12), edge, 8, 8))
	b.add_theme_stylebox_override("pressed", box(base.lightened(0.2), edge, 8, 8))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 8, 0))
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
