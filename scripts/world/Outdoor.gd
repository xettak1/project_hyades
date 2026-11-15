class_name Outdoor
extends RefCounted
## Shared kit for the world OUTSIDE the level buildings: real sky, sun, terrain, clouds, trees,
## lattice towers, and see-through glass window walls. Everything is real 3D geometry
## (no pictures), kept light for a laptop GPU: one shadowed sun, simple meshes, MultiMesh for trees.

# ---------------------------------------------------------------- sky and light
## Daylight (or dusk) sky + sun. Returns {"env": Environment, "sky": ProceduralSkyMaterial, "sun": DirectionalLight3D}.
static func sky(parent: Node, top: Color, horizon: Color, ground: Color, sun_rot: Vector3, sun_energy: float, sun_color: Color = Color(1, 0.97, 0.9)) -> Dictionary:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.ground_horizon_color = horizon.darkened(0.2)
	sm.ground_bottom_color = ground
	sm.sun_angle_max = 20.0
	sm.sun_curve = 0.1
	var sk := Sky.new()
	sk.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sk
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.fog_enabled = true
	e.fog_light_color = horizon
	e.fog_density = 0.0006
	e.fog_aerial_perspective = 0.5
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = sun_energy
	sun.light_color = sun_color
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	parent.add_child(sun)
	return {"env": e, "sky": sm, "sun": sun}

## Deep space: black sky, hard sunlight, stars.
static func space(parent: Node, sun_rot: Vector3) -> Dictionary:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.006)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.36, 0.45)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = 2.2
	sun.light_color = Color(1, 0.98, 0.94)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	parent.add_child(sun)
	stars(parent, 1200, 2600.0)
	return {"env": e, "sun": sun}

static func stars(parent: Node, count: int, radius: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star := SphereMesh.new()
	star.radius = radius * 0.0012
	star.height = radius * 0.0024
	star.radial_segments = 4
	star.rings = 2
	mm.mesh = star
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in count:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.5, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), d * radius))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = PartModels.mat(Color(1, 1, 1), 0.0, 0.5, 3.0)
	parent.add_child(mmi)

# ---------------------------------------------------------------- terrain and scenery
static func flat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

static func ground(parent: Node, size: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = flat(color)
	mi.position = pos + Vector3(0, -0.02, 0)
	parent.add_child(mi)
	return mi

static func slab(parent: Node, size: Vector3, pos: Vector3, color: Color, rough := 0.9) -> MeshInstance3D:
	var mi := PartModels.box(size, flat(color, rough), pos)
	parent.add_child(mi)
	return mi

## Low rolling hills on the horizon (flattened spheres).
static func hills(parent: Node, count: int, radius: float, color: Color, seed := 3, keep_out_dir := Vector3.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var a := rng.randf() * TAU
		var d := radius * rng.randf_range(0.8, 1.15)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 16
		s.rings = 8
		mi.mesh = s
		var w := rng.randf_range(radius * 0.18, radius * 0.4)
		mi.scale = Vector3(w, rng.randf_range(radius * 0.03, radius * 0.08), w * rng.randf_range(0.6, 1.0))
		mi.position = p
		mi.material_override = flat(color.lerp(Color(0.35, 0.4, 0.3), rng.randf() * 0.3))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

## Puffy clouds made of a few flattened spheres each.
static func clouds(parent: Node, count: int, area: float, height: float, seed := 5, tint := Color(1, 1, 1)) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = tint * 0.25
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 12
	s.rings = 6
	for i in count:
		var c := Vector3(rng.randf_range(-area, area), height * rng.randf_range(0.85, 1.2), rng.randf_range(-area, area))
		var size := rng.randf_range(40.0, 110.0)
		for k in rng.randi_range(3, 6):
			var mi := MeshInstance3D.new()
			mi.mesh = s
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = c + Vector3(rng.randf_range(-1, 1) * size, rng.randf_range(0, 0.3) * size, rng.randf_range(-0.5, 0.5) * size)
			mi.scale = Vector3(size * rng.randf_range(0.6, 1.0), size * rng.randf_range(0.25, 0.4), size * rng.randf_range(0.5, 0.8))
			root.add_child(mi)
	return root

## Trees as one MultiMesh (cheap). Avoids the rectangle `keep_out` (x0, z0, x1, z1).
## Scatter a real plant model (e.g. "weed_plant") across the ground: one MultiMesh per mesh variant
## in the model, so hundreds of plants cost only a few draw calls. points: Array of [pos, yaw, scale].
## The model is sized so its tallest variant is `height` metres.
static func scatter(parent: Node, model: String, points: Array, height := 1.0) -> void:
	var path := "res://assets/models/%s.glb" % model
	if not ResourceLoader.exists(path) or points.is_empty():
		return
	var root: Node3D = load(path).instantiate()
	var variants: Array = []      # [mesh, basis, offset to stand on the ground]
	var tallest := 0.001
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p and p != root and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var ab: AABB = Transform3D(t.basis, Vector3.ZERO) * mi.mesh.get_aabb()
		tallest = maxf(tallest, ab.size.y)
		variants.append([mi.mesh, t.basis, -Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)])
	root.free()
	if variants.is_empty():
		return
	var k := height / tallest
	var groups: Array = []
	for v in variants:
		groups.append([])
	for i in points.size():
		groups[i % variants.size()].append(points[i])
	for vi in variants.size():
		var v: Array = variants[vi]
		var pts: Array = groups[vi]
		if pts.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = v[0]
		mm.instance_count = pts.size()
		for i in pts.size():
			var sc: float = k * float(pts[i][2])
			var b := Basis(Vector3.UP, float(pts[i][1])) * Basis().scaled(Vector3.ONE * sc) * (v[1] as Basis)
			mm.set_instance_transform(i, Transform3D(b, (pts[i][0] as Vector3) + Basis(Vector3.UP, float(pts[i][1])) * (v[2] as Vector3) * sc))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if height < 1.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mmi)

