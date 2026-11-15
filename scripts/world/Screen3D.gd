extends StaticBody3D
## A wall monitor: a 2D panel (or a 3D view) rendered onto a screen in the room.
## Look at it and press E to open it full view; you can then click on it.

var viewport: SubViewport
var screen_name := "screen"
var size_m := Vector2.ONE
var _content: Node

## Monitor hardware: a casing that suits the room (gunmetal console in launch control, white
## composite in the satellite, rack-mount unit at the ground station, slim black display in the
## analysis centre), a recessed glowing screen behind glass, the unit's name engraved on the top
## bezel (so titles can never float over other signs), status LEDs and small hardware buttons.
const CASINGS := {
	"launch": {"body": Color(0.15, 0.16, 0.18), "metal": 0.75, "rough": 0.35, "trim": Color(0.95, 0.62, 0.22), "border": 0.075},
	"space": {"body": Color(0.86, 0.87, 0.89), "metal": 0.05, "rough": 0.55, "trim": Color(0.22, 0.65, 0.95), "border": 0.06},
	"ground": {"body": Color(0.5, 0.52, 0.52), "metal": 0.55, "rough": 0.45, "trim": Color(0.3, 0.85, 0.55), "border": 0.07},
	"user": {"body": Color(0.05, 0.055, 0.06), "metal": 0.25, "rough": 0.3, "trim": Color(0.55, 0.85, 0.55), "border": 0.035},
}
var casing := ""
var _led_status: MeshInstance3D
var _led_link: MeshInstance3D
var _panel_ref: Node
var _tick := 0.0

