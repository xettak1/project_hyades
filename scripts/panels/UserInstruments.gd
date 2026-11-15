class_name UserInstruments
extends RefCounted
## LEVEL 4 · AGRICULTURAL ANALYSIS: geospatial workstations reading the imagery that actually
## reached Earth (UserSegment.plots: which plots were seen, what is happening on them, which ones
## the analyst has flagged) and the design choices that set image quality.
##   Viewer   - satellite image viewer for the selected region (true colour, grey = no data)
##   Health   - crop-health map (NDVI-style false colour) of all 24 plots
##   Flood    - flood-detection map (water index) with the analyst's flags
##   Results  - image quality, data confidence, counts, product and delivery status

static func room() -> Node:
	var t := Engine.get_main_loop() as SceneTree
	return t.current_scene if t else null

static func plots() -> Array:
	return MissionState.live.get("plots", [])

static func region_index() -> int:
	return int(MissionState.live.get("view_region", 0))

## Image quality from the camera resolution and pointing accuracy chosen in Level 1 (0..1).
static func image_quality() -> float:
	var pointing := float(MissionState.part_of("adcs").get("pointing", 0.7))
	var res := float(MissionState.part_of("payload").get("resolution", 10.0))
	return clampf(pointing * (0.65 + 0.35 * clampf(10.0 / maxf(res, 1.0), 0.0, 1.0) / 1.0), 0.0, 1.0)

## Plot colours as seen in a true-colour satellite image.
const TRUE_COLOR := {"healthy": Color("#3f7d2a"), "stressed": Color("#9a8a3a"), "flooded": Color("#4a5a55"), "waterlogged": Color("#5d6b48")}

# ---------------------------------------------------------------------------- image viewer
class Viewer extends AV.Display:
	var img: ImageView
	var tabs: Array = []
	var info: AV.Readout
	var q: AV.Meter
	func build() -> void:
		code = "GEO-01"
		title = "SATELLITE IMAGE VIEWER"
		accent = AV.INFO
		footer = "TRUE COLOUR · 3 m / px"
		var t := AV.hbox(8)
		body.add_child(t)
		for r in FarmRegions.REGIONS:
			var l := AV.Lamp.new(r["name"].to_upper(), Vector2(120, 38))
			l.size_flags_vertical = Control.SIZE_FILL
			tabs.append(l)
			t.add_child(l)
		img = ImageView.new()
		AV.expand(img, true, true)
		body.add_child(img)
		var rr := AV.hbox(12)
		info = AV.Readout.new("REGION", "", 20, 260)
		q = AV.Meter.new("IMAGE QUALITY", 62)
		rr.add_child(info)
		rr.add_child(q)
		body.add_child(rr)
	func refresh() -> void:
		var ri := UserInstruments.region_index()
		for i in tabs.size():
			tabs[i].set_state(-1 if i == ri else -2)
		var r: Dictionary = FarmRegions.REGIONS[ri]
		img.region = r["id"]
		img.queue_redraw()
		info.set_value("%s · %s" % [r["name"], r["country"]], AV.WHITE)
		var qq := UserInstruments.image_quality()
		q.set_value(qq, "%d%%" % int(100.0 * qq), 0 if qq >= 0.75 else (1 if qq >= 0.5 else 2))
		var seen := 0
		var n := 0
		for p in UserInstruments.plots():
			if p["region"] == r["id"]:
				n += 1
				if p["seen"]:
					seen += 1
		footer = "TRUE COLOUR · %d of %d plots imaged · use the REGION buttons on the desk" % [seen, n]
		status = 0 if seen == n and n > 0 else (1 if seen > 0 else 2)
		status_text = ["FULL COVERAGE", "PARTIAL COVERAGE", "NO IMAGERY"][status]

