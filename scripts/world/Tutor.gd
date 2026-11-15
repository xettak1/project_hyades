extends CanvasLayer
## THE TUTOR: a mission engineer who walks the player through the whole game, one step at a time.
## Each step says what to do and why. A step ends when the player does the thing
## (walks, opens a screen, installs a part, launches...) or presses Enter for "read me" steps.
## A bouncing arrow in the room points at the next thing to go to.
## The first time the player looks at a kind of part, a "CONCEPT" card explains the idea behind it.
## T hides / shows the tutor. Progress is kept in MissionState, so it survives a restart.

var lab: Node
var _panel: PanelContainer
var _step_lbl: Label
var _title: Label
var _body: Label
var _todo: Label
var _keys: Label
var _concept: PanelContainer
var _concept_title: Label
var _concept_body: Label
var _concept_time := 0.0
var _arrow: Label3D
var _arrow_t := 0.0
var _start_pos := Vector3.ZERO
var _flags := {}
var _hidden := false
var _seen_cats := {}
var _compact := false

# until: "next" = press Enter, "move", "open:<screen>", "close", "focus_part", "pick",
#        "radio", "launch", "open_or_done:<screen>", "finished"
var STEPS: Array = []

func _ready() -> void:
	layer = 6
	add_to_group("tutor")
	_build_steps()
	_build_ui()
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
	lab.add_child(_arrow)
	_start_pos = lab.player.global_position
	MissionState.design_changed.connect(func(): _flags["pick"] = true)
	if MissionState.tutor_done:
		_hidden = true
	_show_step()

# ======================================================================= steps
func _x(key: String) -> float:
	return float(MissionState.compute()["extra"][key])

func _orbit_lines() -> String:
	var out: Array = []
	for id in MissionState.mission()["orbits"]:
		var o: Dictionary = GameData.ORBITS[id]
		out.append("• %s: revisit every %d days, %d min/day of ground contact, %d min of eclipse per orbit." % [o["name"], o["revisit_days"], int(o["contact_min_per_day"]), int(o["eclipse_min"])])
	return "\n".join(out)

func _o(key: String):
	return MissionState.orbit()[key]

