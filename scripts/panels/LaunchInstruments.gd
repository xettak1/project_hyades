class_name LaunchInstruments
extends RefCounted
## LEVEL 1 · LAUNCH CONTROL CONSOLE: four separate pieces of equipment, all reading real data
## from MissionState (the Mission Manager):
##   Budget    - total, spent, remaining, utilisation dial
##   Payload   - spacecraft mass, rocket capacity, maximum allowed mass, utilisation dial
##   Rocket    - launch vehicle, engine status, countdown, orbit insertion, readiness (GO / NO-GO)
##   Overview  - mission name, launch site, target orbit, current phase

static func _lv(a: Array, id: String) -> int:
	for r in a:
		if r["id"] == id:
			return r["level"]
	return -1

static func _bands_less_is_better(warn: float, crit: float) -> Array:
	return [[0.0, warn, AV.OK], [warn, crit, AV.WARN], [crit, 1.0, AV.BAD]]

# ---------------------------------------------------------------------------- budget
class Budget extends AV.Display:
	var dial: AV.Gauge
	var total: AV.Readout
	var spent: AV.Readout
	var left: AV.Readout
	var meter: AV.Meter
	func build() -> void:
		code = "LCC-01"
		title = "MISSION BUDGET"
		accent = AV.WARN
		footer = "FINANCE · VALUES IN US$ MILLIONS"
		var row := AV.hbox(18)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		dial = AV.Gauge.new("BUDGET USED", "%", 0.0, 100.0, "%.0f", Vector2(220, 210))
		dial.bands = LaunchInstruments._bands_less_is_better(0.85, 1.0)
		row.add_child(dial)
		var col := AV.vbox(14)
		AV.expand(col)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		total = AV.Readout.new("TOTAL BUDGET", "$M", 30)
		spent = AV.Readout.new("MONEY SPENT", "$M", 30)
		left = AV.Readout.new("REMAINING FUNDS", "$M", 38)
		col.add_child(total)
		col.add_child(spent)
		col.add_child(left)
		meter = AV.Meter.new("BUDGET UTILISATION")
		body.add_child(meter)
	func refresh() -> void:
		var m := MissionState.mission()
		var x: Dictionary = MissionState.compute()["extra"]
		var a := MissionState.assess(x)
		var budget := float(m["budget"])
		var cost := float(x["cost"])
		var lvl := LaunchInstruments._lv(a, "budget_used")
		dial.set_value(100.0 * cost / budget, lvl)
		total.set_value("$%.2f" % budget)
		spent.set_value("$%.2f" % cost, AV.WHITE)
		left.set_value("$%.2f" % (budget - cost), AV.level_color(lvl))
		meter.set_value(cost / budget, "%.0f%%  of  $%.0fM" % [100.0 * cost / budget, budget], lvl)
		meter.limit = 1.0
		status = maxi(lvl, 0)
		status_text = ["WITHIN BUDGET", "NEAR LIMIT", "OVER BUDGET", "OVER BUDGET"][clampi(lvl, 0, 3)]

