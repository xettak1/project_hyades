class_name OrbitPath
extends RefCounted
## Orbit points for the 3D view. Uses GMAT data when the Data team provides
## res://data/orbits/<orbit_id>_path.csv (columns: t_sec,x_km,y_km,z_km),
## otherwise draws a perfect circle at the right tilt.

const KM_PER_UNIT := 1000.0          # 1 Godot unit = 1000 km
const EARTH_RADIUS_KM := 6371.0
const MOON_RADIUS_KM := 1737.0

static func body_radius_km(orbit: Dictionary) -> float:
	return MOON_RADIUS_KM if orbit.get("body", "earth") == "moon" else EARTH_RADIUS_KM

## Altitude is exaggerated so a low orbit is visible: 3x around Earth, 6x around the Moon.
static func alt_scale(orbit: Dictionary) -> float:
	return 6.0 if orbit.get("body", "earth") == "moon" else 3.0

static func load_points(orbit_id: String, orbit: Dictionary) -> PackedVector3Array:
	var path := "res://data/orbits/%s_path.csv" % orbit_id
	if FileAccess.file_exists(path):
		var pts := _load_gmat_csv(path, body_radius_km(orbit), alt_scale(orbit))
		if pts.size() > 2:
			return pts
	return circle(body_radius_km(orbit), float(orbit["altitude_km"]), float(orbit["inclination"]), alt_scale(orbit))

static func circle(radius_km: float, altitude_km: float, inclination_deg: float, scale: float = 3.0, n: int = 256) -> PackedVector3Array:
	var r := (radius_km + altitude_km * scale) / KM_PER_UNIT
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(inclination_deg))
	var pts := PackedVector3Array()
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(tilt * Vector3(cos(a) * r, 0.0, sin(a) * r))
	return pts

static func _load_gmat_csv(path: String, radius_km: float, scale: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return pts
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or not (line[0].is_valid_int() or line[0] == "-" or line[0] == "."):
			continue   # skip header and empty rows
		var cols := line.split(",")
		if cols.size() < 4:
			continue
		# GMAT: X, Y in the equator plane, Z to the north pole. Godot: Y is up.
		var v := Vector3(cols[1].to_float(), cols[3].to_float(), -cols[2].to_float())
		var alt := v.length() - radius_km
		pts.append(v.normalized() * (radius_km + alt * scale) / KM_PER_UNIT)
	return pts
