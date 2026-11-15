class_name RoomKit
extends RefCounted
## Shared building blocks for every walkable level room (Level 1 lab and the segment rooms):
## the worn-metal look, the panorama lighting, solid walls and wall signs.

const TEX_FLOOR := "res://assets/textures/metal_plate_diff.jpg"
const TEX_WALL := "res://assets/textures/blue_metal_plate_diff.jpg"   # blue painted metal plate (walls and roof)
const HDRI := "res://assets/textures/hdri_indoor.jpg"

## Tiled texture material. scale = repeats per metre (world-space triplanar, so any box works).
## Falls back to a plain colour if the texture file is missing.
static func tex_mat(path: String, scale: float, tint: Color, metal: float, rough: float, fallback: Color) -> StandardMaterial3D:
	if not ResourceLoader.exists(path):
		return PartModels.mat(fallback, 0.0, 0.8)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.metallic = metal
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## WorldEnvironment with panorama reflections, soft shadows and glow, plus a grid of ceiling lamps.
static func environment(parent: Node, room: Vector3, light: Color, lamp: float) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = light * 0.6
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if ResourceLoader.exists(HDRI):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(HDRI)
		var sky := Sky.new()
		sky.sky_material = pano
		e.sky = sky
		e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		e.ambient_light_sky_contribution = 0.55
		e.ambient_light_energy = 0.9
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.4
	we.environment = e
	parent.add_child(we)
	var hx := room.x / 2.0
	var hz := room.z / 2.0
	var x := -hx + 4.0
	while x < hx:
		var z := -hz + 3.0
		while z < hz:
			var l := OmniLight3D.new()
			l.position = Vector3(x, room.y - 0.5, z)
			l.omni_range = 9.0 + room.y * 0.3
			l.light_energy = lamp
			l.light_color = light
			parent.add_child(l)
			z += 6.0
		x += 6.0

static func solid(parent: Node, size: Vector3, pos: Vector3, m: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_child(PartModels.box(size, m))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	return body

static func sign(parent: Node, text: String, pos: Vector3, yaw: float, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 10
	l.modulate = color
	l.position = pos
	l.rotation_degrees.y = yaw
	parent.add_child(l)
	return l

## Floor, ceiling and four walls in the worn-metal look. floor_tint lets each room feel different.
static func shell(parent: Node, room: Vector3, floor_tint: Color = Color.WHITE) -> void:
	var hx := room.x / 2.0
	var hz := room.z / 2.0
	var floor_m := tex_mat(TEX_FLOOR, 0.45, floor_tint, 0.55, 0.6, Color(0.3, 0.3, 0.32))
	var wall_m := tex_mat(TEX_WALL, 0.28, Color(1.45, 1.45, 1.45), 0.45, 0.5, Color(0.5, 0.5, 0.5))
	var ceil_m := tex_mat(TEX_WALL, 0.22, Color(1.05, 1.05, 1.05), 0.45, 0.55, Color(0.4, 0.4, 0.4))
	solid(parent, Vector3(room.x, 0.2, room.z), Vector3(0, -0.1, 0), floor_m)
	solid(parent, Vector3(room.x, 0.2, room.z), Vector3(0, room.y + 0.1, 0), ceil_m)
	solid(parent, Vector3(room.x, room.y, 0.2), Vector3(0, room.y / 2, -hz - 0.1), wall_m)
	solid(parent, Vector3(room.x, room.y, 0.2), Vector3(0, room.y / 2, hz + 0.1), wall_m)
	solid(parent, Vector3(0.2, room.y, room.z), Vector3(-hx - 0.1, room.y / 2, 0), wall_m)
	solid(parent, Vector3(0.2, room.y, room.z), Vector3(hx + 0.1, room.y / 2, 0), wall_m)
