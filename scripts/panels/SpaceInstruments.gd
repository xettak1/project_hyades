class_name SpaceInstruments
extends RefCounted
## LEVEL 2 · SPACECRAFT OPERATIONS: flight displays inside the satellite, all fed by the live
## model in SpaceSegment (battery / solar / load around the orbit, storage, scans) and the parts
## chosen in Level 1.
##   Power      - battery charge dial, solar generation, power consumption, net power, sun/eclipse
##   Data       - onboard storage dial, stored / free, collection progress, active instruments
##   Orbit      - map of the ground track over Africa with the satellite and the four regions
##   CameraOverlay - telemetry drawn over the live Earth imagery (region, lat/lon, resolution, clouds)

static func live(key: String, default = 0.0):
	return MissionState.live.get(key, default)

# ---------------------------------------------------------------------------- power
class Power extends AV.Display:
	var batt: AV.Gauge
	var gen: AV.Meter
	var cons: AV.Meter
	var net: AV.Readout
	var wh: AV.Readout
	var sun: AV.Lamp
	var chg: AV.Lamp
	var bus: AV.Lamp
	func build() -> void:
		code = "EPS-01"
		title = "ELECTRICAL POWER"
		accent = AV.WARN
		footer = "SOLAR ARRAY · BATTERY · 28 V BUS"
		var row := AV.hbox(16)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		batt = AV.Gauge.new("BATTERY CHARGE", "%", 0.0, 100.0, "%.0f", Vector2(200, 190))
		batt.bands = [[0.0, 0.2, AV.BAD], [0.2, 0.4, AV.WARN], [0.4, 1.0, AV.OK]]
		row.add_child(batt)
		var col := AV.vbox(10)
		AV.expand(col)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		gen = AV.Meter.new("SOLAR GENERATION")
		cons = AV.Meter.new("POWER CONSUMPTION")
		col.add_child(gen)
		col.add_child(cons)
		var rr := AV.hbox(12)
		net = AV.Readout.new("NET POWER", "W", 28, 120)
		wh = AV.Readout.new("STORED ENERGY", "Wh", 28, 120)
		rr.add_child(net)
		rr.add_child(wh)
		col.add_child(rr)
		var lamps := AV.hbox(10)
		body.add_child(lamps)
		sun = AV.Lamp.new("SUNLIGHT", Vector2(120, 46))
		chg = AV.Lamp.new("CHARGING", Vector2(120, 46))
		bus = AV.Lamp.new("BUS NOMINAL", Vector2(120, 46))
		for l in [sun, chg, bus]:
			l.size_flags_vertical = Control.SIZE_FILL
			lamps.add_child(l)
	func refresh() -> void:
		var x: Dictionary = MissionState.compute()["extra"]
		var frac: float = SpaceInstruments.live("battery_frac", 1.0)
		var g: float = SpaceInstruments.live("gen_now", x["gen_avg"])
		var l: float = SpaceInstruments.live("load_now", x["load_w"])
		var ecl: bool = SpaceInstruments.live("eclipse", false)
		var peak := maxf(float(x["gen_avg"]) * 1.6, l * 1.2)
		var lvl := 0 if frac >= 0.4 else (1 if frac >= 0.2 else 2)
		batt.set_value(100.0 * frac, lvl)
		gen.set_value(g / peak, "%.1f W" % g, -1 if g > 0.0 else 1)
		var ll := 0 if l <= float(x["gen_avg"]) else 1
		cons.set_value(l / peak, "%.1f W" % l, ll)
		var n := g - l
		net.set_value("%+.1f" % n, AV.OK if n >= 0.0 else AV.WARN)
		wh.set_value("%.1f / %.0f" % [SpaceInstruments.live("battery_wh", 0.0), SpaceInstruments.live("battery_cap_wh", 0.0)])
		sun.set_state(1 if ecl else 0, "IN ECLIPSE" if ecl else "IN SUNLIGHT")
		chg.set_state(0 if n >= 0.0 else 1, "CHARGING" if n >= 0.0 else "DISCHARGING")
		bus.set_state(lvl, ["BUS NOMINAL", "BATTERY LOW", "BATTERY CRITICAL"][lvl])
		status = lvl
		status_text = ["POWER OK", "LOW BATTERY", "CRITICAL"][lvl]

