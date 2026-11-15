extends CanvasLayer
## MISSION CONTROL CONSOLE strip, top centre of the screen in every level.
## Shows only the numbers that matter for the current level, live.
## Levels can publish in-level numbers in MissionState.live (e.g. data collected so far).

var _level: Label
var _status: Label
var _cells: Array = []
var _t := 0.0

func _ready() -> void:
	layer = 3
	add_to_group("console_strip")
	var p := PanelContainer.new()
	var s := FUI.box(Color(0.03, 0.06, 0.12, 0.9), Color(FUI.SKY, 0.35), 8, 8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.custom_minimum_size = Vector2(372, 0)
	p.position = Vector2(-186, 8)
	add_child(p)
	var v := FUI.vb(4)
	p.add_child(v)
	var head := FUI.hb(6)
	_level = FUI.t("", 11, FUI.SKY, "mono_semi")
	head.add_child(_level)
	head.add_child(FUI.grow())
	_status = FUI.t("", 11, FUI.GREEN, "mono_semi")
	head.add_child(_status)
	v.add_child(head)
	var row := FUI.hb(4)
	v.add_child(row)
	for i in 4:
		var c := FUI.vb(0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap := FUI.t("", 9, FUI.DIM, "mono")
		var val := FUI.t("", 13, FUI.WHITE, "mono_semi")
		c.add_child(cap)
		c.add_child(val)
		row.add_child(c)
		_cells.append([c, cap, val])
	_refresh()

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.25:
		_t = 0.0
		_refresh()

func _cell(i: int, cap: String, val: String, color: Color = FUI.WHITE) -> void:
	_cells[i][0].visible = true
	_cells[i][1].text = cap
	_cells[i][2].text = val
	_cells[i][2].add_theme_color_override("font_color", color)

func _refresh() -> void:
	for c in _cells:
		c[0].visible = false
	var id := LevelFlow.current_id() if LevelFlow.index >= 0 else "launch"
	var lv: Dictionary = LevelFlow.current() if LevelFlow.index >= 0 else LevelFlow.LEVELS[0]
	_level.text = "MISSION CONTROL · L%d %s" % [lv["n"], lv["title"]]
	var x: Dictionary = MissionState.compute()["extra"]
	var m := MissionState.mission()
	var live: Dictionary = MissionState.live
	var r: Dictionary = MissionState.level_results
	var rows := MissionState.assess(x)
	var worst := MissionState.worst_level(rows)
	match id:
		"launch":
			_cell(0, "BUDGET", "$%.2f/%sM" % [x["cost"], str(m["budget"])], _lvl(rows, "budget_used"))
			_cell(1, "MASS", "%.1f/%s kg" % [x["mass"], str(m["mass_limit"])], _lvl(rows, "mass_used"))
			_cell(2, "POWER", "%+.0f%%" % (100.0 * (x["gen_avg"] - x["load_w"]) / maxf(x["load_w"], 0.01)), _lvl(rows, "power_margin"))
			_cell(3, "ROCKET", MissionState.rocket()["name"].split(" ")[0], _lvl(rows, "rocket_used"))
		"space":
			_cell(0, "BUDGET LEFT", "$%.2fM" % r.get("launch", {}).get("budget_left", MissionState.budget_left()))
			_cell(1, "POWER", "%+.0f%%" % (100.0 * (x["gen_avg"] - x["load_w"]) / maxf(x["load_w"], 0.01)), _lvl(rows, "power_margin"))
			_cell(2, "STORAGE", "%.1f/%.0f GB" % [live.get("stored_gb", 0.0), x["storage"]])
			_cell(3, "COLLECTED", "%.1f GB" % live.get("collected_gb", 0.0), FUI.SKY)
		"ground":
			var sp: Dictionary = r.get("space", {})
			_cell(0, "ONBOARD", "%.1f GB" % live.get("onboard_gb", sp.get("stored_gb", 0.0)), FUI.AMBER)
			_cell(1, "TRANSMITTED", "%.1f GB" % live.get("transmitted_gb", 0.0), FUI.SKY)
			_cell(2, "RECEIVED", "%.1f GB" % live.get("received_gb", 0.0), FUI.GREEN)
			_cell(3, "BUDGET LEFT", "$%.2fM" % live.get("budget_left", r.get("launch", {}).get("budget_left", 0.0)))
		"user":
			var g: Dictionary = r.get("ground", {})
			_cell(0, "RECEIVED", "%.1f GB" % g.get("received_gb", 0.0), FUI.GREEN)
			_cell(1, "MISSING", "%.1f GB" % g.get("lost_gb", 0.0), FUI.RED if g.get("lost_gb", 0.0) > 0.0 else FUI.WHITE)
			_cell(2, "DELAY", "%.1f days" % g.get("delay_days", 0.0))
			_cell(3, "PLOTS DONE", "%d/%d" % [live.get("plots_done", 0), live.get("plots_total", 0)])
	if id == "launch":
		_status.text = "● " + MissionState.LEVEL_NAMES[worst]
		_status.add_theme_color_override("font_color", Consequences.level_color(worst))
	else:
		_status.text = "● " + str(live.get("status", "NOMINAL"))
		_status.add_theme_color_override("font_color", live.get("status_color", FUI.GREEN))

func _lvl(rows: Array, id: String) -> Color:
	for r in rows:
		if r["id"] == id:
			return Consequences.level_color(r["level"])
	return FUI.WHITE
