class_name Debrief
## Mission debrief: turns what the player actually did in each level into a verdict
## (GOOD / FAIR / POOR), a 0-100 level score, and short "did right" / "could improve" lines.
## Reads MissionState.level_results (filled by LevelFlow.complete) and the launch design.

const GOOD := "GOOD"
const FAIR := "FAIR"
const POOR := "POOR"
const NONE := "NOT PLAYED"

const LEVEL_ORDER := [["launch", "LAUNCH"], ["space", "SPACE"], ["ground", "GROUND"], ["user", "USER"]]

## Full debrief: {"levels": [ {id, title, verdict, score, stat, right, improve} x4 ],
##                "score": 0-1000, "rating": String}
static func build() -> Dictionary:
	var r: Dictionary = MissionState.level_results
	var out: Array = []
	for lv in LEVEL_ORDER:
		var d: Dictionary = r.get(lv[0], {})
		var e: Dictionary
		if d.is_empty():
			e = {"verdict": NONE, "score": 0.0, "stat": "This level was not finished.", "right": [], "improve": []}
		else:
			match lv[0]:
				"launch": e = _launch(d)
				"space": e = _space(d)
				"ground": e = _ground(d)
				"user": e = _user(d)
		e["id"] = lv[0]
		e["title"] = lv[1]
		e["right"] = (e["right"] as Array).slice(0, 2)
		e["improve"] = (e["improve"] as Array).slice(0, 2)
		out.append(e)
	var total := 0.0
	for e in out:
		total += float(e["score"])
	var score := int(round(total / out.size() * 10.0))
	return {"levels": out, "score": score, "rating": rating(score)}

static func rating(score: int) -> String:
	if score >= 850: return "OUTSTANDING"
	if score >= 650: return "MISSION SUCCESS"
	if score >= 450: return "PARTIAL SUCCESS"
	return "MISSION SHORTFALL"

static func _verdict(score: float) -> String:
	if score >= 75.0: return GOOD
	if score >= 45.0: return FAIR
	return POOR

static func _done(e: Dictionary) -> Dictionary:
	e["score"] = clampf(e["score"], 0.0, 100.0)
	e["verdict"] = _verdict(e["score"])
	return e

# ----------------------------------------------------------------------------- LEVEL 1
static func _launch(d: Dictionary) -> Dictionary:
	var m := MissionState.mission()
	var ch: Dictionary = MissionState.current()["checks"]
	var right: Array = []
	var improve: Array = []
	var score := 100.0
	var left: float = d.get("budget_left", 0.0)
	var mass: float = d.get("mass_kg", 0.0)
	var budget := float(m.get("budget", 1.0))
	# Requirements: the big ones.
	var req_fail := 0
	for k in ["req_revisit", "req_data", "req_life"]:
		if not ch.get(k, [true])[0]:
			req_fail += 1
			score -= 22.0
	if not ch.get("req_revisit", [true])[0]:
		improve.append("Revisit is too slow for this mission. A better orbit or pointing system brings it under %d days." % int(m["requirements"]["max_revisit_days"]))
	if not ch.get("req_data", [true])[0]:
		improve.append("Too little useful data reaches Earth. A sharper camera or faster radio fixes this.")
	if not ch.get("req_life", [true])[0]:
		improve.append("The satellite won't last the required %d years. Check battery and lifetime choices." % int(m["requirements"]["min_lifetime"]))
	# Engineering checks.
	if not ch.get("power", [true])[0]:
		score -= 12.0
		improve.append("Solar panels can't cover the average power use. Bigger panels or a lower-power payload would help.")
	if not ch.get("battery", [true])[0]:
		score -= 12.0
		improve.append("The battery runs flat during eclipses. A larger battery keeps it alive in Earth's shadow.")
	if not ch.get("downlink", [true])[0]:
		score -= 10.0
		improve.append("The radio is slower than the camera. Data will pile up onboard; pick a faster radio.")
	# What went well.
	if req_fail == 0:
		right.append("Your design met all three mission requirements: revisit, data and lifetime.")
	var frac := left / maxf(budget, 0.001)
	if frac >= 0.1:
		right.append("Stayed on budget with $%.2fM to spare." % left)
	elif left >= 0.0:
		right.append("Stayed within budget, with only $%.2fM left over." % left)
		score -= 4.0
	if ch.get("power", [true])[0] and ch.get("battery", [true])[0]:
		right.append("Power system covers daylight and every eclipse.")
	if mass <= float(m.get("mass_limit", 0.0)) * 0.6:
		right.append("Light build: %.1f kg, well under the %s kg limit." % [mass, str(m["mass_limit"])])
	var stat := "%s on %s  ·  %.1f kg  ·  $%.2fM left" % [d.get("orbit", "-"), d.get("rocket", "-"), mass, left]
	return _done({"score": score, "stat": stat, "right": right, "improve": improve})

