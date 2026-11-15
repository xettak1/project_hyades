extends RefCounted
## Day-by-day mission simulation. Create it, then call step_day() until done.

var x: Dictionary            # extra values from MissionState.compute()
var snapshot: Dictionary     # the whole compute() result at setup, so results never re-read the live design
var req: Dictionary
var planned_days: int
var life_cap_days: int
var cruise_days: int = 0
var rng := RandomNumberGenerator.new()

var day: int = 0
var done: bool = false
var end_reason: String = ""

# Running totals
var generated_total := 0.0
var sent_total := 0.0
var useful_total := 0.0
var lost_total := 0.0
var stored := 0.0
var safe_mode_days := 0
var power_limited_days := 0

# Event state
var storm_days_left := 0
var outage_days_left := 0
var wheel_failed := false
var events: Array = []       # {day, title, text}
var _event_plan: Array = []  # [day, kind]

func setup(design: Dictionary, requirements: Dictionary, lifetime_years: int, seed_value: int = 0) -> void:
	snapshot = design.duplicate(true)
	x = snapshot["extra"]
	req = requirements
	cruise_days = int(x.get("transfer_days", 0))
	planned_days = cruise_days + lifetime_years * 365
	life_cap_days = cruise_days + int(float(x["life_cap"]) * 365.0)
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	_plan_events()

func _plan_events() -> void:
	# Roughly 1 event per year of mission, at random days.
	var kinds := ["storm", "outage", "wheel", "storm", "outage"]
	var count: int = maxi(1, (planned_days - cruise_days) / 365)
	for i in count:
		var d: int = rng.randi_range(cruise_days + 20, maxi(cruise_days + 21, planned_days - 30))
		_event_plan.append([d, kinds[rng.randi_range(0, kinds.size() - 1)]])

func _trigger(kind: String) -> void:
	match kind:
		"storm":
			# A bigger battery margin shortens the safe mode.
			var spare: float = x["usable_wh"] - x["need_wh"]
			storm_days_left = 1 if spare > 0.5 * x["need_wh"] else 3
			events.append({"day": day, "title": "Solar storm",
				"text": "Charged particles from the Sun hit the spacecraft. It switched to safe mode for %d day(s). A bigger battery margin shortens this." % storm_days_left})
		"outage":
			outage_days_left = 5
			events.append({"day": day, "title": "Ground station outage",
				"text": "Your ground station is down for 5 days. Images pile up in storage; if storage fills, new images are lost."})
		"wheel":
			if x["pointing"] >= 0.9:
				events.append({"day": day, "title": "Reaction wheel fault",
					"text": "One reaction wheel failed, but the precise pointing system has a spare. No effect."})
			else:
				wheel_failed = true
				events.append({"day": day, "title": "Attitude sensor fault",
					"text": "A sensor failed. Basic pointing is now worse: more images miss the target for the rest of the mission."})

func in_cruise() -> bool:
	return day < cruise_days

func step_day() -> void:
	if done:
		return
	if in_cruise():
		day += 1
		if day == cruise_days:
			events.append({"day": day, "title": "Arrived in lunar orbit",
				"text": "The engine fired to brake into a 50 km polar orbit. Mapping begins."})
		return
	for e in _event_plan:
		if e[0] == day:
			_trigger(e[1])

	# How much of the day can the payload run?
	var duty := 1.0
	if x["load_w"] > x["gen_avg"] and x["load_w"] > 0.0:
		duty = x["gen_avg"] / x["load_w"]
		power_limited_days += 1
	if x["need_wh"] > x["usable_wh"] and x["need_wh"] > 0.0:
		duty *= clampf(x["usable_wh"] / x["need_wh"], 0.0, 1.0)
	if storm_days_left > 0:
		duty = 0.0
		storm_days_left -= 1
		safe_mode_days += 1

	var downlink: float = x["downlink"]
	if outage_days_left > 0:
		downlink = 0.0
		outage_days_left -= 1

	var pointing: float = x["pointing"]
	if wheel_failed:
		pointing *= 0.8

	var gen: float = x["data_gen"] * duty
	generated_total += gen
	stored += gen
	var sent: float = minf(stored, downlink * maxf(duty, 0.3))
	stored -= sent
	sent_total += sent
	useful_total += sent * pointing
	if stored > x["storage"]:
		lost_total += stored - x["storage"]
		stored = x["storage"]

	day += 1
	if day >= life_cap_days and life_cap_days < planned_days:
		done = true
		end_reason = "drag"
		events.append({"day": day, "title": "Re-entry",
			"text": ("Out of fuel: the orbit decayed and the spacecraft hit the Moon, %d days before the planned end." if cruise_days > 0 else "Air drag lowered the orbit until the spacecraft burned up, %d days before the planned end.") % (planned_days - day)})
	elif day >= planned_days:
		done = true
		end_reason = "complete"

func progress() -> float:
	return float(day) / float(maxi(planned_days, 1))

