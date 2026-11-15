extends Control
## World (or Moon) ground-track map, drawn live: grid, continents, day/night,
## ground-station coverage, past / current / next orbit track, spacecraft marker.
## Matches the "World Ground Track & Trajectory" card of the Stitch design.

var body := "earth"
var inc_deg := 97.6
var period_s := 5736.0
var t := 0.0                  # seconds since epoch (drives everything)
var stations: Array = []      # [{name, lat, lon, status}]
var footprint_deg := 20.0
var accent := FUI.SKY
var sc_label := "CubeSat 6U"
var sc_mode := "Nadir Pointing"

# Continents from the Stitch SVG (1000 x 500 plate carree)
const CONTINENTS := [
	[115, 75, 185, 68, 265, 95, 295, 125, 285, 165, 250, 185, 240, 225, 205, 245, 175, 235, 150, 195, 125, 155, 100, 115],
	[265, 260, 335, 285, 365, 335, 325, 425, 285, 445, 265, 375, 250, 295],
	[465, 75, 585, 65, 755, 75, 885, 115, 865, 175, 805, 195, 725, 225, 665, 205, 605, 165, 535, 185, 475, 145, 455, 105],
	[460, 195, 555, 185, 595, 245, 575, 325, 545, 385, 495, 395, 465, 325, 435, 255],
	[755, 315, 855, 305, 885, 355, 845, 405, 775, 395, 745, 345],
	[325, 45, 415, 45, 395, 95, 335, 90],
]
var _craters: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_craters.append([rng.randf(), rng.randf_range(0.08, 0.92), rng.randf_range(3.0, 22.0)])

func body_rate_deg_s() -> float:
	return 360.0 / (27.32 * 86400.0) if body == "moon" else 360.0 / 86164.0

## Sub-satellite point (lat, lon in degrees) at time tt.
func subpoint(tt: float) -> Vector2:
	var th := TAU * tt / period_s
	var i := deg_to_rad(inc_deg)
	var lat := rad_to_deg(asin(sin(i) * sin(th)))
	var lon := rad_to_deg(atan2(cos(i) * sin(th), cos(th))) + 30.0 - body_rate_deg_s() * tt
	lon = fposmod(lon + 180.0, 360.0) - 180.0
	return Vector2(lat, lon)

func to_map(lat: float, lon: float) -> Vector2:
	return Vector2((lon + 180.0) / 360.0 * size.x, (90.0 - lat) / 180.0 * size.y)

func subsolar_lon(tt: float) -> float:
	var day_len := 29.53 * 86400.0 if body == "moon" else 86400.0
	return 180.0 - fposmod(tt, day_len) / day_len * 360.0

func _process(_d: float) -> void:
	queue_redraw()

