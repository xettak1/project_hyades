extends Node
## Holds the player's current design and works out every resource from it.

signal design_changed
signal state_changed     # live numbers inside a level changed (see set_live)

var mission_id: String = "flood_watch"
var picks: Dictionary = {}          # category -> part id
var orbit_id: String = ""
var rocket_id: String = ""
var lifetime_years: int = 2
var last_result: Dictionary = {}    # filled by the simulation
var best_scores: Dictionary = {}    # mission id -> best score
var runs: int = 0
var tutor_enabled := true         # chosen on the title screen
var tutor_steps: Dictionary = {}   # level id -> guided step reached (see TutorDialogueManager)
var phase: String = "design"        # design | ops
var open_select := false            # title screen opens straight on mission select
var open_brief := false             # title screen opens straight on the briefing (after the intro)
## What each level achieved, keyed by level id (launch / space / ground / user).
## Written by LevelFlow.complete(); read by later levels so decisions carry through.
var level_results: Dictionary = {}
## Live numbers inside the current level (shown on the console strip). Cleared when a level starts.
var live: Dictionary = {}

var best_score: int:
	get:
		return int(best_scores.get(mission_id, 0))

func start_mission(id: String) -> void:
	mission_id = id
	picks.clear()
	for cat in GameData.categories(id):
		var ids: Array = GameData.parts_for(id)[cat].keys()
		picks[cat] = ids[0]        # start with the simple option of each part
	var m := GameData.mission(id)
	orbit_id = m["orbits"][0]
	rocket_id = m["rockets"][0]
	lifetime_years = m["requirements"]["min_lifetime"]
	last_result = {}
	level_results = {}
	live = {}
	phase = "design"
	design_changed.emit()

func pick(category: String, part_id: String) -> void:
	picks[category] = part_id
	design_changed.emit()

func set_orbit(id: String) -> void:
	orbit_id = id
	design_changed.emit()

func set_rocket(id: String) -> void:
	rocket_id = id
	design_changed.emit()

func set_lifetime(years: int) -> void:
	lifetime_years = years
	design_changed.emit()

func categories() -> Array:
	return GameData.categories(mission_id)

func part_of(category: String) -> Dictionary:
	return GameData.part(category, picks.get(category, ""), mission_id)

func mission() -> Dictionary:
	return GameData.mission(mission_id)

func orbit() -> Dictionary:
	return GameData.ORBITS.get(orbit_id, {})

func rocket() -> Dictionary:
	return GameData.ROCKETS.get(rocket_id, {})

func has_fuel_system() -> bool:
	return orbit().has("delta_v_insert")

