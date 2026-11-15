extends StaticBody3D
## A wall monitor: a 2D panel (or a 3D view) rendered onto a screen in the room.
## Look at it and press E to open it full view; you can then click on it.

var viewport: SubViewport
var screen_name := "screen"
var size_m := Vector2.ONE
var _content: Node

func setup(sz: Vector2, pixels: Vector2i, title: String = "", title_color: Color = UI.COLOR_ACCENT, prompt_name: String = "") -> void:
	size_m = sz
	screen_name = prompt_name if prompt_name != "" else (title.capitalize() if title != "" else "screen")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size_m.x, size_m.y, 0.06)
	cs.shape = bs
	add_child(cs)
	viewport = SubViewport.new()
	viewport.size = pixels
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	# Bezel
	add_child(PartModels.box(Vector3(size_m.x + 0.12, size_m.y + 0.12, 0.08), PartModels.dark(), Vector3(0, 0, -0.045)))
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size_m
	quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = viewport.get_texture()
	quad.material_override = m
	add_child(quad)

	if title != "":
		var l := Label3D.new()
		l.text = title
		l.font_size = 48
		l.pixel_size = 0.004
		l.outline_size = 8
		l.modulate = title_color
		l.position = Vector3(0, size_m.y / 2.0 + 0.22, 0)
		add_child(l)

## Shows a 2D panel. The panel fills the screen.
func set_panel(panel: Control) -> void:
	clear()
	var bg := ColorRect.new()
	bg.color = UI.COLOR_BG
	bg.size = Vector2(viewport.size)
	viewport.add_child(bg)
	var margin := MarginContainer.new()
	margin.size = Vector2(viewport.size)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	viewport.add_child(margin)
	margin.add_child(panel)
	_content = bg

## Shows a 3D world (e.g. the orbit view).
func set_world(world: Node3D) -> void:
	clear()
	viewport.own_world_3d = true
	viewport.add_child(world)
	_content = world

## Shows a live camera looking into the main 3D world (e.g. the satellite camera).
## Optional 2D overlay (labels, scan line) is drawn on top of the picture.
func set_camera(cam: Camera3D, overlay_panel: Control = null) -> void:
	clear()
	viewport.own_world_3d = false
	viewport.add_child(cam)
	cam.current = true
	if overlay_panel:
		overlay_panel.size = Vector2(viewport.size)
		viewport.add_child(overlay_panel)
	_content = cam

## Adds a 2D panel over whatever is shown (used for the results report).
func overlay(panel: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	dim.size = Vector2(viewport.size)
	viewport.add_child(dim)
	var margin := MarginContainer.new()
	margin.size = Vector2(viewport.size)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	viewport.add_child(margin)
	margin.add_child(panel)

func on_focus(_f: bool) -> void:
	pass

func get_prompt() -> String:
	return "[E] Use the %s screen" % screen_name

func interact() -> void:
	get_tree().call_group("screenview", "open", self)

func clear() -> void:
	for c in viewport.get_children():
		c.queue_free()
	_content = null
