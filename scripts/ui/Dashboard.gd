extends VBoxContainer
## Live resource bars. Green = 20%+ spare, yellow = tight, red = over the limit.

const ALL := ["mass", "fuel", "power", "battery", "budget", "data", "comms", "time"]
var ORDER: Array = []
var _rows: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 4 if MissionState.has_fuel_system() else 6)
	add_child(UI.label("RESOURCES", 14, UI.COLOR_ACCENT))
	var c := MissionState.compute()
	for key in ALL:
		if c.has(key):
			ORDER.append(key)
	for key in ORDER:
		var name_l := UI.label("", 14)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = 1.0
		bar.step = 0.001
		var value_l := UI.label("", 13, UI.COLOR_MUTED)
		add_child(name_l)
		add_child(bar)
		add_child(value_l)
		_rows[key] = [name_l, bar, value_l]
	MissionState.design_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	var c := MissionState.compute()
	for key in ORDER:
		if not c.has(key):
			continue
		var r: Dictionary = c[key]
		var row: Array = _rows[key]
		var used: float = r["used"]
		var limit: float = r["limit"]
		row[0].text = r["label"]
		var fill := 1.0
		if limit > 0.0:
			fill = used / limit
		row[1].value = clampf(fill, 0.0, 1.0)
		var style := StyleBoxFlat.new()
		style.bg_color = UI.margin_color(r["margin"])
		style.set_corner_radius_all(4)
		row[1].add_theme_stylebox_override("fill", style)
		row[2].text = "%s / %s %s" % [_fmt(used), _fmt(limit), r["unit"]]

func _fmt(v: float) -> String:
	if absf(v) < 1.0:
		return "%.2f" % v
	return "%.1f" % v
