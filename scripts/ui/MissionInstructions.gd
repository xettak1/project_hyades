extends CanvasLayer
## MISSION INSTRUCTIONS, fixed on the RIGHT in every level. Answers "what am I supposed to do right now?"
##   MISSION OBJECTIVE  - one line
##   YOUR TASK          - the task just finished (✓), the current one (▶) and the next one (dim)
##   PROGRESS           - n / N tasks, with a segmented bar
## Tasks are revealed one at a time and tick themselves off from the real game state
## (the level room, MissionState, and events forwarded by the TutorDialogueManager).
## Press O (or click the title) to collapse.

const WIDTH := 300.0

var room: Node                  # the level room
var level := "launch"
var objective := ""
var tasks: Array = []           # [{text, done: Callable, sticky: bool}]
var _done: Dictionary = {}      # index -> true for tasks completed (sticky ones stay done)
var _flags: Dictionary = {}
var _panel: PanelContainer
var _body: VBoxContainer
var _list: VBoxContainer
var _obj: Label
var _prog: Label
var _bar: Control
var _arrow: Label
var _collapsed := false
var _last_sig := ""
var _poll := 0.0

func _ready() -> void:
	layer = 4
	add_to_group("instructions")
	add_to_group("decision")          # the full-screen view keeps clear of the right column
	level = LevelFlow.current_id() if LevelFlow.index >= 0 else "launch"
	_define()
	_panel = PanelContainer.new()
	var s := FUI.box(Color(0.025, 0.05, 0.1, 0.92), Color(FUI.SKY, 0.35), 10, 12)
	s.border_width_left = 3
	_panel.add_theme_stylebox_override("panel", s)
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel)
	var v := FUI.vb(8)
	_panel.add_child(v)
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.pressed.connect(toggle)
	head.custom_minimum_size = Vector2(0, 20)
	var hv := FUI.hb(6)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.set_anchors_preset(Control.PRESET_FULL_RECT)
	hv.add_child(FUI.t("MISSION OBJECTIVE", 12, FUI.SKY, "mono_semi"))
	hv.add_child(FUI.grow())
	_arrow = FUI.t("O ▾", 10, FUI.DIM, "mono")
	hv.add_child(_arrow)
	head.add_child(hv)
	v.add_child(head)
	_body = FUI.vb(8)
	v.add_child(_body)
	_obj = FUI.t(objective, 17, FUI.WHITE, "sans_semi")
	_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj.custom_minimum_size = Vector2(WIDTH - 30, 0)
	_body.add_child(_obj)
	_body.add_child(FUI.hline())
	_body.add_child(FUI.t("YOUR TASK", 11, FUI.MUTED, "mono_semi"))
	_list = FUI.vb(6)
	_body.add_child(_list)
	var pr := FUI.hb(8)
	_prog = FUI.t("", 12, FUI.MUTED, "mono_semi")
	pr.add_child(_prog)
	_bar = _Segments.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(_bar)
	_body.add_child(pr)
	_refresh(true)

# ======================================================================= the tasks of each level
func _t(text: String, done: Callable, sticky := true) -> Dictionary:
	return {"text": text, "done": done, "sticky": sticky}

func _flag(name: String) -> Callable:
	return func(): return _flags.get(name, false)

func _check_ok(id: String) -> Callable:
	return func():
		for r in MissionState.assess():
			if r["id"] == id:
				return r["level"] < 2
		return true

func _define() -> void:
	match level:
		"launch":
			objective = "Prepare the satellite for launch."
			tasks = [
				_t("Look at a part on the shelves", _flag("focus_part")),
				_t("Install a part with E", _flag("pick")),
				_t("Open the Mission Console to pick an orbit and rocket", _flag("open:Mission Console")),
				_t("Keep the mass within the rocket's limit", _check_ok("rocket_used"), false),
				_t("Stay within the budget", _check_ok("budget_used"), false),
				_t("Press LAUNCH", _flag("launch")),
			]
		"space":
			objective = "Photograph the farmland from orbit."
			tasks = [
				_t("Open the Observation Console (E)", _flag("open:Observation Console")),
				_t("Select a region marked IN VIEW", func(): return room != null and str(room.get("selected")) != ""),
				_t("Scan it and watch the camera", func(): return room != null and int(room.get("scans_done")) >= 1),
				_t("Photograph more regions (aim for all 4)", func(): return room != null and (room.scanned.size() >= 3 or int(room.get("passes_left")) <= 0)),
				_t("Press END OBSERVATION CAMPAIGN", _flag("level_done")),
			]
		"ground":
			objective = "Bring the pictures home to Earth."
			tasks = [
				_t("Choose what comes down first (PRIORITY buttons)", func(): return _flags.get("priority_floods", false) or _flags.get("priority_crops", false)),
				_t("Press START PASS", func(): return room != null and (room.passing or room.finished)),
				_t("Watch the link until the pass ends", func(): return room != null and room.finished),
			]
		"user":
			objective = "Warn the farmers in time."
			tasks = [
				_t("Open the Analysis Workstation (E)", _flag("open:Analysis Workstation")),
				_t("Click every flooded (blue) plot", func(): return room != null and room.marked_count() >= 1),
				_t("Choose how to tell people", func(): return room != null and room.product != ""),
				_t("Press DELIVER REPORT", func(): return room != null and room.delivered),
			]

