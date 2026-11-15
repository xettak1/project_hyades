extends Node3D
## LEVEL 1 OUTSIDE: the launch complex seen through the launch-control windows.
## Coastal launch site: pad with flame trench, service tower, the rocket, lightning masts,
## water tower, crawlerway, scrub land, sea and hills on the horizon, clouds overhead.

var rocket: Node3D           # moves during the launch
var flame: Node3D
var exhaust: CPUParticles3D
var smoke: CPUParticles3D
var glow: OmniLight3D
var pad := Vector3(-18, 0, 112)   # relative to this node (placed just outside the window wall)
var rocket_h := 62.0
var arm: Node3D

func _ready() -> void:
	# Land, sea, roads
	Outdoor.ground(self, 4000.0, Color(0.42, 0.47, 0.3))
	Outdoor.slab(self, Vector3(3000, 0.1, 1400), Vector3(0, -0.05, 1450), Color(0.12, 0.28, 0.42), 0.15)     # ocean behind the pad
	Outdoor.slab(self, Vector3(3000, 0.12, 40), Vector3(0, 0.0, 740), Color(0.85, 0.8, 0.65))                   # beach
	Outdoor.slab(self, Vector3(16, 0.08, 160), Vector3(pad.x, 0.03, pad.z / 2.0 - 4.0), Color(0.55, 0.53, 0.5))  # crawlerway
	Outdoor.slab(self, Vector3(90, 0.6, 90), pad + Vector3(0, 0.3, 0), Color(0.62, 0.6, 0.57))                  # pad hardstand
	Outdoor.slab(self, Vector3(12, 0.2, 40), pad + Vector3(0, 0.62, 18), Color(0.2, 0.2, 0.22))                  # flame trench
	Outdoor.hills(self, 14, 1600.0, Color(0.36, 0.42, 0.28), 4)
	Outdoor.trees(self, 260, 420.0, Vector3(0, 0, 140), Rect2(-140, -40, 240, 300), 9)

	# Service tower with a swing arm and lightning masts
	Outdoor.lattice(self, pad + Vector3(-18, 0.6, 0), 74.0, 9.0, Color(0.55, 0.12, 0.1), 6.0)
	arm = Node3D.new()
	arm.position = pad + Vector3(-13.5, 50.0, 0)
	add_child(arm)
	arm.add_child(PartModels.box(Vector3(9.0, 1.6, 2.2), PartModels.mat(Color(0.5, 0.5, 0.52), 0.6, 0.5), Vector3(4.5, 0, 0)))
	for p in [Vector3(-38, 0, -30), Vector3(30, 0, -30), Vector3(-38, 0, 34), Vector3(30, 0, 34)]:
		add_child(PartModels.cyl(0.4, 0.9, 90.0, PartModels.mat(Color(0.8, 0.8, 0.8), 0.5, 0.5), pad + p + Vector3(0, 45, 0)))
		Outdoor.beacon(self, pad + p + Vector3(0, 90.5, 0))
	# Water tower and a few buildings
	add_child(PartModels.cyl(5.0, 5.0, 8.0, PartModels.mat(Color(0.85, 0.85, 0.85), 0.4, 0.5), pad + Vector3(70, 50, -20)))
	Outdoor.lattice(self, pad + Vector3(70, 0, -20), 46.0, 6.0, Color(0.7, 0.7, 0.7), 8.0)
	for b in [[Vector3(90, 0, 60), Vector3(30, 14, 20)], [Vector3(-110, 0, 20), Vector3(26, 10, 40)], [Vector3(60, 0, -60), Vector3(40, 30, 30)]]:
		Outdoor.slab(self, b[1], b[0] + Vector3(0, b[1].y / 2, 0), Color(0.82, 0.82, 0.8), 0.8)

	# The rocket
	rocket = Node3D.new()
	rocket.position = pad + Vector3(0, 0.6, 0)
	add_child(rocket)
	var model := ModelLib.fit("ex_sls", rocket_h, "height")
	if model:
		rocket.add_child(model)
	else:
		rocket.add_child(PartModels.cyl(4.2, 4.2, rocket_h, PartModels.mat(Color(0.95, 0.6, 0.25)), Vector3(0, rocket_h / 2, 0)))
	flame = Node3D.new()
	flame.visible = false
	rocket.add_child(flame)
	var fm := PartModels.mat(Color(1.0, 0.7, 0.3), 0.0, 1.0, 6.0)
	flame.add_child(PartModels.cyl(1.2, 5.0, 26.0, fm, Vector3(0, -13.0, 0)))
	var core := PartModels.mat(Color(1.0, 0.95, 0.8), 0.0, 1.0, 10.0)
	flame.add_child(PartModels.cyl(0.6, 2.6, 14.0, core, Vector3(0, -7.0, 0)))
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.65, 0.3)
	glow.omni_range = 160.0
	glow.light_energy = 0.0
	glow.position = Vector3(0, -6, 0)
	rocket.add_child(glow)

	exhaust = _particles(Color(1.0, 0.75, 0.35), 220, 0.9, 2.2, Vector3(0, -1, 0), 55.0, 8.0, true)
	rocket.add_child(exhaust)
	smoke = _particles(Color(0.85, 0.83, 0.8), 260, 7.0, 7.0, Vector3(0, 0.15, 1), 22.0, 70.0, false)
	smoke.position = pad + Vector3(0, 3.0, 18.0)
	add_child(smoke)

	Outdoor.clouds(self, 22, 1400.0, 700.0, 12)

func _particles(color: Color, amount: int, size: float, life: float, dir: Vector3, speed: float, spread: float, glow_on: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 1.5 if not glow_on else 0.0, 0)
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.scale_amount_min = size
	p.scale_amount_max = size * 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.5))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(color, 0.95))
	grad.set_color(1, Color(color.darkened(0.3), 0.0))
	p.color_ramp = grad
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	if glow_on:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	p.mesh = mesh
	return p

## Position of the rocket in world space (for the cameras).
func rocket_top() -> Vector3:
	return rocket.global_position + Vector3(0, rocket_h * 0.8, 0)
