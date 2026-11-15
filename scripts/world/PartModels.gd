class_name PartModels
extends RefCounted
## Builds simple 3D models for every part out of Godot primitives.
## Swap any of these for a real .glb model later: just return the imported scene instead.

static func mat(color: Color, metallic: float = 0.0, rough: float = 0.6, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func box(size: Vector3, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	return mi

static func cyl(r_top: float, r_bot: float, h: float, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi

static func ball(r: float, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	return mi

# Common materials
static func alu() -> Material: return mat(Color(0.75, 0.76, 0.8), 0.8, 0.35)
static func dark() -> Material: return mat(Color(0.08, 0.08, 0.1), 0.2, 0.5)
static func gold() -> Material: return mat(Color(0.95, 0.75, 0.3), 1.0, 0.3)
static func copper() -> Material: return mat(Color(0.8, 0.45, 0.25), 0.9, 0.35)
static func pcb() -> Material: return mat(Color(0.05, 0.4, 0.15), 0.0, 0.7)
static func cell_blue() -> Material: return mat(Color(0.08, 0.15, 0.45), 0.5, 0.25)

## Model for a part of the current mission (uses the part's "model" key if it has one).
static func for_part(category: String, part_id: String) -> Node3D:
	var p := GameData.part(category, part_id)
	return build(category, p.get("model", part_id))

static func tiles(n: Node3D, size: Vector2, cols: int, rows: int, y: float, m: Material) -> void:
	var cw := size.x / cols
	var ch := size.y / rows
	for i in cols:
		for j in rows:
			n.add_child(box(Vector3(cw * 0.86, 0.012, ch * 0.86), m, Vector3(-size.x / 2 + cw * (i + 0.5), y, -size.y / 2 + ch * (j + 0.5))))

## Size (largest side, metres) a .glb part model is shown at; default 0.5.
const GLB_SIZE := {"solar_body": 0.55, "solar_deploy": 0.55, "sar_small": 0.6, "sar_large": 0.9,
	"dish_big": 0.6, "telescope": 0.6, "tank_s": 0.4, "tank_l": 0.55, "bat_10": 0.25, "bat_30": 0.45,
	"obc_std": 0.3, "obc_big": 0.3, "cam_basic": 0.35, "cam_hd": 0.5, "radio_uhf": 0.5}

## Returns a model of the part, about 0.3-0.6 m across, resting on y = 0.
## If res://assets/models/<id>.glb exists it is used; otherwise a model is built from shapes.
static func build(category: String, id: String) -> Node3D:
	var glb := ModelLib.fit(id, GLB_SIZE.get(id, 0.5))
	if glb:
		return glb
	var n := Node3D.new()
	match id:
		"sar_small", "sar_large":
			var big := id == "sar_large"
			var w := 0.9 if big else 0.6
			n.add_child(box(Vector3(w, 0.04, 0.32), alu(), Vector3(0, 0.05, 0)))
			tiles(n, Vector2(w - 0.04, 0.28), 8 if big else 5, 3, 0.075, mat(Color(0.75, 0.75, 0.72), 0.3, 0.6))
			n.add_child(box(Vector3(0.18, 0.06, 0.18), gold(), Vector3(0, 0.0, 0)))
		"tank_s", "tank_l":
			var r := 0.17 if id == "tank_s" else 0.24
			n.add_child(ball(r, mat(Color(0.8, 0.82, 0.85), 0.9, 0.25), Vector3(0, r + 0.04, 0)))
			n.add_child(cyl(r * 0.6, r * 0.7, 0.05, alu(), Vector3(0, 0.025, 0)))
			n.add_child(cyl(0.01, 0.01, 0.2, copper(), Vector3(r * 0.8, r + 0.04, 0), Vector3(0, 0, 30)))
		"dish_big":
			n.add_child(box(Vector3(0.18, 0.08, 0.18), alu(), Vector3(0, 0.04, 0)))
			n.add_child(cyl(0.025, 0.025, 0.18, alu(), Vector3(0, 0.17, 0)))
			n.add_child(cyl(0.32, 0.04, 0.12, mat(Color(0.95, 0.95, 0.97), 0.5, 0.3), Vector3(0, 0.32, 0)))
			n.add_child(cyl(0.012, 0.012, 0.22, alu(), Vector3(0, 0.45, 0)))
			n.add_child(ball(0.03, gold(), Vector3(0, 0.57, 0)))
		"telescope":
			for s in [-1, 1]:
				n.add_child(cyl(0.1, 0.1, 0.55, mat(Color(0.92, 0.92, 0.95), 0.4, 0.4), Vector3(s * 0.12, 0.12, 0), Vector3(90, 0, 0)))
				n.add_child(cyl(0.08, 0.08, 0.02, mat(Color(0.3, 0.8, 1.0), 0.0, 0.05, 0.6), Vector3(s * 0.12, 0.12, 0.28), Vector3(90, 0, 0)))
			n.add_child(box(Vector3(0.45, 0.06, 0.3), gold(), Vector3(0, 0.0, 0)))
		"cam_basic":
			n.add_child(box(Vector3(0.22, 0.12, 0.22), alu(), Vector3(0, 0.06, 0)))
			n.add_child(cyl(0.08, 0.08, 0.18, dark(), Vector3(0, 0.21, 0)))
			n.add_child(cyl(0.06, 0.06, 0.02, mat(Color(0.3, 0.8, 1.0), 0.0, 0.05, 0.6), Vector3(0, 0.31, 0)))
		"cam_hd":
			n.add_child(box(Vector3(0.28, 0.14, 0.28), alu(), Vector3(0, 0.07, 0)))
			n.add_child(cyl(0.12, 0.12, 0.34, dark(), Vector3(0, 0.31, 0)))
			n.add_child(cyl(0.125, 0.125, 0.03, gold(), Vector3(0, 0.2, 0)))
			n.add_child(cyl(0.1, 0.1, 0.02, mat(Color(0.3, 0.8, 1.0), 0.0, 0.05, 0.8), Vector3(0, 0.49, 0)))
		"solar_body":
			var p := Node3D.new()
			p.add_child(box(Vector3(0.5, 0.02, 0.36), alu()))
			for i in 2:
				for j in 2:
					p.add_child(box(Vector3(0.22, 0.012, 0.16), cell_blue(), Vector3(-0.12 + i * 0.24, 0.012, -0.085 + j * 0.17)))
			p.position.y = 0.02
			n.add_child(p)
		"solar_deploy":
			# Folded stack of three panels with a hinge
			for k in 3:
				var layer := Node3D.new()
				layer.add_child(box(Vector3(0.5, 0.02, 0.36), alu()))
				for i in 2:
					layer.add_child(box(Vector3(0.22, 0.012, 0.32), cell_blue(), Vector3(-0.12 + i * 0.24, 0.012, 0)))
				layer.position.y = 0.02 + k * 0.045
				n.add_child(layer)
			n.add_child(cyl(0.015, 0.015, 0.4, alu(), Vector3(0, 0.07, 0.19), Vector3(0, 0, 90)))
		"bat_10":
			n.add_child(box(Vector3(0.2, 0.12, 0.14), mat(Color(0.15, 0.15, 0.17), 0.3, 0.5), Vector3(0, 0.06, 0)))
			n.add_child(box(Vector3(0.202, 0.03, 0.142), mat(Color(1.0, 0.55, 0.1)), Vector3(0, 0.07, 0)))
			n.add_child(cyl(0.015, 0.015, 0.03, mat(Color(0.9, 0.1, 0.1)), Vector3(-0.05, 0.135, 0)))
			n.add_child(cyl(0.015, 0.015, 0.03, dark(), Vector3(0.05, 0.135, 0)))
		"bat_30":
			for i in 3:
				n.add_child(cyl(0.06, 0.06, 0.2, mat(Color(0.15, 0.4, 0.9), 0.4, 0.4), Vector3(-0.13 + i * 0.13, 0.1, 0)))
			n.add_child(box(Vector3(0.42, 0.03, 0.15), mat(Color(1.0, 0.55, 0.1)), Vector3(0, 0.215, 0)))
			n.add_child(cyl(0.015, 0.015, 0.03, mat(Color(0.9, 0.1, 0.1)), Vector3(-0.1, 0.245, 0)))
			n.add_child(cyl(0.015, 0.015, 0.03, dark(), Vector3(0.1, 0.245, 0)))
		"radio_uhf":
			n.add_child(box(Vector3(0.18, 0.06, 0.18), alu(), Vector3(0, 0.03, 0)))
			for a in [Vector3(0, 0, 70), Vector3(0, 0, -70), Vector3(70, 0, 0), Vector3(-70, 0, 0)]:
				var whip := cyl(0.005, 0.005, 0.5, mat(Color(0.85, 0.85, 0.85), 0.9, 0.3), Vector3(0, 0.07, 0), a)
				whip.position += Basis.from_euler(a * PI / 180.0) * Vector3(0, 0.25, 0)
				n.add_child(whip)
		"radio_s":
			n.add_child(box(Vector3(0.2, 0.07, 0.2), alu(), Vector3(0, 0.035, 0)))
			n.add_child(box(Vector3(0.16, 0.012, 0.16), gold(), Vector3(0, 0.08, 0)))
			n.add_child(box(Vector3(0.08, 0.014, 0.08), mat(Color(0.95, 0.9, 0.7), 1.0, 0.2), Vector3(0, 0.088, 0)))
		"radio_x":
			n.add_child(box(Vector3(0.22, 0.08, 0.22), alu(), Vector3(0, 0.04, 0)))
			n.add_child(cyl(0.02, 0.02, 0.12, alu(), Vector3(0, 0.14, 0)))
			n.add_child(cyl(0.2, 0.03, 0.08, mat(Color(0.92, 0.92, 0.95), 0.6, 0.3), Vector3(0, 0.24, 0)))
			n.add_child(cyl(0.01, 0.01, 0.12, alu(), Vector3(0, 0.32, 0)))
			n.add_child(ball(0.02, gold(), Vector3(0, 0.38, 0)))
		"obc_std", "obc_big":
			var boards := 1 if id == "obc_std" else 2
			for b in boards:
				var y := 0.02 + b * 0.08
				n.add_child(box(Vector3(0.3, 0.012, 0.3), pcb(), Vector3(0, y, 0)))
				n.add_child(box(Vector3(0.08, 0.02, 0.08), dark(), Vector3(-0.05, y + 0.016, 0.03)))
				n.add_child(box(Vector3(0.05, 0.016, 0.1), dark(), Vector3(0.08, y + 0.014, -0.05)))
				n.add_child(box(Vector3(0.12, 0.016, 0.04), gold(), Vector3(0, y + 0.014, -0.12)))
				for c in 4:
					n.add_child(cyl(0.006, 0.006, 0.08, alu(), Vector3(-0.14 + (c % 2) * 0.28, 0.04, -0.14 + (c / 2) * 0.28)))
		"adcs_basic":
			for i in 3:
				var rod := cyl(0.02, 0.02, 0.3, copper(), Vector3(0, 0.03 + i * 0.05, 0), Vector3(0, i * 60, 90))
				n.add_child(rod)
		"adcs_precise":
			for i in 3:
				n.add_child(cyl(0.07, 0.07, 0.04, alu(), Vector3(-0.16 + i * 0.16, 0.08, 0), Vector3(90 if i == 1 else 0, 0, 90 if i == 2 else 0)))
				n.add_child(cyl(0.03, 0.03, 0.05, dark(), Vector3(-0.16 + i * 0.16, 0.08, 0), Vector3(90 if i == 1 else 0, 0, 90 if i == 2 else 0)))
			n.add_child(box(Vector3(0.1, 0.1, 0.1), dark(), Vector3(0, 0.2, 0.12)))
			n.add_child(cyl(0.035, 0.045, 0.12, dark(), Vector3(0, 0.3, 0.12)))
		"prop_none":
			n.add_child(box(Vector3(0.3, 0.02, 0.2), mat(Color(0.3, 0.3, 0.33)), Vector3(0, 0.01, 0)))
		"prop_cold":
			# Small iodine cold-gas thruster: a tank block with one nozzle
			n.add_child(box(Vector3(0.16, 0.14, 0.16), alu(), Vector3(0, 0.11, 0)))
			n.add_child(cyl(0.015, 0.035, 0.05, dark(), Vector3(0, 0.02, 0)))
		"prop_ion":
			# Ion thruster: box with a round grid and a gold-wrapped tank
			n.add_child(box(Vector3(0.2, 0.16, 0.2), gold(), Vector3(0, 0.12, 0)))
			n.add_child(cyl(0.07, 0.07, 0.03, mat(Color(0.25, 0.25, 0.28), 0.8, 0.3), Vector3(0, 0.12, 0.11), Vector3(90, 0, 0)))
			n.add_child(cyl(0.05, 0.05, 0.032, mat(Color(0.4, 0.55, 1.0), 0.0, 0.5, 0.8), Vector3(0, 0.12, 0.112), Vector3(90, 0, 0)))
		"thermal_mli":
			# Multi-layer insulation blanket (gold foil) folded on a radiator plate
			n.add_child(box(Vector3(0.34, 0.02, 0.24), mat(Color(0.92, 0.93, 0.95), 0.3, 0.3), Vector3(0, 0.01, 0)))
			n.add_child(box(Vector3(0.3, 0.05, 0.2), gold(), Vector3(0, 0.045, 0)))
			n.add_child(box(Vector3(0.28, 0.04, 0.18), gold(), Vector3(0.01, 0.09, 0.005)))
		"thermal_heater":
			# Flexible heater strips on a battery-sized block
			n.add_child(box(Vector3(0.22, 0.12, 0.16), mat(Color(0.2, 0.2, 0.22), 0.4, 0.5), Vector3(0, 0.06, 0)))
			for i in 4:
				n.add_child(box(Vector3(0.225, 0.015, 0.03), mat(Color(0.9, 0.4, 0.1), 0.2, 0.5, 0.6), Vector3(0, 0.03 + i * 0.025, 0.07)))
			n.add_child(cyl(0.006, 0.006, 0.12, copper(), Vector3(0.12, 0.12, 0), Vector3(0, 0, 70)))
		"prop_small":
			n.add_child(ball(0.12, alu(), Vector3(0, 0.22, 0)))
			n.add_child(cyl(0.02, 0.02, 0.08, alu(), Vector3(0, 0.07, 0)))
			n.add_child(cyl(0.02, 0.06, 0.08, dark(), Vector3(0, 0.0, 0)))
		_:
			n.add_child(box(Vector3(0.2, 0.2, 0.2), mat(Color.MAGENTA)))
	return n
