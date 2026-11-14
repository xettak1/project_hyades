extends Node3D
## A wall monitor: a 2D panel (or a 3D view) rendered onto a screen in the room.

var viewport: SubViewport
var _content: Node

func setup(size_m: Vector2, pixels: Vector2i, title: String = "", title_color: Color = UI.COLOR_ACCENT) -> void:
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

func clear() -> void:
	for c in viewport.get_children():
		c.queue_free()
	_content = null
