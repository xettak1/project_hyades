class_name Consequences
extends RefCounted
## Turns "design now" vs "design after a decision" into plain-language consequence lines.
## Each line: [text, kind] where kind is "good", "bad", "warn" or "info".

## [label, key, unit, decimals, direction: +1 = more is better, -1 = less is better, 0 = neutral]
const METRICS := [
	["Useful data reaching Earth", "useful_per_day", "GB/day", 2, 1],
	["Data made by the payload", "data_gen", "GB/day", 2, 1],
	["Radio can send", "downlink", "GB/day", 2, 1],
	["Revisit", "revisit", "days", 0, -1],
	["Power used (average)", "load_w", "W", 1, -1],
	["Solar power (average)", "gen_avg", "W", 1, 1],
	["Battery spare in eclipse", "battery_spare", "Wh", 1, 1],
	["Mass at launch", "mass", "kg", 2, -1],
	["Total cost", "cost", "$M", 2, -1],
	["Orbit can last", "life_cap", "years", 0, 1],
]

const SHORT := {"useful_per_day": "Data to Earth", "data_gen": "Data made", "downlink": "Radio speed", "revisit": "Revisit",
	"load_w": "Power used", "gen_avg": "Solar power", "battery_spare": "Battery spare", "mass": "Mass", "cost": "Cost", "life_cap": "Orbit life"}

## Short rows for the Decision card: [label, "+0.09 GB/day", kind]. Most important first.
static func compact(before: Dictionary, after: Dictionary, max_rows: int = 3) -> Array:
	var out: Array = []
	for mrow in METRICS:
		var a := _val(before["x"], mrow[1])
		var b := _val(after["x"], mrow[1])
		if absf(b - a) < 0.005:
			continue
		var fmt := "%+." + str(mrow[3]) + "f"
		var unit: String = mrow[2]
		var txt := (fmt % (b - a)) + " " + unit
		if unit == "$M":
			txt = ("+$%.2fM" if b > a else "−$%.2fM") % absf(b - a)
		var kind := "info" if mrow[4] == 0 else ("good" if (b - a) * mrow[4] > 0.0 else "warn")
		out.append([SHORT.get(mrow[1], mrow[0]), txt, kind])
		if out.size() >= max_rows:
			break
	return out

static func _val(x: Dictionary, key: String) -> float:
	if key == "battery_spare":
		return float(x["usable_wh"]) - float(x["need_wh"])
	return float(x.get(key, 0.0))

## Numeric changes, most important first. max_rows limits the list.
static func changes(before: Dictionary, after: Dictionary, max_rows: int = 10) -> Array:
	var out: Array = []
	for mrow in METRICS:
		var a := _val(before["x"], mrow[1])
		var b := _val(after["x"], mrow[1])
		if absf(b - a) < 0.005:
			continue
		var fmt := "%." + str(mrow[3]) + "f"
		var better: bool = (b - a) * mrow[4] > 0.0
		var kind := "info" if mrow[4] == 0 else ("good" if better else "warn")
		out.append(["%s: %s → %s %s" % [mrow[0], fmt % a, fmt % b, mrow[2]], kind])
		if out.size() >= max_rows:
			break
	return out

## What the decision does to the warning levels (thresholds.csv), and what is still not nominal.
static func verdicts(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	var still: Array = []
	var prev := {}
	for r in before["assess"]:
		prev[r["id"]] = r
	for r in after["assess"]:
		var was: int = prev[r["id"]]["level"] if prev.has(r["id"]) else 0
		var now: int = r["level"]
		var names: Array = MissionState.LEVEL_NAMES
		if now < was:
			out.append(["▼ %s: %s → %s (%s)" % [r["label"], names[was], names[now], r["shown"]], "good" if now == 0 else "warn"])
		elif now > was:
			out.append(["▲ %s: %s → %s (%s)" % [r["label"], names[was], names[now], r["shown"]], level_kind(now)])
		elif now >= 2:
			still.append(["• still %s: %s (%s)" % [names[now], r["label"], r["shown"]], level_kind(now)])
	return out + still

static func level_kind(level: int) -> String:
	return ["good", "warn", "bad", "critical"][clampi(level, 0, 3)]

## One short sentence for tight spaces (the console).
static func summary(before: Dictionary, after: Dictionary) -> Array:
	var parts: Array = []
	var kind := "info"
	for v in verdicts(before, after):
		if v[0].begins_with("•"):
			continue
		parts.append(v[0])
		if v[1] == "bad" or v[1] == "critical":
			kind = "bad"
		elif v[1] == "warn" and kind != "bad":
			kind = "warn"
		elif kind == "info":
			kind = "good"
	for c in changes(before, after, 3):
		parts.append(c[0])
	if parts.is_empty():
		return ["No change to your results.", "info"]
	return ["   ".join(parts), kind]

static func color(kind: String) -> Color:
	match kind:
		"good": return Color("#34d399")
		"bad": return Color("#f87171")
		"critical": return Color("#ff3b3b")
		"warn": return Color("#fbbf24")
	return Color("#cbd5e1")

static func level_color(level: int) -> Color:
	return color(level_kind(level))