## Works out every resource. Each row: used, limit, unit, margin (0.2 = 20% spare).
func compute() -> Dictionary:
	var m := mission()
	var o := orbit()
	var r := rocket()

	var dry: float = m["base_mass"]
	var hw_cost: float = m["base_cost"]
	var load_w := 0.0
	for cat in categories():
		var p := part_of(cat)
		dry += float(p.get("mass", 0.0))
		hw_cost += float(p.get("cost", 0.0))
		load_w += float(p.get("power", 0.0))

	# Fuel (Moon missions): rocket equation, m_fuel_used = m0 * (1 - e^(-dv / (Isp * g0)))
	var prop := part_of("propulsion")
	var fuel: float = float(prop.get("fuel", 0.0)) if has_fuel_system() else 0.0
	var wet: float = dry + fuel
	var fuel_insert := 0.0
	var fuel_left := 0.0
	var fuel_years := 99.0
	if has_fuel_system():
		var ve: float = float(prop.get("isp", 220.0)) * GameData.G0
		fuel_insert = wet * (1.0 - exp(-float(o["delta_v_insert"]) / ve))
		fuel_left = fuel - fuel_insert
		var after: float = wet - fuel_insert
		var per_year: float = after * (1.0 - exp(-float(o["delta_v_per_year"]) / ve))
		fuel_years = maxf(0.0, fuel_left) / maxf(per_year, 0.001)

	var transfer_years: float = float(o.get("transfer_days", 0)) / 365.0
	var rocket_cost: float = float(r.get("cost", 0.0)) + maxf(0.0, wet - float(r.get("included_kg", 0.0))) * float(r.get("per_kg", 0.0))
	var cost: float = hw_cost + rocket_cost + float(m["ops_cost_per_year"]) * (lifetime_years + transfer_years)

	# Power: panels only work in sunlight, so average = peak x (1 - eclipse fraction).
	var eclipse_frac: float = float(o["eclipse_min"]) / float(o["period_min"])
	var gen_avg: float = float(part_of("solar").get("power_gen", 0.0)) * (1.0 - eclipse_frac)
	# Battery: must run the load through each eclipse using only the usable part.
	var need_wh: float = load_w * float(o["eclipse_min"]) / 60.0
	var usable_wh: float = float(part_of("battery").get("energy", 0.0)) * GameData.USABLE_BATTERY_FRACTION

	# Data and communications: GB/day = Mbps x contact minutes x 60 / 8000.
	var payload := part_of("payload")
	var data_gen: float = float(payload.get("data", 0.0))
	var downlink: float = float(part_of("comms").get("mbps", 0.0)) * float(o["contact_min_per_day"]) * 60.0 / 8000.0
	# Storage: every part with onboard memory (computer, and imagers with their own buffer).
	var storage := 0.0
	for cat in categories():
		storage += float(part_of(cat).get("storage", 0.0))
	var pointing: float = float(part_of("adcs").get("pointing", 1.0))
	var useful_per_day: float = minf(data_gen, downlink) * pointing

	var revisit: int = maxi(1, int(o["revisit_days"]) - int(part_of("adcs").get("revisit_bonus", 0)) - int(payload.get("revisit_bonus", 0)))
	var life_cap: float = float(o["life_years"]) + float(prop.get("life_bonus", 0))
	if has_fuel_system():
		life_cap = minf(float(o["life_years"]), fuel_years)
	var resolution: float = float(payload.get("resolution", 0.0))

	var rocket_cap: float = float(r.get("capacity", {}).get(orbit_id, 0.0))

	var rows := {
		"mass": _row("Mass at launch", wet, float(m["mass_limit"]), "kg"),
		"power": _row("Power (average)", load_w, gen_avg, "W"),
		"battery": _row("Battery in eclipse", need_wh, usable_wh, "Wh"),
		"budget": _row("Budget", cost, float(m["budget"]), "$M"),
		"data": _row("Data made vs sent", data_gen, downlink, "GB/day"),
		"comms": _row("Useful data reaching Earth", float(m["requirements"]["min_data_delivered"]), useful_per_day, "GB/day"),
		"time": _row("Lifetime vs what it can last", float(lifetime_years), life_cap, "years"),
	}
	if has_fuel_system():
		rows["fuel"] = _row("Fuel to brake into lunar orbit", fuel_insert, fuel, "kg")
	rows["extra"] = {
		"load_w": load_w, "gen_avg": gen_avg, "need_wh": need_wh, "usable_wh": usable_wh,
		"data_gen": data_gen, "downlink": downlink, "storage": storage, "pointing": pointing,
		"useful_per_day": useful_per_day, "revisit": revisit, "life_cap": life_cap,
		"rocket_cap": rocket_cap, "mass": wet, "dry_mass": dry, "cost": cost, "rocket_cost": rocket_cost,
		"fuel": fuel, "fuel_insert": fuel_insert, "fuel_left": fuel_left, "resolution": resolution,
		"transfer_days": int(o.get("transfer_days", 0)),
	}
	return rows

func _row(label: String, used: float, limit: float, unit: String) -> Dictionary:
	var margin := -1.0
	if limit > 0.0:
		margin = (limit - used) / limit
	return {"label": label, "used": used, "limit": limit, "unit": unit, "margin": margin}

