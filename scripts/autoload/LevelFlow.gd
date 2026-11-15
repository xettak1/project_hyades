extends CanvasLayer
## LEVEL FLOW: the four mission segments in order, and the transitions between them.
##   Briefing (title screen) -> 1 Launch -> 2 Space -> 3 Ground -> 4 User -> Mission results
## Each level stores what it achieved in MissionState.level_results[<level id>] when it ends;
## later levels read those results, so decisions carry through the whole mission.

const LEVELS := [
	{"id": "launch", "n": 1, "title": "LAUNCH SEGMENT", "goal": "Get the mission into space", "scene": "res://scenes/Lab.tscn", "where": "LAUNCH CONTROL CENTRE · COASTAL LAUNCH SITE, EARTH",
		"intro": "Build your CubeSat, choose the rocket and orbit, and launch."},
	{"id": "space", "n": 2, "title": "SPACE SEGMENT", "goal": "Observe the farmland", "scene": "res://scenes/SpaceSegment.tscn", "where": "ON BOARD THE SATELLITE · 700 KM ABOVE AFRICA",
		"intro": "Choose your instrument and how to use it. Power and storage are limited."},
	{"id": "ground", "n": 3, "title": "GROUND SEGMENT", "goal": "Get the data home", "scene": "res://scenes/GroundSegment.tscn", "where": "SATELLITE GROUND STATION · EARTH",
		"intro": "Collecting data is not the same as delivering it. Build the link to Earth."},
	{"id": "user", "n": 4, "title": "USER SEGMENT", "goal": "Turn data into action", "scene": "res://scenes/UserSegment.tscn", "where": "AGRICULTURAL ANALYSIS CENTRE · EARTH",
		"intro": "Interpret the imagery and warn the people who need it."},
]
const RESULTS_SCENE := "res://scenes/MissionResults.tscn"
const TITLE_SCENE := "res://scenes/Main.tscn"

var index := -1
var busy := false
var _fade: ColorRect
var _card: VBoxContainer
var _l_step: Label
var _l_title: Label
var _l_goal: Label
var _l_intro: Label
var _l_carry: Label
var _l_hint: Label
var _skip := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.015, 0.03, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 10)
	_card.custom_minimum_size = Vector2(760, 0)
	center.add_child(_card)
	_l_step = _lab(18, FUI.SKY, "mono_semi")
	_l_title = _lab(54, FUI.WHITE, "sans_semi")
	_l_goal = _lab(26, FUI.AMBER, "sans_med")
	_l_intro = _lab(19, FUI.TEXT2, "sans")
	_l_carry = _lab(15, FUI.MUTED, "mono")
	_l_hint = _lab(14, FUI.DIM, "mono")
	_card.visible = false

func _lab(size: int, color: Color, kind: String) -> Label:
	var l := FUI.t("", size, color, kind)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(l)
	return l

func current() -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]

func current_id() -> String:
	return current()["id"] if index >= 0 else ""

## Start the mission at Level 1 (called from the briefing).
func start() -> void:
	MissionState.level_results.clear()
	index = 0
	_go(current()["scene"], true)

## A level is finished: store its results and move on.
func complete(results: Dictionary) -> void:
	if busy:
		return
	MissionState.level_results[current_id()] = results
	index += 1
	if index >= LEVELS.size():
		SaveGame.clear_progress()
		_go(RESULTS_SCENE, false)
	else:
		_go(current()["scene"], true)

## Continue a saved mission at level i (see SaveGame).
func resume(i: int) -> void:
	index = clampi(i, 0, LEVELS.size() - 1)
	_go(current()["scene"], true)

func restart_level() -> void:
	if index >= 0:
		MissionState.level_results.erase(current_id())
		_go(current()["scene"], true)

func to_title() -> void:
	index = -1
	_go(TITLE_SCENE, false)

## What the new level inherits from the earlier ones, in one line.
func carry_line() -> String:
	var r: Dictionary = MissionState.level_results
	match current_id():
		"space":
			var l: Dictionary = r.get("launch", {})
			return "FROM LAUNCH:  %s on %s  ·  %.1f kg  ·  $%.2fM of budget left" % [l.get("orbit", "?"), l.get("rocket", "?"), l.get("mass_kg", 0.0), l.get("budget_left", 0.0)]
		"ground":
			var s: Dictionary = r.get("space", {})
			return "FROM ORBIT:  %.1f GB of imagery collected  ·  %.1f GB stored onboard  ·  %d of 4 regions photographed" % [s.get("collected_gb", 0.0), s.get("stored_gb", 0.0), s.get("scanned", []).size()]
		"user":
			var g: Dictionary = r.get("ground", {})
			return "FROM THE GROUND STATIONS:  %.1f GB received  ·  %.1f GB never reached Earth  ·  %.1f days delay" % [g.get("received_gb", 0.0), g.get("lost_gb", 0.0), g.get("delay_days", 0.0)]
	return ""

func _input(event: InputEvent) -> void:
	if not _card.visible:
		return
	if (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]) \
			or (event is InputEventMouseButton and event.pressed):
		_skip = true
		get_viewport().set_input_as_handled()

func _go(scene: String, show_card: bool) -> void:
	busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.45)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)
	if show_card:
		SaveGame.save_progress(index)
		var lv := current()
		_l_step.text = "LEVEL %d OF %d  ·  %s" % [lv["n"], LEVELS.size(), lv.get("where", "")]
		_l_title.text = lv["title"]
		_l_goal.text = lv["goal"]
		_l_intro.text = lv["intro"]
		_l_carry.text = carry_line()
		_l_carry.visible = _l_carry.text != ""
		_l_hint.text = "click or press Enter to begin"
		_card.visible = true
		_card.modulate.a = 0.0
		var tc := create_tween()
		tc.tween_property(_card, "modulate:a", 1.0, 0.4)
		_skip = false
		var t := 0.0
		while t < 4.5 and not _skip:
			await get_tree().process_frame
			t += get_process_delta_time()
		var tc2 := create_tween()
		tc2.tween_property(_card, "modulate:a", 0.0, 0.3)
		await tc2.finished
		_card.visible = false
	else:
		await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.6)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