# ---------------------------------------------------------------------------- payload
class Payload extends AV.Display:
	var dial: AV.Gauge
	var mass: AV.Readout
	var cap: AV.Readout
	var maxm: AV.Readout
	var meter: AV.Meter
	func build() -> void:
		code = "LCC-02"
		title = "PAYLOAD MONITOR"
		accent = AV.INFO
		footer = "MASS PROPERTIES · KILOGRAMS"
		var row := AV.hbox(18)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		dial = AV.Gauge.new("ROCKET CAPACITY USED", "%", 0.0, 100.0, "%.0f", Vector2(220, 210))
		dial.bands = LaunchInstruments._bands_less_is_better(0.85, 1.0)
		row.add_child(dial)
		var col := AV.vbox(14)
		AV.expand(col)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		mass = AV.Readout.new("SPACECRAFT MASS", "kg", 38)
		cap = AV.Readout.new("ROCKET CARRYING CAPACITY", "kg", 30)
		maxm = AV.Readout.new("MAXIMUM ALLOWED MASS", "kg", 30)
		col.add_child(mass)
		col.add_child(cap)
		col.add_child(maxm)
		meter = AV.Meter.new("MASS vs MISSION LIMIT")
		body.add_child(meter)
	func refresh() -> void:
		var m := MissionState.mission()
		var x: Dictionary = MissionState.compute()["extra"]
		var a := MissionState.assess(x)
		var mass_kg := float(x["mass"])
		var rocket_cap := float(x["rocket_cap"])
		var limit := float(m["mass_limit"])
		var lr := LaunchInstruments._lv(a, "rocket_used")
		var lm := LaunchInstruments._lv(a, "mass_used")
		dial.set_value(100.0 * mass_kg / rocket_cap if rocket_cap > 0.0 else 100.0, lr)
		mass.set_value("%.2f" % mass_kg, AV.level_color(maxi(lm, 0)))
		cap.set_value(("%.0f" % rocket_cap) if rocket_cap > 0.0 else "CAN'T REACH ORBIT", AV.WHITE if rocket_cap > 0.0 else AV.BAD)
		maxm.set_value("%.1f" % limit)
		meter.set_value(mass_kg / limit, "%.2f / %.1f kg" % [mass_kg, limit], lm)
		meter.limit = 1.0
		meter.limit_text = "LIMIT"
		status = maxi(maxi(lr, lm), 0)
		status_text = ["MASS OK", "NEAR LIMIT", "TOO HEAVY", "TOO HEAVY"][clampi(status, 0, 3)]

# ---------------------------------------------------------------------------- rocket status
class Rocket extends AV.Display:
	var vehicle: AV.Readout
	var count: AV.Readout
	var lamps: Dictionary = {}
	var go: AV.Lamp
	func build() -> void:
		code = "LCC-03"
		title = "ROCKET STATUS"
		accent = AV.BAD
		footer = "RANGE · VEHICLE · PAD 39"
		var row := AV.hbox(18)
		body.add_child(row)
		vehicle = AV.Readout.new("SELECTED LAUNCH VEHICLE", "", 26, 260)
		row.add_child(vehicle)
		count = AV.Readout.new("COUNTDOWN", "", 38, 200)
		row.add_child(count)
		var g := AV.grid(3, 10, 10)
		AV.expand(g, true, true)
		body.add_child(g)
		for k in [["engines", "ENGINES"], ["fuel", "PROPELLANT"], ["insert", "ORBIT INSERTION"], ["mass", "PAYLOAD MASS"], ["budget", "BUDGET"], ["range", "RANGE SAFETY"]]:
			var l := AV.Lamp.new(k[1], Vector2(150, 50))
			lamps[k[0]] = l
			g.add_child(l)
		go = AV.Lamp.new("LAUNCH READINESS", Vector2(300, 74))
		go.size_flags_vertical = Control.SIZE_FILL
		body.add_child(go)
	func refresh() -> void:
		var x: Dictionary = MissionState.compute()["extra"]
		var a := MissionState.assess(x)
		var g := MissionState.gate()
		vehicle.set_value(MissionState.rocket().get("name", "NOT SELECTED").split(" (")[0], AV.WHITE if MissionState.rocket_id != "" else AV.WARN)
		var lt: float = MissionState.live.get("launch_t", -1.0)
		var ph: String = MissionState.live.get("launch_phase", "")
		if lt < 0.0:
			count.set_value("HOLD", AV.WARN)
		elif lt < 3.0:
			count.set_value("T-%02d" % (3 - int(lt)), AV.WARN)
		else:
			count.set_value("T+%02d" % int(lt - 3.0), AV.OK)
		var flying := lt >= 3.0
		lamps["engines"].set_state(0 if flying else (-1 if lt >= 0.0 else -2), "ENGINES " + ("BURNING" if flying else ("ARMED" if lt >= 0.0 else "SAFE")))
		lamps["fuel"].set_state(0, "PROPELLANT LOADED")
		var cap := float(x["rocket_cap"])
		lamps["insert"].set_state(0 if cap > 0.0 else 3, "INSERTION " + ("GO" if cap > 0.0 else "NO-GO"))
		var lr := maxi(LaunchInstruments._lv(a, "rocket_used"), LaunchInstruments._lv(a, "mass_used"))
		lamps["mass"].set_state(maxi(lr, 0), "MASS " + ["OK", "NEAR LIMIT", "TOO HEAVY", "TOO HEAVY"][clampi(lr, 0, 3)])
		var lb := LaunchInstruments._lv(a, "budget_used")
		lamps["budget"].set_state(maxi(lb, 0), "BUDGET " + ["OK", "TIGHT", "OVER", "OVER"][clampi(lb, 0, 3)])
		lamps["range"].set_state(0, "RANGE GREEN")
		if not g["hard"].is_empty():
			go.set_state(3, "NO-GO · %s" % str(g["hard"][0]).to_upper().left(28))
			status = 3
			status_text = "NO-GO"
		elif not g["warn"].is_empty():
			go.set_state(1, "GO WITH %d WARNING%s" % [g["warn"].size(), "S" if g["warn"].size() > 1 else ""])
			status = 1
			status_text = "GO (CAUTION)"
		else:
			go.set_state(0, "GO FOR LAUNCH")
			status = 0
			status_text = "GO"
		if flying:
			status_text = "LIFTOFF"