func _build_steps() -> void:
	var m := MissionState.mission()
	var req: Dictionary = m["requirements"]
	STEPS = [
		{"title": "Welcome, engineer",
		 "text": "I'm your mission tutor. You lead a small team building a 6U CubeSat, a satellite the size of a shoebox. Its job: photograph a farming region so people can spot floods and check crop health.\n\nYou have $%s million and %s kg. I'll walk you through everything, one step at a time." % [str(m["budget"]), str(m["mass_limit"])],
		 "until": "next"},
		{"title": "Moving around",
		 "text": "Use W A S D to walk and the mouse to look around. The + in the middle of the screen is what you are looking at.\n\nTake a few steps.",
		 "todo": "Walk a few steps", "until": "move"},
		{"title": "Read your briefing",
		 "text": "Every space mission starts with requirements: what the spacecraft must achieve. Yours are on the BRIEFING screen on the front wall (follow the yellow arrow).\n\nLook at it and press E to open it in full view.",
		 "todo": "Open the Briefing screen (E)", "until": "open:Briefing", "target": "Briefing"},
		{"title": "Your three requirements",
		 "text": "• Revisit: see each flood-prone area at least every %d days (floods move fast).\n• Data: deliver %.1f GB of useful images to Earth per day.\n• Lifetime: keep working for %d years.\n\nYour score depends on meeting all three. Press E to close the screen." % [req["max_revisit_days"], req["min_data_delivered"], req["min_lifetime"]],
		 "todo": "Close the screen (E)", "until": "close"},
		{"title": "The parts shelves",
		 "text": "The shelves hold real spacecraft parts: cameras, solar panels, batteries, radios, computers, pointing systems and thrusters.\n\nLook at any part to read its specs. Every part costs mass (kg), power (W) and money ($M).",
		 "todo": "Look at a part on a shelf", "until": "focus_part", "target": "shelf"},
		{"title": "Installing a part",
		 "text": "Every slot is a DECISION between a simple and an advanced option. Your CubeSat starts with the simple one in every slot.\n\nThe DECISION card on the left shows the consequences before you commit: what changes, and which checks it fixes or breaks. Every check has a warning level: green NOMINAL, amber CAUTION (no safety margin), red WARNING (the mission will suffer), flashing red CRITICAL (launch blocked). The light at the bottom right shows the worst one.\n\nPress E to install the part you are looking at.",
		 "todo": "Install any part (E)", "until": "pick", "target": "shelf"},
		{"title": "Watch your resources",
		 "text": "Every choice changes your budgets. The RESOURCES screen in the middle of the front wall adds them up live.\n\nOpen it.",
		 "todo": "Open the Resources screen (E)", "until": "open:Resources", "target": "Resources"},
		{"title": "Power and eclipse",
		 "text": "Solar panels only work in sunlight. In your orbit Earth blocks the Sun for about %d of every %d minutes: that's eclipse. During eclipse the battery runs everything, and only about 60%% of it can be used safely.\n\nIf the average power made is less than what the parts use, the battery drains and the CubeSat goes into safe mode.\n\nPress Enter to continue." % [int(_o("eclipse_min")), int(_o("period_min"))],
		 "until": "next"},
		{"title": "Where your data goes",
		 "text": "Your camera makes %.2f GB of images a day. The radio can send %.2f GB/day, because it only talks to the ground station for about %d minutes a day:\nGB/day = Mbps x contact minutes x 60 / 8000.\n\nBut basic pointing keeps only %d%% of images sharp, so just %.2f GB/day of USEFUL data arrives. You need %.1f.\n\nPress E to close the screen." % [_x("data_gen"), _x("downlink"), int(_o("contact_min_per_day")), int(100 * _x("pointing")), _x("useful_per_day"), req["min_data_delivered"]],
		 "todo": "Close the screen (E)", "until": "close"},
		{"title": "Decision: pointing",
		 "text": "Go to the POINTING shelf (follow the arrow) and look at the precision attitude control. Read its DECISION card: it fixes the data requirement, but costs power and mass.\n\nEvery fix in this game has a price. Your job is to find the set of decisions that meets all three requirements within your power, mass and budget.",
		 "todo": "Install precision pointing", "until": "adcs", "target": "adcs"},
		{"title": "Listen to your advisors",
		 "text": "The ADVISORS screen on the right of the front wall is your engineering team. They warn you about anything that will break: not enough power, too heavy, over budget, data stuck on board.\n\nOpen it and read what they say.",
		 "todo": "Open the Advisors screen (E)", "until": "open:Advisors", "target": "Advisors"},
		{"title": "Fix the warnings",
		 "text": "Use the warnings to improve your design. Typical fixes:\n• Revisit too slow: a different orbit (at the console).\n• Power short: the deployable solar array.\n• Battery runs out in eclipse: the bigger battery.\n• Data piling up: a faster radio.\n\nWhen you're ready, close the screen and walk to the MISSION CONSOLE on the right-hand wall.",
		 "todo": "Open the Mission Console (E)", "until": "open:Mission Console", "target": "Mission Console"},
		{"title": "Orbit, rocket, launch",
		 "text": "Here you choose the orbit and the rocket. Under each choice the console shows what switching would do (IF ... → consequences).\n\n%s\n\nWatch the rocket price against your $%s M budget, set the lifetime, then click LAUNCH." % [_orbit_lines(), str(m["budget"])],
		 "todo": "Click LAUNCH", "until": "launch"},
		{"title": "Liftoff!",
		 "text": "You're in Mission Control. The big screen shows your CubeSat circling Earth. The game now flies your mission day by day, with real problems like solar storms and ground station outages.\n\nOpen the ORBIT & TRAJECTORY MONITOR on the left to see the live telemetry.",
		 "todo": "Open the Orbit & Trajectory Monitor (E)", "until": "open_or_done:Orbit & Trajectory Monitor", "target": "Orbit & Trajectory Monitor", "id": "ops"},
		{"title": "Reading the telemetry",
		 "text": "• Map: the line is your ground track. Blue circles are ground stations; data only goes down while you're inside one.\n• Ground Station Passes: when the next contact is.\n• Solar card: daylight or eclipse, and battery charge.\n• Delta-V card: thruster fuel, or orbit decay if you have none.\n\nUse Speed 10x or Skip to end to finish the mission.",
		 "todo": "Wait for the mission to end", "until": "finished"},
		{"title": "Your mission report",
		 "text": "Look at the big screen and press E to read the report in full view. Your score is out of 1000:\n• Requirements met: 350\n• Data delivered: 300\n• Efficiency (cost and mass): 200\n• Survival: 150\n\nRead the WHY lines: they explain exactly what went wrong and how to fix it. Real engineers iterate too.\n\nPress Enter.",
		 "until": "next", "id": "results"},
		{"title": "Now it's your mission",
		 "text": "Click 'Redesign' on the report (or walk back to the lab), change your parts and orbit, and launch again. Aim for 900 or more: Outstanding.\n\nPress T any time to bring me back with a quick reference. Good luck, engineer!",
		 "until": "next"},
	]