static func trees(parent: Node, count: int, area: float, center := Vector3.ZERO, keep_out := Rect2(), seed := 7, scale := 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var crown := SphereMesh.new()
	crown.radius = 2.4 * scale
	crown.height = 4.2 * scale
	crown.radial_segments = 8
	crown.rings = 5
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25 * scale
	trunk.bottom_radius = 0.35 * scale
	trunk.height = 3.0 * scale
	trunk.radial_segments = 6
	var xs: Array = []
	var tries := 0
	while xs.size() < count and tries < count * 6:
		tries += 1
		var p := center + Vector3(rng.randf_range(-area, area), 0, rng.randf_range(-area, area))
		if keep_out.has_point(Vector2(p.x, p.z)):
			continue
		xs.append([p, rng.randf_range(0.7, 1.4)])
	for part in [[crown, Color(0.18, 0.38, 0.14), 3.6], [trunk, Color(0.35, 0.25, 0.15), 1.5]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = xs.size()
		for i in xs.size():
			var sc: float = xs[i][1]
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), xs[i][0] + Vector3(0, part[2] * scale * sc, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = flat(part[1])
		parent.add_child(mmi)

## A steel lattice tower (launch tower, antenna mast).
static func lattice(parent: Node, pos: Vector3, height: float, base: float, color: Color, level_step := 6.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var m := PartModels.mat(color, 0.6, 0.5)
	var leg := base * 0.06
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			root.add_child(PartModels.box(Vector3(leg, height, leg), m, Vector3(sx * base / 2, height / 2, sz * base / 2)))
	var y := level_step
	while y < height:
		for side in 4:
			var horiz := PartModels.box(Vector3(base, leg * 0.6, leg * 0.6), m, Vector3(0, y, base / 2))
			horiz.rotation_degrees.y = side * 90.0
			horiz.position = Vector3(0, y, base / 2).rotated(Vector3.UP, deg_to_rad(side * 90.0))
			root.add_child(horiz)
			var diag := PartModels.box(Vector3(sqrt(base * base + level_step * level_step), leg * 0.5, leg * 0.5), m, Vector3.ZERO)
			diag.position = Vector3(0, y - level_step / 2, base / 2).rotated(Vector3.UP, deg_to_rad(side * 90.0))
			diag.rotation = Vector3(0, deg_to_rad(side * 90.0), atan2(level_step, base) * (1 if side % 2 == 0 else -1))
			root.add_child(diag)
		y += level_step
	return root

## Blinking red aviation light.
static func beacon(parent: Node, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1, 0.15, 0.1)
	l.light_energy = 2.0
	l.omni_range = 6.0
	parent.add_child(l)
	parent.add_child(PartModels.ball(0.35, PartModels.mat(Color(1, 0.2, 0.15), 0.0, 0.4, 3.0), pos))
	return l

# ---------------------------------------------------------------- glass window walls
static func glass_mat(tint := Color(0.75, 0.88, 1.0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint, 0.1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.3
	m.roughness = 0.04
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## A wall along X (facing ±Z) with one big window opening, a frame, mullions and real glass.
## centre = middle of the wall at floor level; width/height = wall size; opening y0..y1 (sill / head)
## and side margin. The glass has collision so the player cannot walk through it.
static func window_wall(parent: Node, centre: Vector3, width: float, height: float, y0: float, y1: float, margin: float, wall_mat: Material, frame_color := Color(0.12, 0.13, 0.15), mullion_every := 2.4, yaw := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = centre
	root.rotation_degrees.y = yaw
	parent.add_child(root)
	var t := 0.2
	var ow := width - 2.0 * margin
	RoomKit.solid(root, Vector3(width, y0, t), Vector3(0, y0 / 2.0, 0), wall_mat)                       # below sill
	RoomKit.solid(root, Vector3(width, height - y1, t), Vector3(0, (height + y1) / 2.0, 0), wall_mat)    # above head
	RoomKit.solid(root, Vector3(margin, y1 - y0, t), Vector3(-width / 2.0 + margin / 2.0, (y0 + y1) / 2.0, 0), wall_mat)
	RoomKit.solid(root, Vector3(margin, y1 - y0, t), Vector3(width / 2.0 - margin / 2.0, (y0 + y1) / 2.0, 0), wall_mat)
	var fm := PartModels.mat(frame_color, 0.7, 0.35)
	root.add_child(PartModels.box(Vector3(ow, 0.08, 0.3), fm, Vector3(0, y0, 0)))
	root.add_child(PartModels.box(Vector3(ow, 0.08, 0.3), fm, Vector3(0, y1, 0)))
	var n := maxi(1, int(round(ow / mullion_every)))
	for i in n + 1:
		var x := -ow / 2.0 + ow * i / n
		root.add_child(PartModels.box(Vector3(0.07, y1 - y0, 0.14), fm, Vector3(x, (y0 + y1) / 2.0, 0)))
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(ow, y1 - y0)
	glass.mesh = q
	glass.material_override = glass_mat()
	glass.position = Vector3(0, (y0 + y1) / 2.0, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(ow, y1 - y0, 0.1)
	cs.shape = bs
	body.position = Vector3(0, (y0 + y1) / 2.0, 0)
	body.add_child(cs)
	root.add_child(body)
	return root

## Room shell (floor, ceiling, walls) where the FRONT wall (−Z) is a big window wall.
static func shell_with_window(parent: Node, room: Vector3, floor_m: Material, wall_m: Material, ceil_m: Material, y0: float, y1: float, margin: float, frame_color := Color(0.12, 0.13, 0.15)) -> void:
	var hx := room.x / 2.0
	var hz := room.z / 2.0
	RoomKit.solid(parent, Vector3(room.x, 0.2, room.z), Vector3(0, -0.1, 0), floor_m)
	RoomKit.solid(parent, Vector3(room.x, 0.2, room.z), Vector3(0, room.y + 0.1, 0), ceil_m)
	RoomKit.solid(parent, Vector3(room.x, room.y, 0.2), Vector3(0, room.y / 2, hz + 0.1), wall_m)
	RoomKit.solid(parent, Vector3(0.2, room.y, room.z), Vector3(-hx - 0.1, room.y / 2, 0), wall_m)
	RoomKit.solid(parent, Vector3(0.2, room.y, room.z), Vector3(hx + 0.1, room.y / 2, 0), wall_m)
	window_wall(parent, Vector3(0, 0, -hz - 0.1), room.x, room.y, y0, y1, margin, wall_m, frame_color)

## Indoor lamps that don't fight the daylight.
static func lamps(parent: Node, room: Vector3, color: Color, energy: float, spacing := 5.0) -> void:
	var x := -room.x / 2.0 + spacing * 0.6
	while x < room.x / 2.0:
		var z := -room.z / 2.0 + spacing * 0.6
		while z < room.z / 2.0:
			var l := OmniLight3D.new()
			l.position = Vector3(x, room.y - 0.4, z)
			l.omni_range = spacing * 1.6
			l.light_energy = energy
			l.light_color = color
			parent.add_child(l)
			z += spacing
		x += spacing