# ---------------------------------------------------------------------------- data & instruments
class Data extends AV.Display:
	var store: AV.Gauge
	var used: AV.Readout
	var free: AV.Readout
	var prog: AV.Meter
	var imager: AV.Readout
	var lamps: Dictionary = {}
	func build() -> void:
		code = "CDH-01"
		title = "DATA & INSTRUMENTS"
		accent = AV.INFO
		footer = "ONBOARD COMPUTER · MASS MEMORY"
		var row := AV.hbox(16)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		store = AV.Gauge.new("STORAGE USED", "%", 0.0, 100.0, "%.0f", Vector2(200, 190))
		store.bands = [[0.0, 0.8, AV.OK], [0.8, 0.95, AV.WARN], [0.95, 1.0, AV.BAD]]
		row.add_child(store)
		var col := AV.vbox(10)
		AV.expand(col)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		imager = AV.Readout.new("IMAGER", "", 22, 200)
		col.add_child(imager)
		var rr := AV.hbox(12)
		used = AV.Readout.new("STORED", "GB", 28, 110)
		free = AV.Readout.new("FREE", "GB", 28, 110)
		rr.add_child(used)
		rr.add_child(free)
		col.add_child(rr)
		prog = AV.Meter.new("OBSERVATION PROGRESS")
		col.add_child(prog)
		var g := AV.grid(4, 8, 8)
		AV.expand(g)
		body.add_child(g)
		for k in [["camera", "CAMERA"], ["adcs", "POINTING"], ["obc", "COMPUTER"], ["radio", "RADIO"]]:
			var l := AV.Lamp.new(k[1], Vector2(100, 44))
			l.size_flags_vertical = Control.SIZE_FILL
			lamps[k[0]] = l
			g.add_child(l)
	func refresh() -> void:
		var stored: float = SpaceInstruments.live("stored_gb", 0.0)
		var cap: float = maxf(SpaceInstruments.live("storage_gb", 1.0), 0.001)
		var f := stored / cap
		var lvl := 0 if f < 0.8 else (1 if f < 0.95 else 2)
		store.set_value(100.0 * f, lvl)
		used.set_value("%.1f" % stored, AV.level_color(lvl))
		free.set_value("%.1f" % maxf(cap - stored, 0.0))
		var target: float = maxf(SpaceInstruments.live("target_gb", 1.0), 0.001)
		var col: float = SpaceInstruments.live("collected_gb", 0.0)
		prog.set_value(col / target, "%.1f / %.1f GB" % [col, target], -1)
		var cam: Dictionary = MissionState.part_of("payload")
		imager.set_value(str(cam.get("name", "-")).split(" (")[0], AV.INFO)
		var active: bool = SpaceInstruments.live("instrument_state", "STANDBY") == "ACTIVE"
		lamps["camera"].set_state(0 if active else -1, "CAMERA " + ("ACTIVE" if active else "STANDBY"))
		var adcs_adv := str(MissionState.part_of("adcs").get("tier", "")) == "advanced"
		lamps["adcs"].set_state(0 if adcs_adv else 1, "POINTING " + ("FINE" if adcs_adv else "COARSE"))
		lamps["obc"].set_state(0, "COMPUTER ON")
		lamps["radio"].set_state(-2, "RADIO IDLE")
		status = lvl
		status_text = ["RECORDING" if active else "READY", "MEMORY HIGH", "MEMORY FULL"][lvl]

# ---------------------------------------------------------------------------- orbital position
class Orbit extends AV.Display:
	var map: MapView
	var lat: AV.Readout
	var lon: AV.Readout
	var alt: AV.Readout
	var passes: AV.Readout
	func build() -> void:
		code = "GNC-01"
		title = "ORBITAL POSITION"
		accent = AV.OK
		footer = "GROUND TRACK · AFRICA SECTOR"
		map = MapView.new()
		AV.expand(map, true, true)
		body.add_child(map)
		var rr := AV.hbox(12)
		lat = AV.Readout.new("LATITUDE", "°", 24, 100)
		lon = AV.Readout.new("LONGITUDE", "°", 24, 100)
		alt = AV.Readout.new("ALTITUDE", "km", 24, 100)
		passes = AV.Readout.new("PASSES LEFT", "", 24, 100)
		for r in [lat, lon, alt, passes]:
			rr.add_child(r)
		body.add_child(rr)
	func refresh() -> void:
		var la: float = SpaceInstruments.live("sub_lat", 0.0)
		var lo: float = SpaceInstruments.live("sub_lon", 0.0)
		map.push(la, lo)
		lat.set_value("%+.1f" % la)
		lon.set_value("%+.1f" % lo)
		alt.set_value("%d" % int(MissionState.orbit()["altitude_km"]))
		var room = get_tree().current_scene
		var left := int(room.get("passes_left")) if room and "passes_left" in room else 0
		passes.set_value(str(left), AV.WARN if left <= 1 else AV.WHITE)
		var over_africa := la > -38.0 and la < 38.0 and lo > -20.0 and lo < 52.0
		status = 0 if over_africa else -1
		status_text = "OVER AFRICA" if over_africa else "IN TRANSIT"