## Final score and explanations.
func result() -> Dictionary:
	var w: Dictionary = GameData.SCORE_WEIGHTS
	var days: int = maxi(day - cruise_days, 1)
	var avg_useful: float = useful_total / days
	var min_data: float = req["min_data_delivered"]
	var min_days: int = int(req["min_lifetime"]) * 365

	var req_met := {
		"revisit": int(x["revisit"]) <= int(req["max_revisit_days"]),
		"data": avg_useful >= min_data,
		"lifetime": day - cruise_days >= min_days,
	}
	if req.has("max_resolution_m"):
		req_met["resolution"] = float(x.get("resolution", 0.0)) <= float(req["max_resolution_m"])
	var met_count := 0
	for k in req_met:
		if req_met[k]:
			met_count += 1
	var s_req: float = w["requirements"] * met_count / float(req_met.size())

	var target: float = min_data * min_days * 3.0   # full points at 3x the minimum
	var s_data: float = w["data"] * clampf(useful_total / target, 0.0, 1.0)

	# Use the snapshot taken at setup: the score must describe the design that was simulated,
	# even if the player has changed parts since.
	var c: Dictionary = snapshot if snapshot.has("mass") else MissionState.compute()
	var eff := 0.0
	for key in ["mass", "power", "budget"]:
		var mg: float = c[key]["margin"]
		if mg < 0.0:
			eff += 0.0
		elif mg < 0.05 or mg > 0.5:
			eff += 0.5
		else:
			eff += 1.0
	var s_eff: float = w["efficiency"] * eff / 3.0
	# Operations: how long it worked, scaled by how useful it was (a spacecraft that sends nothing home isn't working).
	var usefulness: float = clampf(avg_useful / maxf(min_data, 0.001), 0.0, 1.0)
	var s_surv: float = w["survival"] * clampf(float(day) / planned_days, 0.0, 1.0) * usefulness

	var total := int(round(s_req + s_data + s_eff + s_surv))
	var rating := "Mission failure"
	if total >= 800:
		rating = "Outstanding mission"
	elif total >= 600:
		rating = "Mission success"
	elif total >= 400:
		rating = "Partial success"

	return {
		"score": total, "rating": rating,
		"parts": {"Requirements met": s_req, "Data delivered": s_data,
			"Resource efficiency": s_eff, "Survival": s_surv},
		"req_met": req_met, "avg_useful": avg_useful, "useful_total": useful_total,
		"lost_total": lost_total, "generated_total": generated_total, "days": day - cruise_days,
		"planned_days": planned_days, "events": events, "why": _why(req_met, avg_useful, c),
	}

## Plain-language reasons, biggest problems first.
func _why(req_met: Dictionary, avg_useful: float, c: Dictionary) -> Array:
	var out: Array = []   # [importance, text]
	if req_met.has("resolution") and not req_met["resolution"]:
		out.append([95, "Your payload only sees %.0f m details, but the mission needs %.1f m or better. All that data could not answer the science question. Pick the higher-detail instrument." % [x["resolution"], req["max_resolution_m"]]])
	if cruise_days > 0 and x.get("fuel_left", 0.0) >= 0.0 and end_reason == "drag":
		out.append([88, "After braking into orbit only %.0f kg of fuel was left to keep the orbit up. A bigger tank, a lighter spacecraft or the low-energy transfer would leave more." % x["fuel_left"]])
	if x["data_gen"] > x["downlink"]:
		var pct := int(100.0 * (1.0 - x["downlink"] / x["data_gen"]))
		out.append([90, "Your payload made %.1f GB/day but the radio could send only %.2f GB/day, so about %d%% of images never reached Earth. A faster radio or an orbit with more ground-station contact time fixes this." % [x["data_gen"], x["downlink"], pct]])
	if lost_total > 0.0 and x["data_gen"] <= x["downlink"]:
		out.append([60, "%.0f GB of images were lost when storage filled up during an outage. More storage gives you a buffer." % lost_total])
	if not req_met["revisit"]:
		out.append([80, "Your design only covers the target every %d days, slower than the %d days required. A different orbit, or an instrument / pointing system that can look sideways, helps." % [x["revisit"], req["max_revisit_days"]]])
	if power_limited_days > 0:
		out.append([75, "Your parts needed %.0f W but the panels averaged %.0f W, so the payload was switched off part of every day. Bigger panels, an orbit with less eclipse, or fewer power-hungry parts fix this." % [x["load_w"], x["gen_avg"]]])
	if x["need_wh"] > x["usable_wh"]:
		out.append([70, "The battery could not carry the spacecraft through each eclipse (needed %.0f Wh, had %.0f Wh usable), so it kept dropping into safe mode." % [x["need_wh"], x["usable_wh"]]])
	if end_reason == "drag" and cruise_days == 0:
		out.append([85, "Air drag ended the mission after %d days instead of %d. A thruster would have kept the orbit up." % [day, planned_days]])
	if x["pointing"] < 0.9:
		out.append([40, "Your pointing system blurred or missed about %d%% of the images. Precise pointing makes almost every image count." % int(100.0 * (1.0 - x["pointing"]))])
	if safe_mode_days > 0:
		out.append([30, "Solar storms put the spacecraft in safe mode for %d day(s)." % safe_mode_days])
	if c["budget"]["margin"] > 0.5:
		out.append([20, "You left over half the budget unused. A real team would spend it on something that returns more science or reduces risk."])
	if out.is_empty():
		out.append([0, "Clean design: every requirement met with healthy margins. Engineers call that a robust mission."])
	out.sort_custom(func(a, b): return a[0] > b[0])
	var texts: Array = []
	for item in out:
		texts.append(item[1])
	return texts
