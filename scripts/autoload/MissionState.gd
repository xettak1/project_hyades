extends Node
## Holds the player's current design and works out every resource from it.

signal design_changed

var mission_id: String = "flood_watch"
var picks: Dictionary = {}          # category -> part id
var orbit_id: String = ""
var rocket_id: String = ""
var lifetime_years: int = 2
var last_result: Dictionary = {}    # filled by the simulation
var best_scores: Dictionary = {}    # mission id -> best score
var runs: int = 0
var phase: String = "design"        # design | ops
var open_select := false            # title screen opens straight on mission select

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
	var storage: float = float(part_of("computer").get("storage", 0.0))
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

	if x["load_w"] > x["gen_avg"]:
		warn.append("Parts use %.0f W but the panels give only %.0f W on average. The payload will have to switch off part of the time." % [x["load_w"], x["gen_avg"]])
	if x["need_wh"] > x["usable_wh"]:
		warn.append("Each eclipse needs %.0f Wh but the battery can safely give %.0f Wh. The spacecraft will go into safe mode in the dark." % [x["need_wh"], x["usable_wh"]])
	if x["data_gen"] > x["downlink"]:
		var lost_pct: float = 100.0 * (1.0 - x["downlink"] / x["data_gen"])
		warn.append("Payload makes %.1f GB/day but the radio can send %.2f GB/day: about %d%% of the data will never reach Earth." % [x["data_gen"], x["downlink"], int(lost_pct)])
	if x["useful_per_day"] < float(req["min_data_delivered"]):
		warn.append("Only %.2f GB/day of useful data will reach Earth. The requirement is %.1f GB/day." % [x["useful_per_day"], req["min_data_delivered"]])
	if x["revisit"] > int(req["max_revisit_days"]):
		warn.append("Your design covers the target every %d days. The requirement is every %d days or better." % [x["revisit"], req["max_revisit_days"]])
	if req.has("max_resolution_m") and x["resolution"] > float(req["max_resolution_m"]):
		warn.append("The payload sees %.1f m details, but the requirement is %.1f m or better." % [x["resolution"], req["max_resolution_m"]])
	if lifetime_years > x["life_cap"]:
		var why := "the fuel runs out" if has_fuel_system() else "drag pulls it down"
		warn.append("You planned %d years but %s after about %.1f years." % [lifetime_years, why, x["life_cap"]])
	if lifetime_years < int(req["min_lifetime"]):
		warn.append("Planned lifetime is %d years; the requirement is at least %d." % [lifetime_years, req["min_lifetime"]])
	return {"hard": hard, "warn": warn}
