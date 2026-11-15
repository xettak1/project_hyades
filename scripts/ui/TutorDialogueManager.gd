extends Node
## TUTOR DIALOGUE MANAGER: decides what the Mission Tutor says, in every level.
##  - Guided steps for the current level, from data/dialogue/tutor_dialogue.json
##    (a step ends when its 'until' happens: Enter, walking, opening a screen, installing a part...)
##  - Reactions to the player's actual decisions (parts, rocket, orbit) and to warning levels
##    getting worse or being fixed (thresholds.csv), filled with live numbers.
##  - A short explanation the first time the player looks at each kind of part.
##  - A bouncing 3D arrow pointing at where to go next.
## The text appears in the MissionTutor console at the bottom of the screen.
## Other scripts talk to it through the "tutor" group: on_screen_opened, on_screen_closed,
## on_part_focus, on_event.

const DIALOGUE := "res://data/dialogue/tutor_dialogue.json"
const MissionTutorUI := preload("res://scripts/ui/MissionTutor.gd")

var room: Node3D                  # the level room (needs .player)
var ui
var level := "launch"
var data: Dictionary = {}
var steps: Array = []
var stage := ""
var line := 0
var reaction: Dictionary = {}     # {text, kind} while a reaction is on screen
var _flags := {}
var _seen_cats := {}
var _snap: Dictionary = {}        # design before the last change (for reactions)
var _arrow: Label3D
var _arrow_t := 0.0
var _start_pos := Vector3.ZERO

func _ready() -> void:
	add_to_group("tutor")
	level = LevelFlow.current_id() if LevelFlow.index >= 0 else "launch"
	var f := FileAccess.open(DIALOGUE, FileAccess.READ)
	if f:
		data = JSON.parse_string(f.get_as_text())
	var lv: Dictionary = data.get("levels", {}).get(level, {})
	steps = lv.get("steps", [])
	stage = lv.get("stage", level.to_upper())
	ui = MissionTutorUI.new()
	add_child(ui)
	ui.next_pressed.connect(next)
	ui.skip_pressed.connect(skip)
	_arrow = Label3D.new()
	_arrow.text = "▼"
	_arrow.font_size = 160
	_arrow.pixel_size = 0.004
	_arrow.outline_size = 18
	_arrow.modulate = Color(1.0, 0.8, 0.2)
	_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_arrow.no_depth_test = true
	_arrow.render_priority = 20
	_arrow.visible = false
	room.add_child.call_deferred(_arrow)
	_start_pos = room.player.global_position if room.player else Vector3.ZERO
	_snap = _snapshot()
	MissionState.design_changed.connect(_on_design_changed)
	line = 0
	_show()

# ======================================================================= state
func step_index() -> int:
	return int(MissionState.tutor_steps.get(level, 0))

func guided() -> bool:
	return MissionState.tutor_enabled and step_index() < steps.size()

func _step() -> Dictionary:
	return steps[step_index()] if step_index() < steps.size() else {}

