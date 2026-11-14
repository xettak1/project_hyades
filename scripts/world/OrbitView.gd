extends Node3D
## Earth, the orbit line and the spacecraft. Shown on the big mission-control screen.

const SECONDS_PER_VISUAL_ORBIT := 6.0

var _earth: MeshInstance3D
var _planet: Node3D
var _sun: DirectionalLight3D
var _craft: Node3D
var _cam: Camera3D
var _points: PackedVector3Array
var _t := 0.0
var _cam_angle := 0.6
var _cam_dist := 19.0
var _cam_h := 7.0

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.01, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.27, 0.35)
	env.environment = e
	add_child(env)

	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.4
	add_child(_sun)

	var orbit := MissionState.orbit()
	var moon: bool = orbit.get("body", "earth") == "moon"
	var radius: float = OrbitPath.body_radius_km(orbit) / OrbitPath.KM_PER_UNIT
	_cam_dist = radius * 3.0
	_cam_h = radius * 1.1
	var glb_planet := ModelLib.fit("moon" if moon else "earth", radius * 2.0, "center")
	_earth = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	_earth.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.62, 0.6) if moon else Color(0.2, 0.45, 0.9)
	var textures := ["res://assets/moon.jpg", "res://assets/moon.png"] if moon else ["res://assets/earth.jpg", "res://assets/earth.png"]
	if moon:
		# Earth far in the background
		var far_earth := PartModels.ball(0.6, PartModels.mat(Color(0.2, 0.45, 0.9), 0.0, 0.5, 0.3), Vector3(-14, 4, -20))
		add_child(far_earth)
	for tex_path in textures:
		if ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path)
			mat.albedo_color = Color.WHITE
			break
	_earth.material_override = mat
	add_child(_earth)
	if glb_planet:
		# Real textured globe from assets/models replaces the plain sphere
		_earth.visible = false
		_planet = glb_planet
		add_child(glb_planet)

	_points = OrbitPath.load_points(MissionState.orbit_id, MissionState.orbit())
	var line := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in _points:
		im.surface_add_vertex(p)
	im.surface_end()
	line.mesh = im
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.albedo_color = Color(1.0, 0.8, 0.3)
	line.material_override = lmat
	add_child(line)

	_craft = Node3D.new()
	var cs := radius / 6.371   # spacecraft marker size follows the planet size
	var sc := ModelLib.fit(MissionState.mission()["env"].get("orbit_model", ""), 1.6 * cs, "center")
	if sc:
		_craft.add_child(sc)
		add_child(_craft)
	else:
		_craft.add_child(PartModels.box(Vector3(0.4, 0.4, 0.7) * cs, PartModels.mat(Color(0.95, 0.85, 0.5), 0.5, 0.4, 0.6)))
		for side in [-1.0, 1.0]:
			_craft.add_child(PartModels.box(Vector3(1.0, 0.03, 0.45) * cs, PartModels.cell_blue(), Vector3(side * 0.7, 0, 0) * cs))
		add_child(_craft)

	_cam = Camera3D.new()
	_cam.far = 500.0
	_cam.current = true
	add_child(_cam)

func _process(delta: float) -> void:
	_earth.rotate_y(delta * 0.05)
	if _planet:
		_planet.rotate_y(delta * 0.05)
	_t += delta / SECONDS_PER_VISUAL_ORBIT
	if _points.size() > 1:
		var f: float = fposmod(_t, 1.0) * float(_points.size() - 1)
		var i := int(f)
		var a: Vector3 = _points[i]
		var b: Vector3 = _points[mini(i + 1, _points.size() - 1)]
		_craft.position = a.lerp(b, f - i)
		if not b.is_equal_approx(a):
			_craft.look_at(b, Vector3.UP)
	_cam_angle += delta * 0.08
	_cam.position = Vector3(sin(_cam_angle) * _cam_dist, _cam_h, cos(_cam_angle) * _cam_dist)
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	# Sunlight comes from slightly to the side of the camera, so you see day and a sliver of night
	_sun.look_at_from_position(_cam.position.rotated(Vector3.UP, 0.7), Vector3.ZERO, Vector3.UP)