## Launch review: hard stops block launch, warnings explain what will go wrong.
func gate() -> Dictionary:
	var c := compute()
	var x: Dictionary = c["extra"]
	var m := mission()
	var req: Dictionary = m["requirements"]
	var hard: Array = []
	var warn: Array = []

	if x["rocket_cap"] <= 0.0:
		hard.append("The %s cannot reach the %s. Pick a rocket that flies there." % [rocket()["name"], orbit()["name"]])
	elif x["mass"] > x["rocket_cap"]:
		hard.append("Spacecraft is %.0f kg at launch but the rocket can carry only %.0f kg there." % [x["mass"], x["rocket_cap"]])
	if x["mass"] > float(m["mass_limit"]):
		hard.append("Spacecraft is %.1f kg, over the %s limit of %.0f kg. Remove or downgrade parts." % [x["mass"], m["spacecraft_class"], m["mass_limit"]])
	if x["cost"] > float(m["budget"]):
		hard.append("Mission costs $%.2fM but the budget is $%.2fM. Downgrade parts, pick a cheaper rocket or shorten the mission." % [x["cost"], m["budget"]])
	if has_fuel_system() and x["fuel_left"] < 0.0:
		hard.append("Not enough fuel to brake into lunar orbit: needs %.0f kg, tank holds %.0f kg. The spacecraft would fly past the Moon. Use a bigger tank, a lighter design or the low-energy transfer." % [x["fuel_insert"], x["fuel"]])

	# Warnings and cautions come from the threshold table (data/tables/thresholds.csv).
	var caution: Array = []
	for row in assess(x):
		if row["level"] == CRITICAL and row["blocks"]:
			continue          # already reported above as a hard block
		if row["level"] >= WARNING:
			warn.append(row["message"])
		elif row["level"] == CAUTION:
			caution.append(row["message"])
	return {"hard": hard, "warn": warn, "caution": caution}



# ============================================================================ CONSEQUENCES
## Pass/fail checks for a design, used to show what a decision fixes or breaks.
## Each entry: [ok, short label].
func checks(x: Dictionary) -> Dictionary:
	var m := mission()
	var req: Dictionary = m["requirements"]
	return {
		"rocket": [x["rocket_cap"] > 0.0 and x["mass"] <= x["rocket_cap"], "Rocket can carry it to this orbit"],
		"mass": [x["mass"] <= float(m["mass_limit"]), "Under the %s kg mass limit" % str(m["mass_limit"])],
		"budget": [x["cost"] <= float(m["budget"]), "Within the $%sM budget" % str(m["budget"])],
		"power": [x["load_w"] <= x["gen_avg"], "Solar panels cover the average power use"],
		"battery": [x["need_wh"] <= x["usable_wh"], "Battery lasts through every eclipse"],
		"downlink": [x["data_gen"] <= x["downlink"], "Radio can send all the data made"],
		"req_data": [x["useful_per_day"] >= float(req["min_data_delivered"]), "REQUIREMENT: %.1f GB/day of useful data" % req["min_data_delivered"]],
		"req_revisit": [int(x["revisit"]) <= int(req["max_revisit_days"]), "REQUIREMENT: revisit every %d days" % req["max_revisit_days"]],
		"req_life": [lifetime_years <= x["life_cap"] and lifetime_years >= int(req["min_lifetime"]), "REQUIREMENT: work for %d years" % req["min_lifetime"]],
	}

## Works out the design as it would be after one change, without changing anything.
## kind: "part" (key = category), "orbit", "rocket" or "lifetime".
func preview(kind: String, key: String, value) -> Dictionary:
	var saved := [picks.duplicate(), orbit_id, rocket_id, lifetime_years]
	match kind:
		"part": picks[key] = value
		"orbit": orbit_id = value
		"rocket": rocket_id = value
		"lifetime": lifetime_years = int(value)
	var x: Dictionary = compute()["extra"]
	var ch := checks(x)
	var lv := assess(x)
	picks = saved[0]
	orbit_id = saved[1]
	rocket_id = saved[2]
	lifetime_years = saved[3]
	return {"x": x, "checks": ch, "assess": lv}

func current() -> Dictionary:
	var x: Dictionary = compute()["extra"]
	return {"x": x, "checks": checks(x), "assess": assess(x)}


# ============================================================================ THRESHOLDS
enum {NOMINAL, CAUTION, WARNING, CRITICAL}
const LEVEL_NAMES := ["NOMINAL", "CAUTION", "WARNING", "CRITICAL"]