## Live numbers the dialogue can use as {placeholders}.
func context() -> Dictionary:
	var m := MissionState.mission()
	var req: Dictionary = m["requirements"]
	var o := MissionState.orbit()
	var x: Dictionary = MissionState.compute()["extra"]
	var r: Dictionary = MissionState.level_results
	var lines: Array = []
	for id in m["orbits"]:
		var ob: Dictionary = GameData.ORBITS[id]
		lines.append("%s: we'd see the farms every %d days, with %d minutes a day to talk to Earth." % [ob["name"].split(" (")[0], ob["revisit_days"], int(ob["contact_min_per_day"])])
	return {"budget": str(m["budget"]), "mass_limit": str(m["mass_limit"]), "cost": "%.2f" % x["cost"],
		"left": "%.2f" % (float(m["budget"]) - x["cost"]), "mass": "%.1f" % x["mass"],
		"eclipse": str(int(o["eclipse_min"])), "period": str(int(o["period_min"])), "contact": str(int(o["contact_min_per_day"])),
		"data_gen": "%.2f" % x["data_gen"], "downlink": "%.2f" % x["downlink"], "useful": "%.2f" % x["useful_per_day"],
		"min_data": "%.1f" % req["min_data_delivered"], "max_revisit": str(req["max_revisit_days"]), "min_life": str(req["min_lifetime"]),
		"revisit": str(x["revisit"]), "pointing_pct": str(int(100.0 * x["pointing"])), "orbit": o["name"], "rocket": MissionState.rocket().get("name", "no rocket yet"),
		"rocket_cost": "%.2f" % x["rocket_cost"], "orbit_lines": " ".join(lines),
		"days": str(int(30)), "collected": "%.1f" % r.get("space", {}).get("collected_gb", 0.0),
		"received": "%.1f" % r.get("ground", {}).get("received_gb", 0.0),
		"stored": "%.1f" % float(MissionState.live.get("stored_gb", 0.0)), "storage": "%.0f" % x["storage"],
		"scan_gb": str(MissionState.live.get("scan_gb", "")),
		"left_onboard": "%.1f" % maxf(float(MissionState.live.get("onboard_gb", 0.0)) - float(MissionState.live.get("received_gb", 0.0)), 0.0),
		"flood_found": str(MissionState.live.get("flood_found", "0")), "flood_total": str(MissionState.live.get("flood_total", "0")),
		"unseen_flood": str(MissionState.live.get("unseen_flood", "0"))}

func _fill(text: String) -> String:
	return text.format(context())

# ======================================================================= showing
func _show() -> void:
	if not reaction.is_empty():
		ui.show_line(reaction["text"], stage, "", true, false, reaction["kind"])
		return
	if not guided():
		ui.show_line(_idle_line(), stage, "", false, false, "step")
		return
	var st := _step()
	var says: Array = st.get("say", [])
	line = clampi(line, 0, says.size() - 1)
	var last := line >= says.size() - 1
	var until: String = st.get("until", "next")
	ui.show_line(_fill(says[line]), stage,
		st.get("todo", "") if last else "", (not last) or until == "next", says.size() > 1 and not last, "step")

func _idle_line() -> String:
	match level:
		"launch": return "You're in charge, Director. The **instructions** on the right show what to do next."
		"space": return "Scan the regions that are **in view** and not under cloud."
		"ground": return "Choose a **priority**, then start the pass."
	return "Find the **flooded plots** and warn the farmers."

func next() -> void:
	if ui.is_typing():
		ui.finish_typing()
		return
	if not reaction.is_empty():
		reaction = {}
		_show()
		return
	if not guided():
		return
	var st := _step()
	var says: Array = st.get("say", [])
	if line < says.size() - 1:
		line += 1
		_show()
	elif st.get("until", "next") == "next":
		_advance()

func skip() -> void:
	if not reaction.is_empty():
		reaction = {}
		_show()
		return
	if not guided():
		return
	var st := _step()
	line = st.get("say", []).size() - 1
	if st.get("until", "next") == "next":
		_advance()
	else:
		_show()

func _advance() -> void:
	MissionState.tutor_steps[level] = step_index() + 1
	_flags.clear()
	line = 0
	_show()

## Interrupts with a reaction (kind: reaction / good / alert). The guided step comes back on Next.
func react(text: String, kind := "reaction") -> void:
	reaction = {"text": _fill(text), "kind": kind}
	_show()

# ======================================================================= decisions -> reactions
func _snapshot() -> Dictionary:
	var lv := {}
	for r in MissionState.assess():
		lv[r["id"]] = r["level"]
	return {"picks": MissionState.picks.duplicate(), "orbit": MissionState.orbit_id, "rocket": MissionState.rocket_id, "levels": lv}

