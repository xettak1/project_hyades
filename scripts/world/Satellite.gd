extends Node3D
## The spacecraft on the assembly stand. Rebuilds itself whenever a part is installed.
## Three styles, one per mission:
##   cubesat - 6U CubeSat shown at 3x real size, open aluminium frame
##   smallsat - ~500 kg radar satellite, gold insulation, radar antenna on the side
##   orbiter - lunar orbiter with fuel tank, engine and big dish

var style := "cubesat"
var W := 0.7
var H := 1.1
var D := 0.32
var inner_scale := 0.8
var spin := true
var _frame: Node3D
var _parts_root: Node3D

func _ready() -> void:
	style = MissionState.mission()["env"]["sat_style"]
	match style:
		"smallsat":
			W = 1.4; H = 1.6; D = 1.2; inner_scale = 1.8
		"orbiter":
			W = 1.6; H = 1.8; D = 1.6; inner_scale = 1.9
	_frame = Node3D.new()
	add_child(_frame)
	_build_frame()
	_parts_root = Node3D.new()
	add_child(_parts_root)
	MissionState.design_changed.connect(rebuild)
	rebuild()

func _process(delta: float) -> void:
	if spin:
		rotate_y(delta * 0.25)

func _build_frame() -> void:
	var rail := PartModels.alu()
	var t := 0.035 if style == "cubesat" else 0.06
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_frame.add_child(PartModels.box(Vector3(t, H, t), rail, Vector3(sx * W / 2, 0, sz * D / 2)))
	for sy in [-1, 1]:
		for sz in [-1, 1]:
			_frame.add_child(PartModels.box(Vector3(W, t, t), rail, Vector3(0, sy * H / 2, sz * D / 2)))
		for sx in [-1, 1]:
			_frame.add_child(PartModels.box(Vector3(t, t, D), rail, Vector3(sx * W / 2, sy * H / 2, 0)))
	var plate := PartModels.mat(Color(0.5, 0.5, 0.55), 0.6, 0.5)
	if style != "cubesat":
		# Gold multi-layer insulation on back and sides; the front stays open so you can see inside.
		plate = PartModels.mat(Color(0.85, 0.65, 0.25), 0.9, 0.35)
		_frame.add_child(PartModels.box(Vector3(W, H, 0.02), plate, Vector3(0, 0, -D / 2)))
		for sx in [-1, 1]:
			_frame.add_child(PartModels.box(Vector3(0.02, H, D), plate, Vector3(sx * W / 2, 0, 0)))
	_frame.add_child(PartModels.box(Vector3(W, 0.02, D), plate, Vector3(0, H / 2, 0)))
	_frame.add_child(PartModels.box(Vector3(W, 0.02, D), plate, Vector3(0, -H / 2, 0)))

func _place(cat: String, pos: Vector3, rot_deg := Vector3.ZERO, s := 1.0) -> Node3D:
	var id: String = MissionState.picks.get(cat, "")
	if id == "":
		return null
	var m := PartModels.for_part(cat, id)
	m.position = pos
	m.rotation_degrees = rot_deg
	m.scale = Vector3.ONE * s
	_parts_root.add_child(m)
	return m

func rebuild() -> void:
	if _parts_root == null:
		return
	for c in _parts_root.get_children():
		c.queue_free()
	match style:
		"cubesat": _build_cubesat()
		"smallsat": _build_smallsat()
		"orbiter": _build_orbiter()

# ---------------------------------------------------------------- CubeSat
func _build_cubesat() -> void:
	_place("battery", Vector3(0, -H / 2 + 0.02, 0), Vector3.ZERO, 0.7)
	_place("computer", Vector3(0, -0.2, 0), Vector3.ZERO, 0.8)
	_place("adcs", Vector3(0, 0.05, 0), Vector3.ZERO, 0.8)
	_place("propulsion", Vector3(0, 0.25, 0), Vector3.ZERO, 0.7)
	_place("payload", Vector3(0, -H / 2, 0), Vector3(180, 0, 0), 0.8)
	_place("comms", Vector3(0, H / 2, 0), Vector3.ZERO, 0.8)
	var cells := PartModels.cell_blue()
	_parts_root.add_child(PartModels.box(Vector3(W - 0.04, H - 0.06, 0.012), cells, Vector3(0, 0, -D / 2 - 0.01)))
	for sx in [-1, 1]:
		_parts_root.add_child(PartModels.box(Vector3(0.012, H - 0.06, D - 0.04), cells, Vector3(sx * (W / 2 + 0.01), 0, 0)))
	if MissionState.picks.get("solar") == "solar_deploy":
		for sx in [-1, 1]:
			_wing(sx, Vector3(sx * (W / 2 + 0.05), 0.1, 0), 3, Vector2(0.45, 0.75))