static func _emit(c: Color, e := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

func setup(sz: Vector2, pixels: Vector2i, title: String = "", title_color: Color = UI.COLOR_ACCENT, prompt_name: String = "") -> void:
	size_m = sz
	screen_name = prompt_name if prompt_name != "" else (title.capitalize() if title != "" else "screen")
	if casing == "":
		casing = LevelFlow.current_id() if LevelFlow.index >= 0 else "launch"
	var cs_def: Dictionary = CASINGS.get(casing, CASINGS["launch"])
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

	var b: float = cs_def["border"] * clampf(minf(size_m.x, size_m.y) / 1.6, 0.6, 1.3)
	var top := 0.095 if title != "" else b
	if minf(size_m.x, size_m.y) < 0.8:
		top = b
	var body_m := PartModels.mat(cs_def["body"], cs_def["metal"], cs_def["rough"])
	var trim: Color = cs_def["trim"]
	var cw := size_m.x + 2.0 * b
	var ch := size_m.y + b + top
	var cy := (top - b) / 2.0
	# casing with a chamfered look: a deep body and a slightly smaller front plate
	add_child(PartModels.box(Vector3(cw - 0.02, ch - 0.02, 0.12), body_m, Vector3(0, cy, -0.07)))
	add_child(PartModels.box(Vector3(cw, ch, 0.03), body_m, Vector3(0, cy, -0.018)))
	# recessed black frame around the panel
	add_child(PartModels.box(Vector3(size_m.x + 0.03, size_m.y + 0.03, 0.01), PartModels.mat(Color(0.01, 0.012, 0.015), 0.2, 0.6), Vector3(0, 0, -0.002)))
	# thin accent line under the nameplate band
	if title != "" and top > b:
		add_child(PartModels.box(Vector3(cw - 0.06, 0.004, 0.004), _emit(trim, 0.8), Vector3(0, size_m.y / 2.0 + 0.018, 0.0)))
	# wall bracket behind
	add_child(PartModels.box(Vector3(minf(cw * 0.4, 0.6), minf(ch * 0.4, 0.4), 0.1), PartModels.mat(Color(0.2, 0.21, 0.23), 0.7, 0.4), Vector3(0, cy, -0.17)))

	match casing:
		"space":
			# grab handles either side, like ISS laptops and panels
			for sx in [-1.0, 1.0]:
				var hx: float = sx * (cw / 2.0 + 0.05)
				add_child(PartModels.box(Vector3(0.025, ch * 0.6, 0.025), PartModels.mat(Color(0.9, 0.75, 0.2), 0.3, 0.4), Vector3(hx, cy, 0.03)))
				for sy in [-1.0, 1.0]:
					add_child(PartModels.box(Vector3(0.06, 0.025, 0.06), body_m, Vector3(hx - sx * 0.02, cy + sy * ch * 0.3, 0.0)))
		"ground":
			# 19-inch rack ears with handles and screws
			for sx in [-1.0, 1.0]:
				var ex: float = sx * (cw / 2.0 + 0.04)
				add_child(PartModels.box(Vector3(0.08, ch, 0.02), body_m, Vector3(ex, cy, -0.01)))
				add_child(PartModels.box(Vector3(0.02, ch * 0.5, 0.05), PartModels.mat(Color(0.75, 0.76, 0.78), 0.9, 0.25), Vector3(ex, cy, 0.03)))
				for sy in [-1.0, 1.0]:
					add_child(PartModels.cyl(0.012, 0.012, 0.01, PartModels.mat(Color(0.8, 0.8, 0.82), 0.9, 0.3), Vector3(ex, cy + sy * ch * 0.4, 0.002), Vector3(90, 0, 0)))

	# The picture: a slightly recessed, self-lit screen
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size_m
	quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = viewport.get_texture()
	m.albedo_color = Color(1.06, 1.06, 1.06)
	quad.material_override = m
	quad.position = Vector3(0, 0, 0.004)
	add_child(quad)
	# Glass in front: catches reflections of the room lights
	var glass := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = size_m
	glass.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.7, 0.8, 0.9, 0.035)
	gm.metallic = 0.0
	gm.roughness = 0.05
	gm.metallic_specular = 0.9
	gm.cull_mode = BaseMaterial3D.CULL_BACK
	glass.material_override = gm
	glass.position = Vector3(0, 0, 0.009)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	# a faint diagonal sheen across the glass
	var sheen := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = size_m
	sheen.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.5, 0.58, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	sm.albedo_texture = gt
	sheen.material_override = sm
	sheen.position = Vector3(0, 0, 0.011)
	sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheen)

	# Nameplate engraved in the top bezel
	if title != "" and top > b:
		var l := Label3D.new()
		l.text = title
		l.font = FUI.font("Inter-SemiBold")
		l.font_size = 48
		l.pixel_size = clampf(0.0011 * minf(size_m.x / 2.0, 1.25), 0.0008, 0.0013)
		l.outline_size = 0
		l.modulate = Color(trim.lerp(Color(0.8, 0.82, 0.85), 0.35), 0.85) if casing != "space" else Color(0.15, 0.35, 0.55)
		l.position = Vector3(-size_m.x / 2.0 + 0.02, size_m.y / 2.0 + top / 2.0 + 0.008, 0.003)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# never wider than the bezel (leaves room for the LEDs on the right)
		var tw := FUI.font("Inter-SemiBold").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x * l.pixel_size
		var room_w := size_m.x - 0.2
		if tw > room_w:
			l.pixel_size *= room_w / tw
		add_child(l)
	# Status LEDs (power, data link, unit status) and tiny hardware buttons on the bottom bezel
	var ly := -size_m.y / 2.0 - b / 2.0
	var led_r := clampf(b * 0.16, 0.006, 0.012)
	var leds_x := size_m.x / 2.0 - 0.02
	if title != "" and top > b:
		ly = size_m.y / 2.0 + top / 2.0 + 0.008
	add_child(PartModels.ball(led_r, _emit(Color(0.2, 1.0, 0.45), 2.5), Vector3(leds_x, ly, 0.004)))
	_led_link = PartModels.ball(led_r, _emit(Color(0.25, 0.75, 1.0), 2.5), Vector3(leds_x - led_r * 4.0, ly, 0.004))
	add_child(_led_link)
	_led_status = PartModels.ball(led_r, _emit(Color(0.2, 1.0, 0.45), 2.5), Vector3(leds_x - led_r * 8.0, ly, 0.004))
	add_child(_led_status)
	if b >= 0.05 and size_m.x > 1.2:
		var btn := PartModels.mat(Color(0.08, 0.085, 0.09), 0.4, 0.5)
		for i in 5:
			var bx := -size_m.x / 2.0 + 0.06 + i * 0.075
			add_child(PartModels.box(Vector3(0.05, b * 0.42, 0.012), btn, Vector3(bx, -size_m.y / 2.0 - b / 2.0, 0.004)))
		var maker := Label3D.new()
		maker.text = {"launch": "HYADES  LCC-AV7", "space": "HYADES  FLT-DSP", "ground": "HYADES  GS-RK19", "user": "HYADES  GEO-WS"}.get(casing, "HYADES")
		maker.font_size = 32
		maker.pixel_size = 0.0011
		maker.outline_size = 0
		maker.modulate = Color(trim, 0.55) if casing != "space" else Color(0.3, 0.35, 0.4)
		maker.position = Vector3(size_m.x / 2.0 - 0.14, -size_m.y / 2.0 - b / 2.0, 0.003)
		maker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(maker)

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.25 or _led_status == null:
		return
	_tick = 0.0
	# data link LED flickers; status LED follows the panel's status (if it reports one)
	_led_link.visible = randf() > 0.25
	if _panel_ref and is_instance_valid(_panel_ref) and "status" in _panel_ref:
		var lvl: int = _panel_ref.status
		var col := AV.level_color(lvl)
		var mat: StandardMaterial3D = _led_status.material_override if _led_status.material_override else null
		if mat == null:
			mat = _emit(col)
			_led_status.material_override = mat
		mat.albedo_color = col
		mat.emission = col
		_led_status.visible = lvl < 3 or int(Time.get_ticks_msec() / 400) % 2 == 0

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
	_panel_ref = panel

## Shows a full-bleed instrument display (an AV.Display): no extra margin, it draws its own frame.
func set_display(display: Control) -> void:
	clear()
	display.size = Vector2(viewport.size)
	viewport.add_child(display)
	_content = display
	_panel_ref = display

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