# ---------------------------------------------------------------------------- mission overview
class Overview extends AV.Display:
	var mname: AV.Readout
	var site: AV.Readout
	var orbit: AV.Readout
	var phase: AV.Readout
	var stages: Array = []
	var orbit_vals: Dictionary = {}
	func build() -> void:
		code = "LCC-04"
		title = "MISSION OVERVIEW"
		accent = AV.OK
		footer = "FLIGHT DIRECTOR · MISSION 01"
		var g := AV.grid(2, 18, 10)
		AV.expand(g)
		body.add_child(g)
		mname = AV.Readout.new("MISSION", "", 26, 260)
		site = AV.Readout.new("LAUNCH LOCATION", "", 22, 260)
		orbit = AV.Readout.new("TARGET ORBIT", "", 22, 260)
		phase = AV.Readout.new("CURRENT PHASE", "", 26, 260)
		for r in [mname, site, orbit, phase]:
			g.add_child(r)
		var og := AV.Section.new("ORBIT PARAMETERS")
		AV.expand(og)
		body.add_child(og)
		var orow := AV.hbox(12)
		og.content.add_child(orow)
		for k in [["alt", "ALTITUDE", "km"], ["inc", "INCLINATION", "°"], ["per", "PERIOD", "min"], ["rev", "REVISIT", "days"]]:
			var r := AV.Readout.new(k[1], k[2], 24, 90)
			orbit_vals[k[0]] = r
			orow.add_child(r)
		var sec := AV.Section.new("MISSION TIMELINE")
		AV.expand(sec, true, true)
		body.add_child(sec)
		var tl := AV.hbox(8)
		sec.content.add_child(tl)
		for s in ["DESIGN", "LAUNCH", "ORBIT OPS", "DOWNLINK", "ANALYSIS"]:
			var l := AV.Lamp.new(s, Vector2(90, 46))
			stages.append(l)
			tl.add_child(l)
	func refresh() -> void:
		mname.set_value(MissionState.mission()["name"], AV.WHITE)
		site.set_value("Coastal launch site · Pad 39", AV.WHITE)
		var o := MissionState.orbit()
		var kind := "Sun-synchronous" if MissionState.orbit_id.begins_with("sso") else "Low Earth orbit"
		orbit.set_value("%s · %d km" % [kind, int(o["altitude_km"])], AV.INFO)
		var x: Dictionary = MissionState.compute()["extra"]
		orbit_vals["alt"].set_value("%d" % int(o["altitude_km"]))
		orbit_vals["inc"].set_value("%.1f" % float(o.get("inclination", o.get("inclination_deg", 0.0))))
		orbit_vals["per"].set_value("%.1f" % float(o["period_min"]))
		orbit_vals["rev"].set_value("%d" % int(x["revisit"]), AV.WHITE)
		var lt: float = MissionState.live.get("launch_t", -1.0)
		var ph := "DESIGN & CHECKOUT" if lt < 0.0 else ("COUNTDOWN" if lt < 3.0 else "ASCENT")
		phase.set_value(ph, AV.WARN if lt >= 0.0 else AV.OK)
		var idx := 0 if lt < 0.0 else 1
		for i in stages.size():
			stages[i].set_state(0 if i < idx else (-1 if i == idx else -2))
		status = 0 if lt < 0.0 else -1
		status_text = "PRE-LAUNCH" if lt < 0.0 else ("COUNTDOWN" if lt < 3.0 else "IN FLIGHT")