func _wing(sx: int, at: Vector3, panels: int, size: Vector2) -> void:
	var wing := Node3D.new()
	wing.position = at
	var frame := PartModels.alu()
	wing.add_child(PartModels.cyl(0.02, 0.02, 0.15, frame, Vector3(sx * 0.07, 0, 0), Vector3(0, 0, 90)))
	for k in panels:
		var cx: float = sx * (0.15 + size.x / 2 + k * (size.x + 0.03))
		wing.add_child(PartModels.box(Vector3(size.x, size.y, 0.02), frame, Vector3(cx, 0, 0)))
		wing.add_child(PartModels.box(Vector3(size.x - 0.04, size.y - 0.04, 0.026), PartModels.cell_blue(), Vector3(cx, 0, 0)))
	_parts_root.add_child(wing)

# ---------------------------------------------------------------- Radar satellite
func _build_smallsat() -> void:
	var s := inner_scale
	_place("battery", Vector3(0, -H / 2 + 0.05, 0), Vector3.ZERO, s)
	_place("computer", Vector3(0, -0.2, 0), Vector3.ZERO, s)
	_place("adcs", Vector3(0, 0.15, 0), Vector3.ZERO, s)
	_place("propulsion", Vector3(0, 0.45, 0), Vector3.ZERO, s)
	_place("comms", Vector3(0, -H / 2, 0), Vector3(180, 0, 0), 2.0)   # antenna looks down at Earth
	# Radar antenna: a long tiled panel on the +x side, looking sideways at the ground
	var big: bool = MissionState.picks.get("payload") == "sar_large"
	var length := 4.6 if big else 3.0
	var radar := Node3D.new()
	radar.position = Vector3(W / 2 + 0.12, -0.1, 0)
	radar.add_child(PartModels.box(Vector3(0.08, 0.9, length), PartModels.alu()))
	var tiles := 10 if big else 6
	for i in tiles:
		radar.add_child(PartModels.box(Vector3(0.02, 0.8, length / tiles * 0.9), PartModels.mat(Color(0.78, 0.78, 0.74), 0.3, 0.6), Vector3(0.05, 0, -length / 2 + length / tiles * (i + 0.5))))
	_parts_root.add_child(radar)
	# Solar: fixed panels on top, or a big wing on the -x side
	if MissionState.picks.get("solar") == "rsolar_wing":
		_wing(-1, Vector3(-W / 2 - 0.05, 0.3, 0), 3, Vector2(1.1, 1.0))
	else:
		_parts_root.add_child(PartModels.box(Vector3(W - 0.1, 0.03, D - 0.1), PartModels.cell_blue(), Vector3(0, H / 2 + 0.03, 0)))
		_parts_root.add_child(PartModels.box(Vector3(0.03, H - 0.2, D - 0.1), PartModels.cell_blue(), Vector3(-W / 2 - 0.03, 0, 0)))

# ---------------------------------------------------------------- Lunar orbiter
func _build_orbiter() -> void:
	var s := inner_scale
	_place("propulsion", Vector3(0, -0.45, 0), Vector3.ZERO, 2.4)     # fuel tank in the middle
	_place("battery", Vector3(-0.45, 0.45, 0.2), Vector3.ZERO, s * 0.7)
	_place("computer", Vector3(0.4, 0.45, 0.2), Vector3.ZERO, s * 0.7)
	_place("adcs", Vector3(0, 0.25, -0.3), Vector3.ZERO, s * 0.8)
	# Main engine under the spacecraft
	_parts_root.add_child(PartModels.cyl(0.12, 0.3, 0.45, PartModels.dark(), Vector3(0, -H / 2 - 0.22, 0)))
	# Cameras look down at the Moon from a bracket
	_place("payload", Vector3(0, -H / 2, D / 2 + 0.25), Vector3(180, 0, 0), 1.6)
	# Antenna on a boom on top
	var dish: bool = MissionState.picks.get("comms") == "lradio_ka"
	_parts_root.add_child(PartModels.cyl(0.04, 0.04, 0.9 if dish else 0.3, PartModels.alu(), Vector3(0, H / 2 + (0.45 if dish else 0.15), 0)))
	_place("comms", Vector3(0, H / 2 + (0.85 if dish else 0.3), 0), Vector3(-25, 0, 0), 2.6 if dish else 2.0)
	# Solar wings
	_wing(1, Vector3(W / 2 + 0.05, 0.3, 0), 3, Vector2(1.0, 1.2))
	if MissionState.picks.get("solar") == "lsolar_2":
		_wing(-1, Vector3(-W / 2 - 0.05, 0.3, 0), 3, Vector2(1.0, 1.2))