## The measured value for each threshold id (ratios; see thresholds.csv).
func measure(id: String, x: Dictionary) -> float:
	var m := mission()
	var req: Dictionary = m["requirements"]
	match id:
		"mass_used": return x["mass"] / maxf(float(m["mass_limit"]), 0.001)
		"rocket_used": return x["mass"] / x["rocket_cap"] if x["rocket_cap"] > 0.0 else 99.0
		"budget_used": return x["cost"] / maxf(float(m["budget"]), 0.001)
		"power_margin": return (x["gen_avg"] - x["load_w"]) / maxf(x["load_w"], 0.001)
		"battery_dod": return x["need_wh"] / maxf(float(part_of("battery").get("energy", 0.001)), 0.001)
		"downlink_load": return x["data_gen"] / maxf(x["downlink"], 0.0001)
		"storage_days": return x["storage"] / maxf(x["data_gen"], 0.0001)
		"data_margin": return x["useful_per_day"] / maxf(float(req["min_data_delivered"]), 0.0001)
		"revisit_ratio": return float(x["revisit"]) / maxf(float(req["max_revisit_days"]), 1.0)
		"life_margin": return x["life_cap"] / maxf(float(lifetime_years), 0.001)
		"lifetime_req": return float(lifetime_years) / maxf(float(req["min_lifetime"]), 1.0)
	return 0.0

static func level_of(v: float, row: Dictionary) -> int:
	var c := float(row["caution"])
	var w := float(row["warning"])
	var k := float(row["critical"])
	if row["direction"] == "max":
		return CRITICAL if v > k else (WARNING if v > w else (CAUTION if v > c else NOMINAL))
	return CRITICAL if v < k else (WARNING if v < w else (CAUTION if v < c else NOMINAL))

static func fmt_value(v: float, kind: String) -> String:
	match kind:
		"percent": return "%d%%" % roundi(v * 100.0)
		"signed_percent": return "%+d%%" % roundi(v * 100.0)
		"days": return "%.1f days" % v
		"times": return "%.1fx" % v
	return "%.2f" % v

## Every threshold check for a design: [{id, label, value, shown, level, blocks, why, fix, message}]
func assess(x = null) -> Array:
	if x == null:
		x = compute()["extra"]
	var out: Array = []
	for row in GameData.THRESHOLDS:
		var id: String = row["id"]
		if id == "storage_days" and x.get("storage", 0.0) <= 0.0:
			continue
		var v := measure(id, x)
		var lvl := level_of(v, row)
		var shown := fmt_value(v, row["format"])
		var msg: String = "%s: %s - %s" % [row["label"], shown, LEVEL_NAMES[lvl]]
		if lvl > NOMINAL:
			msg += ". " + row["why"] + " Fix: " + row["fix"]
		out.append({"id": id, "label": row["label"], "value": v, "shown": shown, "level": lvl,
			"blocks": row["blocks_launch"] == "yes", "why": row["why"], "fix": row["fix"], "message": msg,
			"limits": [float(row["caution"]), float(row["warning"]), float(row["critical"])], "direction": row["direction"], "format": row["format"]})
	return out

func worst_level(rows: Array) -> int:
	var w := NOMINAL
	for r in rows:
		w = maxi(w, r["level"])
	return w


# ============================================================================ LEVEL HAND-OVER
## Budget left after the spacecraft, the launch and operations are paid for.
func budget_left() -> float:
	return float(mission()["budget"]) - float(compute()["extra"]["cost"])

## Result of Level 1, handed to Level 2.
func launch_results() -> Dictionary:
	var x: Dictionary = compute()["extra"]
	return {"rocket": rocket()["name"], "orbit": orbit()["name"], "orbit_id": orbit_id, "rocket_id": rocket_id,
		"mass_kg": x["mass"], "launch_cost": x["rocket_cost"], "total_cost": x["cost"], "budget_left": budget_left(),
		"picks": picks.duplicate(), "lifetime_years": lifetime_years}

## Update a live in-level number and tell the UI (instrumentation panel, console, tutor).
func set_live(key: String, value) -> void:
	live[key] = value
	state_changed.emit()
