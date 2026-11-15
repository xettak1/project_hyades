extends Node
## Renders the mission-select card backgrounds from the game's own 3D content.
## ART=flood|radar|lunar|wildfire  ->  res://assets/textures/mission_<art>.jpg (1280 x 720)
func _ready() -> void:
	if get_tree().current_scene == self:
		var d = load("res://tests/MissionArt.gd").new()
		get_tree().root.add_child.call_deferred(d)
		return
	var art := OS.get_environment("ART")
	var root := Node3D.new()
	get_tree().root.add_child(root)
	match art:
		"flood":
			MissionState.start_mission("flood_watch")
			var intro = load("res://scenes/Intro.tscn").instantiate()
			intro.set("_t", 20.5)
			get_tree().root.add_child(intro)
			await get_tree().process_frame
			for c in intro.find_children("*", "CanvasLayer", true, false):
				c.visible = false
			await get_tree().create_timer(2.5).timeout
		"radar":
			_space_env(root, 0.4)
			var e = load("res://scripts/world/EarthGlobe.gd").new()
			root.add_child(e)
			e.face(68.0, -40.0, Vector3(0, 0.15, 1).normalized(), Vector3(0, 1, 0))
			e.position = Vector3(0, -560, -420)
			var s := ModelLib.fit("sc_landsat8", 7.0, "center")
			if s:
				s.position = Vector3(3.2, 1.0, -12.0)
				s.rotation_degrees = Vector3(10, 215, -12)
				root.add_child(s)
			_cam(root, Vector3(0, 0, 0), Vector3(0.15, -0.18, -1), 50)
			await get_tree().create_timer(2.0).timeout
		"lunar":
			_space_env(root, 0.25)
			var m := ModelLib.fit("moon", 60.0, "center")
			if m:
				m.position = Vector3(-8, -26, -60)
				root.add_child(m)
			var o := ModelLib.fit("sc_mro", 5.5, "center")
			if o:
				o.position = Vector3(3.5, 2.0, -11.0)
				o.rotation_degrees = Vector3(15, 140, 10)
				root.add_child(o)
			_cam(root, Vector3(0, 0, 0), Vector3(0.05, -0.12, -1), 50)
			await get_tree().create_timer(2.0).timeout
		"wildfire":
			var o := Outdoor.sky(root, Color(0.25, 0.22, 0.32), Color(1.0, 0.5, 0.25), Color(0.35, 0.25, 0.18), Vector3(-6, -60, 0), 1.2)
			o["env"].fog_enabled = true
			o["env"].fog_light_color = Color(0.75, 0.45, 0.3)
			o["env"].fog_density = 0.006
			o["env"].glow_enabled = true
			Outdoor.ground(root, 3000.0, Color(0.5, 0.4, 0.22))
			Outdoor.hills(root, 12, 900.0, Color(0.42, 0.35, 0.2), 4)
			Outdoor.trees(root, 120, 260.0, Vector3(0, 0, -120), Rect2(-20, -20, 40, 30), 9, 1.0)
			for f in [Vector3(-30, 0, -120), Vector3(15, 0, -160), Vector3(60, 0, -210), Vector3(-80, 0, -230)]:
				_fire(root, f)
			_cam(root, Vector3(0, 6, 20), Vector3(0, -0.06, -1), 55)
			await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg("res://assets/textures/mission_%s.jpg" % art, 0.88)
	print("saved ", art)
	get_tree().quit()

func _space_env(root: Node3D, amb: float) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0.01)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.45, 0.55)
	e.ambient_light_energy = amb
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.2
	root.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.7, -0.35, -0.6), Vector3.UP)
	Outdoor.stars(root, 1500, 2500.0)

func _cam(root: Node3D, pos: Vector3, dir: Vector3, fov: float) -> void:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 5000
	root.add_child(c)
	c.position = pos
	c.look_at(pos + dir, Vector3.UP)
	c.current = true

func _fire(root: Node3D, p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.1)
	l.light_energy = 12.0
	l.omni_range = 60.0
	l.position = p + Vector3(0, 4, 0)
	root.add_child(l)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.55, 0.15)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.45, 0.1)
	fm.emission_energy_multiplier = 4.0
	for k in 7:
		var flame := PartModels.ball(1.6 + randf() * 1.2, fm, p + Vector3(randf_range(-8, 8), 0.8, randf_range(-4, 4)))
		flame.scale = Vector3(1, 1.8, 1)
		root.add_child(flame)
	var smoke := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(9, 9)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.25, 0.22, 0.2, 0.35)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = sm
	smoke.mesh = q
	smoke.amount = 120
	smoke.lifetime = 9.0
	smoke.preprocess = 9.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(8, 1, 4)
	smoke.direction = Vector3(0.3, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 5.0
	smoke.initial_velocity_max = 8.0
	smoke.gravity = Vector3(1.5, 0.5, 0)
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 3.5
	smoke.position = p + Vector3(0, 2, 0)
	root.add_child(smoke)
