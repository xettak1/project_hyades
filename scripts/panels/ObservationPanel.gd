extends VBoxContainer
## OBSERVATION CONSOLE (Level 2): pick a farming region that is in view, then scan it.
## Shows which regions are below the satellite right now, cloud cover, passes left and storage.

var room   # SpaceSegment
var _rows: Dictionary = {}
var _status: Label
var _sel: Label
var _scan: Button
var _data: Label
var _t := 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(FUI.t("OBSERVATION CONSOLE", 15, FUI.SKY, "mono_semi"))
	_status = FUI.t("", 15, FUI.TEXT2, "mono")
	add_child(_status)
	add_child(FUI.hline())
	for r in FarmRegions.REGIONS:
		var row := FUI.hb(10)
		var b := _btn("SELECT", FUI.SKY)
		b.pressed.connect(room.select_region.bind(r["id"]))
		row.add_child(b)
		var v := FUI.vb(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(FUI.t("%s · %s" % [r["name"], r["country"]], 17, FUI.WHITE, "sans_semi"))
		v.add_child(FUI.t("Crops: %s  ·  Risk: %s" % [r["crops"], r["risk"]], 12, FUI.MUTED))
		row.add_child(v)
		var st := FUI.t("", 14, FUI.MUTED, "mono_semi")
		st.custom_minimum_size = Vector2(250, 0)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(st)
		add_child(row)
		_rows[r["id"]] = [b, st]
	add_child(FUI.hline())
	_sel = FUI.t("", 16, FUI.AMBER, "sans_semi")
	_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sel)
	var bh := FUI.hb(12)
	_scan = _btn("  SCAN SELECTED REGION  ", FUI.GREEN, 20)
	_scan.pressed.connect(room.scan)
	bh.add_child(_scan)
	bh.add_child(FUI.grow())
	var end := _btn("END OBSERVATION CAMPAIGN", FUI.AMBER, 15)
	end.pressed.connect(room.end_campaign)
	bh.add_child(end)
	add_child(bh)
	_data = FUI.t("", 14, FUI.TEXT, "mono")
	_data.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_data)
	refresh()

func _btn(text: String, c: Color, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FUI.font("JetBrainsMono-SemiBold"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_disabled_color", FUI.FAINT)
	b.add_theme_stylebox_override("normal", FUI.box(Color(c, 0.08), Color(c, 0.5), 6, 8))
	b.add_theme_stylebox_override("hover", FUI.box(Color(c, 0.2), c, 6, 8))
	b.add_theme_stylebox_override("pressed", FUI.box(Color(c, 0.3), c, 6, 8))
	b.add_theme_stylebox_override("disabled", FUI.box(Color(0, 0, 0, 0.2), FUI.BORDER, 6, 8))
	return b

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.2:
		_t = 0.0
		refresh()

func refresh() -> void:
	if room == null:
		return
	_status.text = "Day %d of %d  ·  passes left %d of %d  ·  %s" % [room.day, room.CAMPAIGN_DAYS, room.passes_left, room.passes_total,
		"FAST-FORWARD to next pass over Africa" if room.fast else "AFRICA IN VIEW"]
	for r in FarmRegions.REGIONS:
		var id: String = r["id"]
		var w: Array = _rows[id]
		var vis: bool = room.in_view(id)
		var cloud: float = room.cloud_now(id)
		var shots: int = room.scanned.get(id, 0)
		var txt := ("IN VIEW" if vis else "below horizon") + ("  ·  cloud %d%%" % int(cloud * 100) if vis else "") + ("  ·  ✓ %d" % shots if shots > 0 else "")
		w[1].text = txt
		w[1].add_theme_color_override("font_color", (FUI.AMBER if cloud > room.CLOUD_LIMIT else FUI.GREEN) if vis else FUI.FAINT)
		w[0].text = "SELECTED" if room.selected == id else "SELECT"
	var sr := FarmRegions.region(room.selected)
	if sr.is_empty():
		_sel.text = "Select a region that is IN VIEW, then scan it."
	else:
		var why: String = room.scan_blocker()
		_sel.text = "%s: %s" % [sr["name"], why if why != "" else "ready to scan (%.1f GB per pass)" % room.per_pass_gb()]
	_scan.disabled = room.scan_blocker() != "" or room.scanning
	_data.text = "Collected %.1f GB  ·  useful %.1f GB  ·  memory %.1f / %.0f GB%s" % [room.collected_gb, room.useful_gb, room.stored_gb, room.storage_gb,
		("  ·  LOST %.1f GB (memory full)" % room.overflow_gb) if room.overflow_gb > 0.0 else ""]