# ======================================================================= UI
func _build_ui() -> void:
	_panel = PanelContainer.new()
	var s := FUI.box(Color(0.03, 0.06, 0.12, 0.93), Color(FUI.AMBER, 0.55), 10, 14)
	s.border_width_left = 4
	_panel.add_theme_stylebox_override("panel", s)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var v := FUI.vb(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	var head := FUI.hb(8)
	head.add_child(FUI.t("TUTOR", 12, FUI.AMBER, "mono_semi"))
	head.add_child(FUI.grow())
	_step_lbl = FUI.t("", 12, FUI.DIM, "mono")
	head.add_child(_step_lbl)
	v.add_child(head)
	_title = FUI.t("", 20, FUI.WHITE, "sans_semi")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_body = FUI.t("", 15, FUI.TEXT2)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_body)
	_todo = FUI.t("", 14, FUI.GREEN, "sans_semi")
	_todo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_todo)
	_keys = FUI.t("", 12, FUI.DIM, "mono")
	v.add_child(_keys)

	_concept = PanelContainer.new()
	_concept.add_theme_stylebox_override("panel", FUI.box(Color(0.03, 0.08, 0.12, 0.93), Color(FUI.SKY, 0.5), 10, 12))
	_concept.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_concept)
	var cv := FUI.vb(4)
	_concept.add_child(cv)
	_concept_title = FUI.t("", 13, FUI.SKY, "mono_semi")
	cv.add_child(_concept_title)
	_concept_body = FUI.t("", 14, FUI.TEXT2)
	_concept_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_concept_body)
	_concept.visible = false
	_layout()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := 420.0 if _compact else 440.0
	_panel.custom_minimum_size = Vector2(w, 0)
	for l in [_title, _body, _todo, _concept_body]:
		l.custom_minimum_size = Vector2(w - 34, 0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	if _compact:
		_panel.position = Vector2(vp.x - w - 20, 50)
	else:
		_panel.position = Vector2(vp.x - w - 16, 16)
	_concept.custom_minimum_size = Vector2(w, 0)
	_concept.size = Vector2(w, 0)
	_concept.reset_size()
	_concept.position = Vector2(_panel.position.x, _panel.position.y + _panel.size.y + 10)

## Used by the full-view screen to leave room for the tutor on the right.
func is_showing() -> bool:
	return _panel.visible

func _show_step() -> void:
	_flags.clear()
	var done: bool = MissionState.tutor_done or MissionState.tutor_step >= STEPS.size()
	if done:
		MissionState.tutor_done = true
		_step_lbl.text = ""
		_title.text = "Quick reference"
		_body.text = "• Requirements: Briefing screen.\n• Budgets: Resources screen.\n• Problems: Advisors screen.\n• Data per day = Mbps x contact minutes x 60 / 8000.\n• Eclipse ~34 min per orbit: battery must cover it.\n• Look at a part to see its DECISION card before installing.\n• The console shows what each orbit and rocket would change.\n• Read the WHY lines after every mission."
		_todo.text = ""
		_keys.text = "[T] hide"
		_arrow.visible = false
	else:
		var st: Dictionary = STEPS[MissionState.tutor_step]
		_step_lbl.text = "STEP %d / %d" % [MissionState.tutor_step + 1, STEPS.size()]
		_title.text = st["title"]
		_body.text = st["text"]
		_todo.text = ("▶ " + st["todo"]) if st.has("todo") else ""
		_todo.visible = st.has("todo")
		_keys.text = ("[Enter] next   [T] hide" if st["until"] == "next" else "[T] hide   [Backspace] skip tutor")
		if st["until"] == "next":
			_keys.text += "   [Backspace] skip tutor"
	_panel.visible = not _hidden
	_layout()
	_layout.call_deferred()

func _advance() -> void:
	MissionState.tutor_step += 1
	if MissionState.tutor_step >= STEPS.size():
		MissionState.tutor_done = true
		_hidden = true
	_show_step()

func _jump_to(id: String) -> void:
	for i in STEPS.size():
		if STEPS[i].get("id", "") == id and MissionState.tutor_step < i:
			MissionState.tutor_step = i
			_show_step()
			return

# ======================================================================= events from the game
func on_screen_opened(name: String) -> void:
	_flags["open:" + name] = true
	_compact = true
	_layout()

func on_screen_closed() -> void:
	_flags["close"] = true
	_compact = false
	_layout()

func on_part_focus(category: String) -> void:
	_flags["focus_part"] = true
	if not _seen_cats.has(category) and not MissionState.tutor_done:
		_seen_cats[category] = true
		_show_concept(category)

func on_event(ev: String) -> void:
	_flags[ev] = true
	if ev == "launch":
		_jump_to("ops")
	elif ev == "finished":
		_jump_to("results")

const CONCEPTS := {
	"payload": ["PAYLOAD", "The instrument that does the mission, here a camera. Resolution is the smallest thing it can see: you need 10 m or better. Sharper images are bigger files to send home."],
	"solar": ["SOLAR POWER", "Panels make power only in sunlight. Averaged over an orbit you get about 63% of their rated power, because of eclipse."],
	"battery": ["BATTERY", "Runs the CubeSat during eclipse, about a third of every orbit. Only about 60% of the capacity is used, to keep the battery healthy for years."],
	"comms": ["RADIO (DOWNLINK)", "Sends images to Earth only while a ground station is in view, about 30-50 minutes a day. Faster radio = more data, but more power while transmitting."],
	"computer": ["COMPUTER & STORAGE", "Runs the spacecraft and stores images between ground passes. If storage fills up, new images are lost."],
	"adcs": ["ATTITUDE CONTROL (ADCS)", "Points the camera at the ground. Rough pointing blurs many images. Precise pointing (reaction wheels + star tracker) can also tilt sideways to revisit sooner."],
	"thermal": ["THERMAL CONTROL", "Space swings from hot sunlight to freezing shadow every orbit. Blankets and radiators need no power; heaters keep the battery warm but use power."],
	"propulsion": ["PROPULSION", "A thruster changes or holds the orbit. In these orbits the CubeSat stays up for 10+ years anyway, so ask: is it worth the mass, power and money?"],
}

func _show_concept(cat: String) -> void:
	if not CONCEPTS.has(cat):
		return
	_concept_title.text = "CONCEPT · " + CONCEPTS[cat][0]
	_concept_body.text = CONCEPTS[cat][1]
	_concept_time = 12.0
	_concept.visible = not _hidden
	_layout()

# ======================================================================= per frame
func _process(delta: float) -> void:
	if _concept_time > 0.0:
		_concept_time -= delta
		_concept.modulate.a = clampf(_concept_time / 0.6, 0.0, 1.0)
		if _concept_time <= 0.0:
			_concept.visible = false
	if MissionState.tutor_done or MissionState.tutor_step >= STEPS.size():
		_arrow.visible = false
		return
	var st: Dictionary = STEPS[MissionState.tutor_step]
	if _check(st["until"]):
		_advance()
		return
	_update_arrow(st, delta)

func _check(until: String) -> bool:
	match until:
		"next":
			return false
		"move":
			return lab.player.global_position.distance_to(_start_pos) > 2.0
		"close":
			return not _sv_open()
		"focus_part", "pick", "launch", "finished":
			return _flags.get(until, false)
		"adcs":
			return MissionState.part_of("adcs").get("tier", "") == "advanced"
	if until.begins_with("open_or_done:"):
		return _flags.get("open:" + until.substr(13), false) or _flags.get("finished", false)
	if until.begins_with("open:"):
		return _flags.get(until, false)
	return false

func _update_arrow(st: Dictionary, delta: float) -> void:
	var target: String = st.get("target", "")
	var sv_open := _sv_open()
	if target == "" or sv_open or _hidden:
		_arrow.visible = false
		return
	var pos = null
	if target == "shelf" or target == "adcs":
		var best := INF
		for n in lab.find_children("*", "StaticBody3D", true, false):
			if "part_id" in n and (target == "shelf" or n.category == "adcs" and GameData.part("adcs", n.part_id).get("tier", "") == "advanced"):
				var d: float = n.global_position.distance_to(lab.player.global_position)
				if d < best:
					best = d
					pos = n.global_position + Vector3(0, 1.4, 0)
	else:
		for n in lab.find_children("*", "StaticBody3D", true, false):
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

# ======================================================================= keys
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if get_tree().paused:
		return
	match event.keycode:
		KEY_T:
			_hidden = not _hidden
			if not _hidden and MissionState.tutor_done:
				_show_step()
			_panel.visible = not _hidden
			_concept.visible = not _hidden and _concept_time > 0.0
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _hidden or MissionState.tutor_done:
				return
			if STEPS[MissionState.tutor_step]["until"] == "next":
				_advance()
				get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			if not MissionState.tutor_done and not _hidden:
				MissionState.tutor_done = true
				_hidden = true
				_show_step()
				get_tree().call_group("hud", "show_message", "Tutor off. Press T any time for a quick reference.", 4.0)
				get_viewport().set_input_as_handled()