# ======================================================================= events (forwarded by the tutor)
func on_event(ev: String) -> void:
	_flags[ev] = true
	_refresh()

func on_screen_opened(name: String) -> void:
	_flags["open:" + name] = true
	_refresh()

func on_part_focus(_category: String) -> void:
	_flags["focus_part"] = true
	_refresh()

func on_pick() -> void:
	_flags["pick"] = true
	_refresh()

# ======================================================================= state
## Index of the first task not yet done (tasks are done in order).
func current_index() -> int:
	for i in tasks.size():
		if not _is_done(i):
			return i
	return tasks.size()

func _is_done(i: int) -> bool:
	if _done.get(i, false):
		return true
	var ok: bool = tasks[i]["done"].call()
	if ok and tasks[i]["sticky"]:
		_done[i] = true
	return ok

## Tasks are done in order, so progress = how far along the list we are.
func done_count() -> int:
	return current_index()

func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp.x - _panel.size.x - 12, 56)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_refresh()

func _refresh(force := false) -> void:
	if _list == null:
		return
	var cur := current_index()
	var n := done_count()
	var sig := "%d/%d/%d" % [cur, n, tasks.size()]
	if sig == _last_sig and not force:
		return
	_last_sig = sig
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if cur >= tasks.size():
		_list.add_child(_row("✓", "All tasks done. Well done!", FUI.GREEN, true))
	else:
		if cur > 0:
			_list.add_child(_row("✓", tasks[cur - 1]["text"], Color(FUI.GREEN, 0.75), false))
		_list.add_child(_row("▶", tasks[cur]["text"], FUI.WHITE, true))
		if cur + 1 < tasks.size():
			_list.add_child(_row("○", tasks[cur + 1]["text"], FUI.DIM, false))
	_prog.text = "PROGRESS  %d / %d" % [n, tasks.size()]
	_prog.add_theme_color_override("font_color", FUI.GREEN if n == tasks.size() else FUI.MUTED)
	_bar.total = tasks.size()
	_bar.done = n
	_bar.queue_redraw()
	_panel.size = Vector2.ZERO
	_panel.reset_size.call_deferred()

func _row(icon: String, text: String, color: Color, strong: bool) -> Control:
	var h := FUI.hb(8)
	var ic := FUI.t(icon, 14, color, "sans_semi")
	ic.custom_minimum_size = Vector2(16, 0)
	h.add_child(ic)
	var l := FUI.t(text, 15 if strong else 13, color, "sans_semi" if strong else "sans")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 60, 0)
	h.add_child(l)
	if strong and icon == "▶":
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", FUI.box(Color(FUI.SKY, 0.1), Color(FUI.SKY, 0.45), 6, 6))
		p.add_child(h)
		return p
	return h

func toggle() -> void:
	_collapsed = not _collapsed
	_body.visible = not _collapsed
	_arrow.text = "O ▸" if _collapsed else "O ▾"
	_panel.size = Vector2.ZERO
	_panel.reset_size.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O and not get_tree().paused:
		toggle()

## Used by the full-screen view and the Decision card to stay clear of this panel.
func is_showing() -> bool:
	return visible and _panel.visible

func width() -> float:
	return _panel.size.x

func bottom() -> float:
	return _panel.position.y + _panel.size.y

class _Segments extends Control:
	var total := 1
	var done := 0
	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (total - 1)) / maxf(total, 1)
		for i in total:
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), FUI.GREEN if i < done else Color(1, 1, 1, 0.12))