## True-colour image of one region's six plots, with crop-row texture and grey "no data" tiles.
class ImageView extends Control:
	var region := "volta"
	func _init() -> void:
		custom_minimum_size = Vector2(300, 180)
		clip_contents = true
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(region)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2a22"))
		var ps: Array = UserInstruments.plots().filter(func(p): return p["region"] == region)
		var cols := 3
		var rows := 2
		var gap := 10.0
		var cw := (size.x - gap * (cols + 1)) / cols
		var ch := (size.y - gap * (rows + 1)) / rows
		for i in ps.size():
			var p: Dictionary = ps[i]
			var r := Rect2(gap + (i % cols) * (cw + gap), gap + (i / cols) * (ch + gap), cw, ch)
			if not p["seen"]:
				draw_rect(r, Color(0.32, 0.33, 0.35))
				var k := -r.size.y
				while k < r.size.x:
					draw_line(r.position + Vector2(maxf(k, 0), maxf(-k, 0)), r.position + Vector2(minf(k + r.size.y, r.size.x), minf(r.size.y, r.size.x - k)), Color(1, 1, 1, 0.08), 2.0)
					k += 14
				AV.text(self, r.position + Vector2(0, r.size.y / 2 + 6), "NO DATA", 18, Color(1, 1, 1, 0.6), "mono_semi", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			else:
				var base: Color = UserInstruments.TRUE_COLOR.get(p["state"], Color(0.4, 0.4, 0.3))
				draw_rect(r, base)
				# crop rows and soil texture
				for row in int(r.size.y / 7):
					var y := r.position.y + row * 7 + 2
					draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), base.darkened(0.25 + 0.1 * rng.randf()), 2.0)
				for k in 40:
					draw_rect(Rect2(r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y), Vector2(3, 3)), base.lightened(rng.randf() * 0.2))
				if p["state"] == "flooded":
					var wpts := PackedVector2Array()
					for a in 18:
						var ang := TAU * a / 18.0
						wpts.append(r.get_center() + Vector2(cos(ang) * r.size.x * (0.38 + 0.08 * rng.randf()), sin(ang) * r.size.y * (0.36 + 0.08 * rng.randf())))
					draw_colored_polygon(wpts, Color("#3c5a6e"))
				elif p["state"] == "waterlogged":
					for k in 4:
						draw_circle(r.position + Vector2(rng.randf_range(0.2, 0.8) * r.size.x, rng.randf_range(0.2, 0.8) * r.size.y), r.size.y * 0.12, Color("#4f6b78"))
			draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
			AV.text(self, r.position + Vector2(6, 18), p["id"], 15, AV.WHITE, "mono_semi")
			if p.get("marked", false):
				AV.text(self, r.position + Vector2(r.size.x - 70, 18), "⚑ FLOOD", 14, AV.BAD, "mono_semi")
		# north arrow and scale bar
		AV.text(self, Vector2(size.x - 28, 22), "N", 14, AV.WHITE, "mono_semi")
		draw_line(Vector2(size.x - 22, 28), Vector2(size.x - 22, 46), AV.WHITE, 2.0)
		draw_line(Vector2(12, size.y - 10), Vector2(112, size.y - 10), AV.WHITE, 2.0)
		AV.text(self, Vector2(12, size.y - 14), "1 km", 12, AV.WHITE, "mono")

