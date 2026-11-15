extends VBoxContainer
## ANALYSIS WORKSTATION (Level 4): the satellite imagery of all 24 farm plots.
## Coloured plots are what the satellite saw (green healthy, yellow stressed, blue flooded);
## grey plots have no usable imagery (not photographed in Level 2, or the data never reached
## Earth in Level 3). Click plots to mark them as FLOODED, choose how to tell people, and deliver.

var room   # UserSegment
var _grid: GridContainer
var _btns: Dictionary = {}
var _info: Label
var _prod: Dictionary = {}
var _summary: Label

const PRODUCTS := [["alert", "EMERGENCY FLOOD ALERT"], ["map", "FLOOD RISK MAP"], ["report", "CROP HEALTH REPORT"], ["dashboard", "MONITORING DASHBOARD"]]

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(FUI.t("SATELLITE IMAGERY ANALYSIS", 15, FUI.AMBER, "mono_semi"))
	var help := FUI.t("Click a plot to mark it FLOODED. Grey = no imagery: we cannot know what is happening there.", 14, FUI.TEXT2)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var row := FUI.hb(16)
	add_child(row)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	row.add_child(_grid)
	for p in room.plots:
		var b := Button.new()
		b.custom_minimum_size = Vector2(92, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", FUI.font("JetBrainsMono-SemiBold"))
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(room.toggle_mark.bind(p["id"]))
		b.mouse_entered.connect(_show_info.bind(p["id"]))
		_grid.add_child(b)
		_btns[p["id"]] = b
	var side := FUI.vb(8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	for i in FarmRegions.REGIONS.size():
		var r: Dictionary = FarmRegions.REGIONS[i]
		side.add_child(FUI.t("Row %s: %s (%s)" % [char(65 + i), r["name"], r["country"]], 13, FUI.MUTED))
	side.add_child(FUI.hline())
	_info = FUI.t("Point at a plot to see its imagery.", 14, FUI.TEXT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_info)
	add_child(FUI.hline())
	add_child(FUI.t("HOW SHOULD WE TELL PEOPLE?", 13, FUI.AMBER, "mono_semi"))
	var pr := FUI.hb(8)
	for p in PRODUCTS:
		var b := _btn(p[1], FUI.SKY)
		b.pressed.connect(room.set_product.bind(p[0]))
		pr.add_child(b)
		_prod[p[0]] = b
	add_child(pr)
	var bot := FUI.hb(12)
	_summary = FUI.t("", 14, FUI.TEXT2, "mono")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(_summary)
	var go := _btn("  DELIVER REPORT  ", FUI.GREEN, 18)
	go.pressed.connect(room.deliver)
	bot.add_child(go)
	add_child(bot)
	refresh()

func _btn(text: String, c: Color, size := 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FUI.font("JetBrainsMono-SemiBold"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", c)
	b.add_theme_stylebox_override("normal", FUI.box(Color(c, 0.08), Color(c, 0.45), 6, 8))
	b.add_theme_stylebox_override("hover", FUI.box(Color(c, 0.2), c, 6, 8))
	b.add_theme_stylebox_override("pressed", FUI.box(Color(c, 0.35), c, 6, 8))
	return b

func _show_info(id: String) -> void:
	for p in room.plots:
		if p["id"] == id:
			var r := FarmRegions.region(p["region"])
			if not p["seen"]:
				_info.text = "%s · %s\nNO IMAGERY. %s" % [id, r["name"], room.why_missing(p)]
			else:
				_info.text = "%s · %s\nImagery shows: %s%s" % [id, r["name"], {"healthy": "healthy green crops", "stressed": "crops under stress (yellowing)", "flooded": "standing water over the field", "waterlogged": "waterlogged, soggy soil"}[p["state"]], "\nMARKED AS FLOODED" if p["marked"] else ""]

func refresh() -> void:
	for p in room.plots:
		var b: Button = _btns[p["id"]]
		var c: Color = FarmRegions.COLORS[p["state"]] if p["seen"] else FarmRegions.COLORS["none"]
		b.text = p["id"] + ("\n⚑ FLOOD" if p["marked"] else ("" if p["seen"] else "\nno data"))
		b.add_theme_color_override("font_color", Color.WHITE)
		var st := FUI.box(c.darkened(0.15), FUI.WHITE if p["marked"] else c.darkened(0.4), 6, 4)
		st.set_border_width_all(4 if p["marked"] else 1)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", FUI.box(c, FUI.WHITE, 6, 4))
	for k in _prod:
		_prod[k].add_theme_stylebox_override("normal", FUI.box(Color(FUI.SKY, 0.35 if room.product == k else 0.08), FUI.SKY if room.product == k else Color(FUI.SKY, 0.45), 6, 8))
	_summary.text = "Marked %d plots as flooded  ·  product: %s  ·  data delay %.1f days" % [room.marked_count(), room.product.to_upper() if room.product != "" else "not chosen", room.delay_days]