func _font(n: String) -> Font:
	return FUI.font(n)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var sx := w / 1000.0
	var sy := h / 500.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080f1e") if body == "earth" else Color("#252a33"))
	# Grid
	var g := 40.0 * sx
	var x := 0.0
	while x <= w:
		draw_line(Vector2(x, 0), Vector2(x, h), Color("#131e33"), 1.0)
		x += g
	var y := 0.0
	while y <= h:
		draw_line(Vector2(0, y), Vector2(w, y), Color("#131e33"), 1.0)
		y += g
	# Land (Earth) or craters (Moon)
	if body == "earth":
		for poly in CONTINENTS:
			var pts := PackedVector2Array()
			for k in range(0, poly.size(), 2):
				pts.append(Vector2(poly[k] * sx, poly[k + 1] * sy))
			draw_colored_polygon(pts, Color("#142137"))
			pts.append(pts[0])
			draw_polyline(pts, Color("#1e2f4a"), 1.0, true)
	else:
		for c in _craters:
			var p := Vector2(c[0] * w, c[1] * h)
			draw_circle(p, c[2] * sx, Color("#1f232b"))
			draw_arc(p, c[2] * sx, 0, TAU, 24, Color("#3a404c"), 1.0, true)
	# Equator and prime meridian
	draw_line(Vector2(0, h / 2), Vector2(w, h / 2), Color("#1e293b"), 1.0)
	draw_dashed_line(Vector2(w / 2, 0), Vector2(w / 2, h), Color("#1e293b"), 1.0, 3.0)
	draw_string(_font("JetBrainsMono-Regular"), Vector2(w / 2 + 6, h / 2 - 6), "EQUATOR 0°", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FUI.FAINT)
	draw_string(_font("JetBrainsMono-Regular"), Vector2(w / 2 + 6, 16), "MERIDIAN 0°", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FUI.FAINT)
	# Night side
	var sun_lon := subsolar_lon(t)
	var col_w := 6.0
	var cx := 0.0
	while cx < w:
		var lon := (cx + col_w / 2) / w * 360.0 - 180.0
		var dist := absf(fposmod(lon - sun_lon + 180.0, 360.0) - 180.0)
		var night := clampf((dist - 78.0) / 24.0, 0.0, 1.0)
		if night > 0.0:
			draw_rect(Rect2(cx, 0, col_w + 0.5, h), Color(0.008, 0.027, 0.075, 0.72 * night))
		cx += col_w
	# Ground stations
	for st in stations:
		var p := to_map(st["lat"], st["lon"])
		var r := footprint_deg / 360.0 * w
		for k in 6:
			draw_circle(p, r * (1.0 - k * 0.15), Color(FUI.SKY, 0.025 + k * 0.012))
		draw_arc(p, r, 0, TAU, 48, Color(FUI.SKY, 0.5), 1.0, true)
		draw_circle(p, 3.5, FUI.SKY)
		var active: bool = st.get("active", false)
		draw_string(_font("brogame"), p + Vector2(9, -4), st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FUI.TEXT2 if active else FUI.MUTED)
		draw_string(_font("JetBrainsMono-Regular"), p + Vector2(9, 10), st.get("status", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FUI.GREEN if active else FUI.DIM)
	# Tracks: previous rev (muted dashed), current (solid accent), next (faint dashed)
	_track(t - period_s * 1.5, t - period_s * 0.5, Color("#334155"), 1.2, true)
	_track(t - period_s * 0.5, t, accent, 2.2, false)
	_track(t, t + period_s * 0.6, Color(accent, 0.45), 1.2, true)
	# Sub-solar point
	var sp := to_map(0.0, sun_lon)
	draw_circle(sp, 4.0, FUI.AMBER)
	draw_arc(sp, 8.0, 0, TAU, 24, Color(FUI.AMBER, 0.6), 1.0, true)
	var sl := "Subsolar point (1,361 W/m²)"
	var off := Vector2(12, 4) if sp.x < w - 200 else Vector2(-190, -10)
	draw_string(_font("JetBrainsMono-Regular"), sp + off, sl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#fde68a"))
	# Spacecraft
	var now := subpoint(t)
	var nxt := subpoint(t + period_s * 0.01)
	var p0 := to_map(now.x, now.y)
	var dir := (to_map(nxt.x, nxt.y) - p0)
	if dir.length() > 0.01 and dir.length() < w / 2:
		draw_line(p0, p0 + dir.normalized() * 22.0, FUI.GREEN, 2.0, true)
	draw_arc(p0, 15.0, 0, TAU, 32, Color(accent, 0.45), 1.0, true)
	draw_circle(p0, 5.0, accent)
	draw_circle(p0, 1.8, Color("#040812"))
	var badge := Rect2(p0 + Vector2(16, -38), Vector2(132, 34))
	if badge.end.x > w:
		badge.position.x = p0.x - 148
	if badge.position.y < 0:
		badge.position.y = p0.y + 8
	draw_rect(badge, Color("#0f172a"))
	draw_rect(badge, Color("#334155"), false, 1.0)
	draw_string(_font("brogame"), badge.position + Vector2(8, 14), sc_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FUI.WHITE)
	draw_string(_font("JetBrainsMono-Regular"), badge.position + Vector2(8, 28), sc_mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FUI.GREEN)

func _track(t0: float, t1: float, color: Color, width: float, dashed: bool) -> void:
	var steps := 160
	var seg := PackedVector2Array()
	var prev := Vector2.INF
	for k in steps + 1:
		var sp := subpoint(lerpf(t0, t1, float(k) / steps))
		var p := to_map(sp.x, sp.y)
		if prev != Vector2.INF and absf(p.x - prev.x) > size.x * 0.5:
			_flush(seg, color, width, dashed)
			seg = PackedVector2Array()
		seg.append(p)
		prev = p
	_flush(seg, color, width, dashed)

func _flush(seg: PackedVector2Array, color: Color, width: float, dashed: bool) -> void:
	if seg.size() < 2:
		return
	if not dashed:
		draw_polyline(seg, color, width, true)
		return
	for k in seg.size() - 1:
		if k % 2 == 0:
			draw_line(seg[k], seg[k + 1], color, width, true)