func _on_design_changed() -> void:
	_flags["pick"] = true
	if MissionState.picks != _snap.get("picks", {}):
		get_tree().call_group("instructions", "on_pick")
	if MissionState.phase != "design":
		_snap = _snapshot()
		return
	var now := _snapshot()
	var found: Array = []      # [priority, rule]
	for rule in data.get("reactions", []):
		match rule.get("when", ""):
			"pick":
				var cat: String = rule["category"]
				if now["picks"].get(cat, "") != _snap["picks"].get(cat, "") and GameData.part(cat, now["picks"].get(cat, "")).get("tier", "") == rule["tier"]:
					found.append([1, rule])
			"rocket":
				if now["rocket"] != _snap["rocket"] and now["rocket"] == rule["id"]:
					found.append([1, rule])
			"orbit":
				if now["orbit"] != _snap["orbit"] and now["orbit"] == rule["id"]:
					found.append([1, rule])
			"worse":
				var c: String = rule["check"]
				if now["levels"].get(c, 0) > _snap["levels"].get(c, 0) and now["levels"].get(c, 0) >= int(rule.get("min_level", 2)):
					found.append([3, rule])
			"fixed":
				var c2: String = rule["check"]
				if now["levels"].get(c2, 0) == 0 and _snap["levels"].get(c2, 0) >= 1:
					found.append([2, rule])
	_snap = now
	if found.is_empty():
		return
	found.sort_custom(func(a, b): return a[0] > b[0])
	react(found[0][1]["say"], found[0][1].get("kind", "reaction"))

# ======================================================================= events from the game
func on_screen_opened(name: String) -> void:
	_flags["open:" + name] = true
	get_tree().call_group("instructions", "on_screen_opened", name)

func on_screen_closed() -> void:
	_flags["close"] = true

func on_part_focus(category: String) -> void:
	_flags["focus_part"] = true
	get_tree().call_group("instructions", "on_part_focus", category)
	if not _seen_cats.has(category) and reaction.is_empty():
		_seen_cats[category] = true
		var c: String = data.get("concepts", {}).get(category, "")
		if c != "" and MissionState.tutor_enabled:
			react(c, "reaction")

func on_event(ev: String) -> void:
	get_tree().call_group("instructions", "on_event", ev)
	_flags["event:" + ev] = true
	_flags[ev] = true
	for rule in data.get("reactions", []):
		if rule.get("when", "") == "event" and rule.get("id", "") == ev:
			react(rule["say"], rule.get("kind", "reaction"))

# ======================================================================= per frame
func _process(delta: float) -> void:
	if guided():
		if _check(_step().get("until", "next")):
			_advance()
		else:
			_update_arrow(_step(), delta)
	else:
		_arrow.visible = false

func _check(until: String) -> bool:
	match until:
		"next":
			return false
		"move":
			return room.player and room.player.global_position.distance_to(_start_pos) > 2.0
		"close":
			return not _sv_open()
		"focus_part", "pick", "launch":
			return _flags.get(until, false)
		"adcs":
			return MissionState.part_of("adcs").get("tier", "") == "advanced"
	if until == "pick":
		return _flags.get("pick", false)
	return _flags.get(until, false)

func _update_arrow(st: Dictionary, delta: float) -> void:
	var target: String = st.get("target", "")
	if target == "" or _sv_open() or ui.is_collapsed():
		_arrow.visible = false
		return
	var pos = null
	if target == "shelf" or target == "adcs":
		var best := INF
		for n in room.find_children("*", "StaticBody3D", true, false):
			if "part_id" in n and (target == "shelf" or n.category == "adcs" and GameData.part("adcs", n.part_id).get("tier", "") == "advanced"):
				var d: float = n.global_position.distance_to(room.player.global_position)
				if d < best:
					best = d
					pos = n.global_position + Vector3(0, 1.4, 0)
	else:
		for n in room.find_children("*", "StaticBody3D", true, false):
			if "screen_name" in n and n.screen_name == target:
				pos = n.global_position + Vector3(0, n.size_m.y / 2.0 + 0.9, 0)
	if pos == null:
		_arrow.visible = false
		return
	_arrow_t += delta
	_arrow.visible = true
	_arrow.global_position = pos + Vector3(0, 0.15 * sin(_arrow_t * 4.0), 0)

func _sv_open() -> bool:
	for n in get_tree().get_nodes_in_group("screenview"):
		if n.is_open():
			return true
	return false

## Pixels the tutor console takes at the bottom (other UI keeps clear of it).
func used_height() -> float:
	return ui.used_height() if ui else 0.0

# ======================================================================= keys
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or get_tree().paused or LevelFlow.busy:
		return
	match event.keycode:
		KEY_T:
			ui.toggle()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			next()
			get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			skip()
			get_viewport().set_input_as_handled()
