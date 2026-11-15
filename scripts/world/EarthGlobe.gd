extends Node3D
## Earth seen from orbit: the NASA-textured Earth model, a cloud layer, a blue atmosphere glow,
## and helpers to put things on the surface by latitude / longitude.
## Model axes (measured): north = +Y, longitude 0 faces -Z, 90°W faces +X, 90°E faces -X.

var radius := 637.1          # 1 unit = 10 km
var spin: Node3D             # rotates with the planet; surface markers live here
var _clouds: MeshInstance3D

func _ready() -> void:
	spin = Node3D.new()
	add_child(spin)
	var e := ModelLib.fit("earth", radius * 2.0, "center")
	if e:
		spin.add_child(e)
	else:
		spin.add_child(PartModels.ball(radius, PartModels.mat(Color(0.2, 0.4, 0.8))))
	_clouds = _shell(radius * 1.006, _cloud_shader())
	spin.add_child(_clouds)
	add_child(_shell(radius * 1.03, _atmo_shader()))

static func dir_local(lat: float, lon: float) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(-sin(lo) * cos(la), sin(la), -cos(lo) * cos(la))

## A point on (or above) the surface, in spin space.
func local_point(lat: float, lon: float, height := 0.0) -> Vector3:
	return dir_local(lat, lon) * (radius + height)

func world_point(lat: float, lon: float, height := 0.0) -> Vector3:
	return spin.to_global(local_point(lat, lon, height))

func world_normal(lat: float, lon: float) -> Vector3:
	return (world_point(lat, lon) - global_position).normalized()

## Turn the planet so (lat, lon) faces direction n_world (from the planet centre),
## with north pointing towards f_world on screen.
func face(lat: float, lon: float, n_world: Vector3, f_world: Vector3) -> void:
	var t := dir_local(lat, lon)
	var fl := (Vector3.UP - t * Vector3.UP.dot(t)).normalized()
	var el := fl.cross(t)
	var nw := n_world.normalized()
	var fw := (f_world - nw * f_world.dot(nw)).normalized()
	var ew := fw.cross(nw)
	var L := Basis(el, fl, t)
	var W := Basis(ew, fw, nw)
	spin.basis = (W * L.transposed()).orthonormalized()

## Something lying flat on the surface at (lat, lon), in spin space.
func place_flat(node: Node3D, lat: float, lon: float, height := 0.0) -> void:
	var n := dir_local(lat, lon)
	var north := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
	var east := north.cross(n)
	node.transform = Transform3D(Basis(east, n, -north), local_point(lat, lon, height))
	spin.add_child(node)

func _process(delta: float) -> void:
	_clouds.rotate_y(delta * 0.004)

func _shell(r: float, shader: Shader) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 96
	s.rings = 48
	mi.mesh = s
	var m := ShaderMaterial.new()
	m.shader = shader
	if shader.code.contains("noise_tex"):
		var nt := NoiseTexture2D.new()
		nt.width = 1024
		nt.height = 512
		nt.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.012
		fn.fractal_octaves = 5
		nt.noise = fn
		m.set_shader_parameter("noise_tex", nt)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _cloud_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform sampler2D noise_tex;
void fragment() {
	float n = texture(noise_tex, UV * vec2(2.0, 1.0)).r;
	float a = smoothstep(0.56, 0.78, n);
	ALBEDO = vec3(1.0);
	ALPHA = a * 0.85;
	ROUGHNESS = 1.0;
}"""
	return sh

static func _atmo_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float g = pow(rim, 4.0);
	ALBEDO = vec3(0.3, 0.55, 1.0) * g * 1.6;
	ALPHA = g;
}"""
	return sh
