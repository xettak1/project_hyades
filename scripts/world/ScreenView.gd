extends CanvasLayer
## Full-view mode for wall screens. Press E on a screen to open it: it fills your view
## and mouse clicks go straight into it (buttons on the console, speed buttons, etc.).
## E, Esc or right-click closes it.

var player: Node
var screen: Node        # the Screen3D being viewed
var _bg: ColorRect
var _img: TextureRect
var _title: Label

func _ready() -> void:
	layer = 5
	add_to_group("screenview")
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.88)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_img = TextureRect.new()
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_img.offset_left = 30
	_img.offset_right = -30
	_img.offset_top = 50
	_img.offset_bottom = -40
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_img)
	_title = UI.label("", 20, UI.COLOR_ACCENT)
	_title.position = Vector2(30, 12)
	_title.size = Vector2(900, 30)
	add_child(_title)
	var hint := UI.label("Click to use   |   E, Esc or right-click to close", 15, UI.COLOR_MUTED)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position += Vector2(30, -32)
	hint.size = Vector2(700, 24)
	add_child(hint)
	visible = false

func _process(_d: float) -> void:
	if not visible:
		return
	var right := 30.0
	for t in get_tree().get_nodes_in_group("tutor"):
		if t.is_showing():
			right = 470.0
	_img.offset_right = -right

func is_open() -> bool:
	return visible

func open(s: Node) -> void:
	screen = s
	_img.texture = s.viewport.get_texture()
	_title.text = s.screen_name.to_upper()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.frozen = true
	get_tree().call_group("hud", "set_prompt", "")
	get_tree().call_group("tutor", "on_screen_opened", s.screen_name)

func close() -> void:
	if not visible:
		return
	visible = false
	screen = null
	get_tree().call_group("tutor", "on_screen_closed")
	if player:
		player.frozen = false
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Where the screen image is drawn on the window (it keeps its aspect ratio).
func _image_rect() -> Rect2:
	var area := _img.get_global_rect()
	var tex_size := Vector2(screen.viewport.size)
	var s := minf(area.size.x / tex_size.x, area.size.y / tex_size.y)
	var draw_size := tex_size * s
	return Rect2(area.position + (area.size - draw_size) / 2.0, draw_size)

func _input(event: InputEvent) -> void:
	if not visible or screen == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		var r := _image_rect()
		var ev: InputEventMouse = event.duplicate()
		var local: Vector2 = (event.position - r.position) / r.size * Vector2(screen.viewport.size)
		ev.position = local
		ev.global_position = local
		if ev is InputEventMouseMotion:
			(ev as InputEventMouseMotion).relative = (event as InputEventMouseMotion).relative / r.size * Vector2(screen.viewport.size)
		screen.viewport.push_input(ev, true)
		get_viewport().set_input_as_handled()