# ----------------------------------------------------------------------------- LEVEL 2
static func _space(d: Dictionary) -> Dictionary:
	var right: Array = []
	var improve: Array = []
	var collected: float = d.get("collected_gb", 0.0)
	var useful: float = d.get("useful_gb", 0.0)
	var overflow: float = d.get("overflow_gb", 0.0)
	var regions: int = (d.get("scanned", []) as Array).size()
	var scans: int = int(d.get("scans", 0))
	var clear := useful / maxf(collected, 0.001)
	# 50 for coverage of the four regions, 35 for clear (usable) imagery, 15 for not overflowing.
	var score := 50.0 * regions / 4.0 + 35.0 * clampf(clear / 0.8, 0.0, 1.0) + (15.0 if overflow < 0.01 else 15.0 * clampf(1.0 - overflow / maxf(collected, 0.001), 0.0, 1.0))
	if regions >= 4:
		right.append("Photographed all four farm regions, so no farmer was left without data.")
	elif regions > 0:
		improve.append("Only %d of 4 regions were photographed in clear skies. The rest get no flood warning." % regions)
	else:
		improve.append("No region was photographed in clear skies. Wait for the clouds to pass before scanning.")
	if collected > 0.0 and clear >= 0.7:
		right.append("Timed scans well: %d%% of the imagery was usable." % int(round(clear * 100.0)))
	elif collected > 0.0:
		improve.append("Much of the imagery was through cloud (%d%% usable). Scan when the cloud cover meter is low." % int(round(clear * 100.0)))
	if overflow > 0.01:
		improve.append("Storage filled up and %.1f GB of pictures was dropped. Fewer, better-timed scans avoid this." % overflow)
	elif scans > 0:
		right.append("Never overfilled onboard storage.")
	var stat := "%.1f GB collected  ·  %d of 4 regions  ·  %d scans" % [collected, regions, scans]
	return _done({"score": score, "stat": stat, "right": right, "improve": improve})

# ----------------------------------------------------------------------------- LEVEL 3
static func _ground(d: Dictionary) -> Dictionary:
	var right: Array = []
	var improve: Array = []
	var got: float = d.get("received_gb", 0.0)
	var left: float = d.get("left_onboard_gb", 0.0)
	var lost: float = d.get("lost_gb", 0.0)
	var delay: float = d.get("delay_days", 0.0)
	var prio: String = d.get("priority", "floods")
	var frac := got / maxf(got + left, 0.001)
	var score := 60.0 * frac + (25.0 if prio == "floods" else 10.0) + 15.0 * clampf(1.0 - (delay - 1.0) / 5.0, 0.0, 1.0)
	if frac >= 0.95:
		right.append("Brought down %.1f GB, everything that was onboard." % got)
	elif got > 0.0:
		improve.append("%.1f GB stayed onboard when the passes ran out. Keep the dish locked on for the whole pass." % left)
	else:
		improve.append("No data reached the ground. Track the satellite during each pass to open the link.")
	if prio == "floods":
		right.append("Sent flood imagery first, so the urgent pictures arrived first.")
	else:
		improve.append("Crops went first, so the flood pictures arrived later. For a flood mission, floods should lead.")
	if delay > 3.0:
		improve.append("Data took about %.0f days to reach users. The radio is the bottleneck." % delay)
	elif delay <= 1.5:
		right.append("Data reached users within about a day.")
	var stat := "%.1f GB received  ·  %.1f GB lost  ·  %.1f days delay" % [got, lost, delay]
	return _done({"score": score, "stat": stat, "right": right, "improve": improve})

# ----------------------------------------------------------------------------- LEVEL 4
const PRODUCT_NAMES := {"alert": "an emergency flood alert", "map": "a flood risk map", "report": "a crop health report", "dashboard": "a monitoring dashboard"}

static func _user(d: Dictionary) -> Dictionary:
	var right: Array = []
	var improve: Array = []
	var total: int = int(d.get("flood_total", 0))
	var found: int = int(d.get("flood_found", 0))
	var falses: int = int(d.get("false_marks", 0))
	var unseen: int = int(d.get("unseen_flood", 0))
	var missed: int = int(d.get("missed_seen", 0))
	var products: Array = d.get("products", [])
	var product: String = products[0] if not products.is_empty() else ""
	var score := 100.0 * float(d.get("impact", 0.0))
	if total > 0 and found >= total:
		right.append("Found every flooded plot (%d of %d)." % [found, total])
	elif found > 0:
		right.append("Spotted %d of %d flooded plots." % [found, total])
	if product == "alert" or product == "map":
		right.append("Sent %s, which is what flood responders need." % PRODUCT_NAMES[product])
	elif product != "":
		improve.append("Sent %s. For floods, an alert or a flood map gets people moving faster." % PRODUCT_NAMES.get(product, product))
	if missed > 0:
		improve.append("%d flooded plot%s had imagery but %s not marked. Look for dark, smooth water." % [missed, "s" if missed > 1 else "", "were" if missed > 1 else "was"])
	if falses > 0:
		improve.append("%d dry plot%s marked as flooded. False alarms cost responders' trust." % [falses, "s were" if falses > 1 else " was"])
	elif found > 0:
		right.append("No false alarms.")
	if unseen > 0:
		improve.append("%d flooded plot%s had no imagery at all. More clear scans in Level 2 would reveal them." % [unseen, "s" if unseen > 1 else ""])
	var stat := "%d of %d floods found  ·  %d%% of plots seen  ·  %s" % [found, total, int(round(100.0 * float(d.get("coverage", 0.0)))), PRODUCT_NAMES.get(product, "no product").trim_prefix("an ").trim_prefix("a ")]
	return _done({"score": score, "stat": stat, "right": right, "improve": improve})