# ---------------------------------------------------------------------------- shared plot map
## A 6 x 4 map of every plot (rows = regions) with a colour per plot and a legend.
class PlotMap extends Control:
	var mode := "health"            # health | flood
	func _init(m: String = "health") -> void:
		mode = m
		custom_minimum_size = Vector2(300, 170)
	func _cell_color(p: Dictionary) -> Color:
		if not p["seen"]:
			return Color(0.3, 0.31, 0.33)
		if mode == "health":
			return {"healthy": Color("#1a9850"), "stressed": Color("#fee08b"), "flooded": Color("#d73027"), "waterlogged": Color("#fc8d59")}.get(p["state"], Color.GRAY)
		return {"flooded": Color("#2166ac"), "waterlogged": Color("#67a9cf"), "healthy": Color("#3a3f45"), "stressed": Color("#3a3f45")}.get(p["state"], Color.GRAY)
	func _draw() -> void:
		var ps: Array = UserInstruments.plots()
		var cols := FarmRegions.PLOTS_PER_REGION
		var rows := FarmRegions.REGIONS.size()
		var lab_w := 120.0
		var gap := 5.0
		var cw := (size.x - lab_w - gap * cols) / cols
		var ch := (size.y - 26.0 - gap * rows) / rows
		for ri in rows:
			var y := ri * (ch + gap)
			AV.text(self, Vector2(0, y + ch / 2 + 5), FarmRegions.REGIONS[ri]["name"].split(" ")[0].to_upper(), 13, AV.LABEL, "mono_semi")
			for ci in cols:
				var idx := ri * cols + ci
				if idx >= ps.size():
					continue
				var p: Dictionary = ps[idx]
				var r := Rect2(lab_w + ci * (cw + gap), y, cw, ch)
				draw_rect(r, _cell_color(p))
				if not p["seen"]:
					AV.text(self, r.position + Vector2(0, r.size.y / 2 + 5), "?", 15, Color(1, 1, 1, 0.5), "mono_semi", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
				if mode == "flood" and p.get("marked", false):
					draw_rect(r.grow(-2), AV.BAD, false, 3.0)
				AV.text(self, r.position + Vector2(4, 13), p["id"], 11, Color(1, 1, 1, 0.75), "mono")
		# legend
		var items := [["HEALTHY", Color("#1a9850")], ["STRESSED", Color("#fee08b")], ["FLOODED", Color("#d73027")], ["NO DATA", Color(0.3, 0.31, 0.33)]] if mode == "health" else [["FLOOD WATER", Color("#2166ac")], ["WATERLOGGED", Color("#67a9cf")], ["DRY", Color("#3a3f45")], ["FLAGGED", AV.BAD]]
		var lx := lab_w
		for it in items:
			draw_rect(Rect2(lx, size.y - 16, 14, 14), it[1])
			AV.text(self, Vector2(lx + 20, size.y - 4), it[0], 12, AV.LABEL, "mono")
			lx += (size.x - lab_w) / items.size()

class Health extends AV.Display:
	var map: PlotMap
	var h: AV.Readout
	var s: AV.Readout
	var u: AV.Readout
	func build() -> void:
		code = "GEO-02"
		title = "CROP HEALTH (NDVI)"
		accent = AV.OK
		footer = "VEGETATION INDEX · GREEN = HEALTHY"
		map = PlotMap.new("health")
		AV.expand(map, true, true)
		body.add_child(map)
		var rr := AV.hbox(12)
		h = AV.Readout.new("HEALTHY", "plots", 26, 100)
		s = AV.Readout.new("STRESSED", "plots", 26, 100)
		u = AV.Readout.new("NO DATA", "plots", 26, 100)
		for x in [h, s, u]:
			rr.add_child(x)
		body.add_child(rr)
	func refresh() -> void:
		var nh := 0
		var ns := 0
		var nu := 0
		for p in UserInstruments.plots():
			if not p["seen"]:
				nu += 1
			elif p["state"] == "healthy":
				nh += 1
			elif p["state"] == "stressed":
				ns += 1
		h.set_value(str(nh), AV.OK)
		s.set_value(str(ns), AV.WARN)
		u.set_value(str(nu), AV.LABEL if nu == 0 else AV.BAD)
		map.queue_redraw()
		status = 0 if nu == 0 else (1 if nu < 12 else 2)
		status_text = "%d CROP OBSERVATIONS" % (nh + ns)

class Flood extends AV.Display:
	var map: PlotMap
	var det: AV.Readout
	var flag: AV.Readout
	var miss: AV.Readout
	func build() -> void:
		code = "GEO-03"
		title = "FLOOD DETECTION"
		accent = AV.INFO
		footer = "WATER INDEX · RED OUTLINE = FLAGGED BY ANALYST"
		map = PlotMap.new("flood")
		AV.expand(map, true, true)
		body.add_child(map)
		var rr := AV.hbox(12)
		det = AV.Readout.new("WATER DETECTED", "plots", 26, 100)
		flag = AV.Readout.new("FLAGGED", "plots", 26, 100)
		miss = AV.Readout.new("UNKNOWN", "plots", 26, 100)
		for x in [det, flag, miss]:
			rr.add_child(x)
		body.add_child(rr)
	func refresh() -> void:
		var nd := 0
		var nf := 0
		var nu := 0
		for p in UserInstruments.plots():
			if not p["seen"]:
				nu += 1
			elif FarmRegions.is_flood(p["state"]):
				nd += 1
			if p.get("marked", false):
				nf += 1
		det.set_value(str(nd), AV.INFO)
		flag.set_value(str(nf), AV.OK if nf >= nd and nd > 0 else AV.WHITE)
		miss.set_value(str(nu), AV.LABEL if nu == 0 else AV.BAD)
		map.queue_redraw()
		status = 0 if nf >= nd and nd > 0 else 1
		status_text = "%d / %d FLAGGED" % [nf, nd]

# ---------------------------------------------------------------------------- results
class Results extends AV.Display:
	var quality: AV.Gauge
	var conf: AV.Gauge
	var found: AV.Readout
	var crops: AV.Readout
	var missing: AV.Readout
	var product: AV.Lamp
	var deliver: AV.Lamp
	func build() -> void:
		code = "GEO-04"
		title = "ANALYSIS RESULTS"
		accent = AV.WARN
		footer = "QUALITY CONTROL · DISSEMINATION"
		var row := AV.hbox(12)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		quality = AV.Gauge.new("IMAGE QUALITY", "%", 0.0, 100.0, "%.0f", Vector2(180, 170))
		quality.bands = [[0.0, 0.5, AV.BAD], [0.5, 0.75, AV.WARN], [0.75, 1.0, AV.OK]]
		conf = AV.Gauge.new("DATA CONFIDENCE", "%", 0.0, 100.0, "%.0f", Vector2(180, 170))
		conf.bands = [[0.0, 0.5, AV.BAD], [0.5, 0.8, AV.WARN], [0.8, 1.0, AV.OK]]
		row.add_child(quality)
		row.add_child(conf)
		var rr := AV.hbox(12)
		found = AV.Readout.new("FLOODED PLOTS FOUND", "", 26, 120)
		crops = AV.Readout.new("CROP OBSERVATIONS", "", 26, 120)
		missing = AV.Readout.new("MISSING DATA", "plots", 26, 120)
		for x in [found, crops, missing]:
			rr.add_child(x)
		body.add_child(rr)
		var lamps := AV.hbox(8)
		product = AV.Lamp.new("NO PRODUCT", Vector2(160, 44))
		deliver = AV.Lamp.new("NOT DELIVERED", Vector2(160, 44))
		product.size_flags_vertical = Control.SIZE_FILL
		deliver.size_flags_vertical = Control.SIZE_FILL
		lamps.add_child(product)
		lamps.add_child(deliver)
		body.add_child(lamps)
	func refresh() -> void:
		var ps := UserInstruments.plots()
		var seen := 0
		var nc := 0
		var nf := 0
		for p in ps:
			if p["seen"]:
				seen += 1
				if not FarmRegions.is_flood(p["state"]):
					nc += 1
			if p.get("marked", false):
				nf += 1
		var total := maxi(ps.size(), 1)
		var c := float(seen) / total
		var qq := UserInstruments.image_quality()
		quality.set_value(100.0 * qq, 0 if qq >= 0.75 else (1 if qq >= 0.5 else 2))
		conf.set_value(100.0 * c, 0 if c >= 0.8 else (1 if c >= 0.5 else 2))
		var r = UserInstruments.room()
		var delivered: bool = r != null and "delivered" in r and r.delivered
		if delivered:
			found.set_value("%s / %s" % [MissionState.live.get("flood_found", "0"), MissionState.live.get("flood_total", "0")], AV.OK)
		else:
			found.set_value("%d flagged" % nf, AV.WHITE)
		crops.set_value(str(nc))
		missing.set_value(str(ps.size() - seen), AV.LABEL if seen == ps.size() else AV.BAD)
		var prod: String = str(r.product) if r != null and "product" in r else ""
		product.set_state(-1 if prod != "" else -2, ("PRODUCT: " + prod.to_upper()) if prod != "" else "NO PRODUCT CHOSEN")
		deliver.set_state(0 if delivered else -2, "REPORT DELIVERED" if delivered else "NOT DELIVERED")
		status = 0 if c >= 0.8 else (1 if c >= 0.5 else 2)
		status_text = "HIGH CONFIDENCE" if c >= 0.8 else ("MEDIUM CONFIDENCE" if c >= 0.5 else "LOW CONFIDENCE")
