class_name MissionCard
extends Control
## A rectangular mission card for the mission-select screen.
## Full-background image (cropped to fill the card at any size), a dark gradient overlay so the
## text stays readable, the mission title and a short description. Locked cards are muted, show a
## lock icon and cannot be clicked; the playable card glows, lifts on hover and emits `chosen`.

signal chosen

const COPPER := Color(0.92, 0.52, 0.2)
const CREAM := Color(1.0, 0.94, 0.86)

var texture: Texture2D
var title := ""
var tag := ""
var desc := ""
var locked := true
var _hover := 0.0
var _t := 0.0
static var _shade: GradientTexture2D

## One smooth vertical gradient shared by all cards (no banding).
static func shade() -> GradientTexture2D:
	if _shade == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
		g.colors = PackedColorArray([Color(0.01, 0.02, 0.04, 0.12), Color(0.01, 0.02, 0.04, 0.22), Color(0.01, 0.02, 0.04, 0.7), Color(0.01, 0.02, 0.04, 0.9)])
		_shade = GradientTexture2D.new()
		_shade.gradient = g
		_shade.width = 4
		_shade.height = 256
		_shade.fill_from = Vector2(0, 0)
		_shade.fill_to = Vector2(0, 1)
	return _shade

func _init(tex_path: String = "", t: String = "", tg: String = "", d: String = "", is_locked := true) -> void:
	if tex_path != "" and ResourceLoader.exists(tex_path):
		texture = load(tex_path)
	title = t
	tag = tg
	desc = d
	locked = is_locked
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(240, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	clip_contents = true

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		chosen.emit()

func _process(delta: float) -> void:
	_t += delta
	var over := get_global_rect().has_point(get_global_mouse_position()) or has_focus()
	_hover = move_toward(_hover, 1.0 if (over and not locked) else 0.0, delta * 5.0)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var r := Rect2(Vector2.ZERO, size)
	# background image, cropped to cover the card (zooms in slightly on hover)
	if texture:
		var ts := texture.get_size()
		var k := maxf(w / ts.x, h / ts.y) * (1.0 + 0.04 * _hover)
		var dw := ts.x * k
		var dh := ts.y * k
		var mod := Color(1.08, 1.08, 1.08) if not locked else Color(0.62, 0.64, 0.68)
		draw_texture_rect(texture, Rect2((w - dw) / 2.0, (h - dh) / 2.0, dw, dh), false, mod)
	else:
		draw_rect(r, Color(0.08, 0.1, 0.14))
	# dark overlay: light at the top, darker where the text sits
	draw_texture_rect(MissionCard.shade(), r, false)
	if locked:
		draw_rect(r, Color(0.04, 0.05, 0.07, 0.18))
	# text: tag, title, description (sizes scale with the card)
	var s := clampf(h / 260.0, 0.75, 1.6)
	var pad := 22.0 * s
	var title_sz := int(30 * s)
	var desc_sz := int(15 * s)
	var tag_sz := int(12 * s)
	var f_semi := FUI.font("brogame")       # the game's display font
	var f_reg := FUI.font("brogame")
	var f_mono := FUI.font("JetBrainsMono-SemiBold")
	var desc_lines := _wrap(desc, f_reg, desc_sz, w - pad * 2.0)
	var y := h - pad - desc_lines.size() * desc_sz * 1.35
	for i in desc_lines.size():
		draw_string(f_reg, Vector2(pad, y + (i + 1) * desc_sz * 1.35), desc_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, desc_sz, Color(CREAM, 0.6 if locked else 0.9))
	draw_string(f_semi, Vector2(pad, y - 4.0 * s), title, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, title_sz, Color(1, 1, 1, 0.65 if locked else 1.0))
	draw_string(f_mono, Vector2(pad, y - title_sz - 12.0 * s), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_sz, Color(0.6, 0.65, 0.7) if locked else COPPER)
	# top-right badge: lock or play
	if locked:
		var c := Vector2(w - 34.0 * s, 34.0 * s)
		draw_circle(c, 20.0 * s, Color(0, 0, 0, 0.55))
		draw_arc(c, 20.0 * s, 0, TAU, 32, Color(1, 1, 1, 0.25), 1.5, true)
		_lock_icon(c, 9.0 * s, Color(0.85, 0.87, 0.9))
		var lt := "LOCKED"
		var lw := f_mono.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_sz).x
		draw_string(f_mono, Vector2(w - 62.0 * s - lw, 39.0 * s), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_sz, Color(0.8, 0.82, 0.85, 0.8))
	else:
		var bt := "▶  PLAY MISSION"
		var bw := f_mono.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s)).x + 28.0 * s
		var br := Rect2(w - bw - 18.0 * s, 18.0 * s, bw, 34.0 * s)
		draw_rect(br, COPPER.lerp(Color(1, 0.7, 0.35), _hover))
		draw_string(f_mono, br.position + Vector2(14.0 * s, br.size.y * 0.68), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(0.08, 0.04, 0.02))
		var ac := "AVAILABLE"
		draw_circle(Vector2(pad + 5.0 * s, 32.0 * s), 5.0 * s, Color(0.3, 1.0, 0.55, 0.6 + 0.4 * sin(_t * 3.0)))
		draw_string(f_mono, Vector2(pad + 16.0 * s, 37.0 * s), ac, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_sz, Color(0.6, 1.0, 0.75))
	# frame: glowing copper for the playable card, thin grey for locked ones
	if locked:
		draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
	else:
		var glow := 0.7 + 0.2 * sin(_t * 2.2) + 0.3 * _hover
		draw_rect(r, Color(COPPER, glow), false, 3.0)
		for i in range(3, 9):
			draw_rect(r.grow(-i), Color(COPPER, glow * 0.12 * (1.0 - (i - 3) / 6.0)), false, 1.0)

func _lock_icon(c: Vector2, u: float, col: Color) -> void:
	draw_rect(Rect2(c.x - u, c.y - u * 0.2, u * 2.0, u * 1.5), col)
	draw_arc(c + Vector2(0, -u * 0.2), u * 0.65, PI, TAU, 16, col, u * 0.32, true)
	draw_rect(Rect2(c.x - u * 0.15, c.y + u * 0.25, u * 0.3, u * 0.55), Color(0, 0, 0, 0.6))

func _wrap(text: String, f: Font, sz: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var t := word if line == "" else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out