## Africa-centred map: continents (from the mission map data), the four farm regions,
## the ground track history and the satellite with its camera footprint.
class MapView extends Control:
	const LON0 := -30.0
	const LON1 := 60.0
	const LAT0 := -40.0
	const LAT1 := 40.0
	var trail: Array = []
	func _init() -> void:
		custom_minimum_size = Vector2(300, 160)
		clip_contents = true
	func push(la: float, lo: float) -> void:
		if trail.is_empty() or Vector2(la, lo).distance_to(trail[trail.size() - 1]) > 0.3:
			trail.append(Vector2(la, lo))
			while trail.size() > 160:
				trail.pop_front()
		queue_redraw()
	func _p(la: float, lo: float) -> Vector2:
		return Vector2((lo - LON0) / (LON1 - LON0) * size.x, (LAT1 - la) / (LAT1 - LAT0) * size.y)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#04101c"))
		# continents: GroundTrackMap data is in a 1000 x 500 equirectangular frame
		for poly in preload("res://scripts/panels/GroundTrackMap.gd").CONTINENTS:
			var pts := PackedVector2Array()
			for k in range(0, poly.size(), 2):
				var lo: float = poly[k] / 1000.0 * 360.0 - 180.0
				var la: float = 90.0 - poly[k + 1] / 500.0 * 180.0
				pts.append(_p(la, lo))
			draw_colored_polygon(pts, Color("#173022"))
			pts.append(pts[0])
			draw_polyline(pts, Color("#2f5a3d"), 1.2, true)
		for lo in range(-30, 61, 15):
			draw_line(_p(LAT0, lo), _p(LAT1, lo), Color(1, 1, 1, 0.06), 1.0)
			AV.text(self, _p(LAT0, lo) + Vector2(3, -4), "%d°" % lo, 10, AV.DIMTXT)
		for la in range(-30, 41, 15):
			draw_line(_p(la, LON0), _p(la, LON1), Color(1, 1, 1, 0.06), 1.0)
		draw_line(_p(0, LON0), _p(0, LON1), Color(AV.INFO, 0.2), 1.0)
		for r in FarmRegions.REGIONS:
			var c := _p(r["lat"], r["lon"])
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), Color(AV.WARN, 0.25))
			draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), AV.WARN, false, 1.5)
		if trail.size() > 1:
			var pts := PackedVector2Array()
			for t in trail:
				pts.append(_p(t.x, t.y))
			draw_polyline(pts, Color(AV.INFO, 0.7), 2.0, true)
		if not trail.is_empty():
			var s := _p(trail[trail.size() - 1].x, trail[trail.size() - 1].y)
			# what the camera can reach from here (the game's in-view rule: 42° around the satellite)
			var reach := 42.0
			var pts2 := PackedVector2Array()
			for i in 49:
				var a := TAU * i / 48.0
				pts2.append(_p(trail[trail.size() - 1].x + reach * sin(a), trail[trail.size() - 1].y + reach * cos(a)))
			draw_colored_polygon(pts2, Color(AV.OK, 0.08))
			draw_polyline(pts2, Color(AV.OK, 0.5), 1.0, true)
			draw_circle(s, 5, AV.OK)
		draw_rect(Rect2(Vector2.ZERO, size), AV.FRAME, false, 1.0)

# ---------------------------------------------------------------------------- camera overlay
## Telemetry corners over the live Earth imagery from the satellite camera.
class CameraOverlay extends Control:
	var frame := 0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _process(_d: float) -> void:
		frame += 1
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := Color(0.75, 0.95, 1.0, 0.9)
		# corner brackets
		for p in [[Vector2(20, 60), 1, 1], [Vector2(w - 20, 60), -1, 1], [Vector2(20, h - 20), 1, -1], [Vector2(w - 20, h - 20), -1, -1]]:
			draw_line(p[0], p[0] + Vector2(40 * p[1], 0), c, 2.0)
			draw_line(p[0], p[0] + Vector2(0, 40 * p[2]), c, 2.0)
		var cam: Dictionary = MissionState.part_of("payload")
		var res := float(cam.get("resolution", 10.0))
		var la: float = SpaceInstruments.live("sub_lat", 0.0)
		var lo: float = SpaceInstruments.live("sub_lon", 0.0)
		var region: String = SpaceInstruments.live("region_name", "—")
		var active: bool = SpaceInstruments.live("instrument_state", "STANDBY") == "ACTIVE"
		var lines := ["TARGET  %s" % region, "SUBSAT  %+.2f°  %+.2f°" % [la, lo], "GSD     %.0f m / px" % res]
		for i in lines.size():
			AV.text(self, Vector2(w - 330, h - 86 + i * 22), lines[i], 16, c, "mono")
		AV.text(self, Vector2(30, h - 42), "FRM %06d" % frame, 16, c, "mono")
		AV.text(self, Vector2(30, h - 64), "● REC" if active else "○ STBY", 18, AV.BAD if active else c, "mono_semi")
		# scale bar (10 km)
		var bar := 120.0
		draw_line(Vector2(w / 2 - bar / 2, h - 40), Vector2(w / 2 + bar / 2, h - 40), c, 2.0)
		AV.text(self, Vector2(w / 2 - 60, h - 48), "10 km", 14, c, "mono", HORIZONTAL_ALIGNMENT_CENTER, 120)
