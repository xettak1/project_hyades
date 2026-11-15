extends VBoxContainer
## RESOURCES screen = threshold board. Every check from data/tables/thresholds.csv, live:
## value, a bar with the caution / warning / critical marks, and the warning level.
## Green NOMINAL, amber CAUTION, red WARNING, flashing red CRITICAL.

var _rows: Dictionary = {}
var _summary: Label
var _t := 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 3)
	var head := FUI.hb(8)
	head.add_child(FUI.t("SYSTEM MARGINS", 15, UI.COLOR_ACCENT, "sans_semi"))
	head.add_child(FUI.grow())
	_summary = FUI.t("", 12, FUI.MUTED, "mono_semi")
	head.add_child(_summary)
	add_child(head)
	for r in MissionState.assess():
		var line := FUI.hb(6)
		var dot := FUI.dot(FUI.GREEN, 8)
		line.add_child(dot)
		var name := FUI.t(r["label"], 12, FUI.TEXT2)
		name.clip_text = true
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		var val := FUI.t("", 12, FUI.WHITE, "mono_semi")
		line.add_child(val)
		var lvl := FUI.t("", 10, FUI.GREEN, "mono_semi")
		lvl.custom_minimum_size = Vector2(62, 0)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(lvl)
		add_child(line)
		var bar := _Bar.new()
		bar.custom_minimum_size = Vector2(0, 9)
		add_child(bar)
		_rows[r["id"]] = {"dot": dot, "val": val, "lvl": lvl, "bar": bar}
	add_child(FUI.t("Limits come from data/tables/thresholds.csv", 10, FUI.DIM))
	MissionState.design_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	var counts := [0, 0, 0, 0]
	for r in MissionState.assess():
		if not _rows.has(r["id"]):
			continue
		var w: Dictionary = _rows[r["id"]]
		var c := Consequences.level_color(r["level"])
		counts[r["level"]] += 1
		w["dot"].color = c
		w["val"].text = r["shown"]
		w["lvl"].text = MissionState.LEVEL_NAMES[r["level"]]
		w["lvl"].add_theme_color_override("font_color", c)
		w["bar"].set_data(r)
	var bits: Array = []
	for i in [3, 2, 1]:
		if counts[i] > 0:
			bits.append("%d %s" % [counts[i], MissionState.LEVEL_NAMES[i]])
	_summary.text = "ALL NOMINAL" if bits.is_empty() else "  ".join(bits)
	_summary.add_theme_color_override("font_color", Consequences.level_color(3 if counts[3] > 0 else (2 if counts[2] > 0 else (1 if counts[1] > 0 else 0))))

func _process(delta: float) -> void:
	# Critical rows blink.
	_t += delta
	var on := fmod(_t, 0.8) < 0.5
	for id in _rows:
		var w: Dictionary = _rows[id]
		if w["lvl"].text == "CRITICAL":
			w["lvl"].modulate.a = 1.0 if on else 0.25
			w["dot"].modulate.a = w["lvl"].modulate.a
		else:
			w["lvl"].modulate.a = 1.0
			w["dot"].modulate.a = 1.0

## A bar showing the value against the three thresholds (marks at caution, warning, critical).
class _Bar extends Control:
	var row: Dictionary = {}
	func set_data(r: Dictionary) -> void:
		row = r
		queue_redraw()
	func _draw() -> void:
		if row.is_empty():
			return
		var w := size.x
		var h := size.y
		var lim: Array = row["limits"]
		var lo: float
		var hi: float
		if row["direction"] == "max":
			lo = 0.0
			hi = maxf(lim[2] * 1.25, lim[2] + 0.2)
		else:
			hi = maxf(lim[0] * 1.5, lim[0] + 0.5)
			lo = minf(lim[2] - absf(lim[2]) * 0.5, lim[2] - 0.2)
		var f := func(v: float) -> float: return clampf((v - lo) / (hi - lo), 0.0, 1.0) * w
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.06))
		# Coloured zones
		var zones := [[lim[0], lim[1], Color(FUI.AMBER, 0.18)], [lim[1], lim[2], Color(FUI.RED, 0.2)]]
		for z in zones:
			var a: float = f.call(z[0])
			var b: float = f.call(z[1])
			draw_rect(Rect2(minf(a, b), 0, absf(b - a), h), z[2])
		var cpos: float = f.call(lim[2])
		if row["direction"] == "max":
			draw_rect(Rect2(cpos, 0, w - cpos, h), Color(FUI.RED, 0.35))
		else:
			draw_rect(Rect2(0, 0, cpos, h), Color(FUI.RED, 0.35))
		# Value marker
		var x: float = f.call(row["value"])
		var col := Consequences.level_color(row["level"])
		if row["direction"] == "max":
			draw_rect(Rect2(0, 2, x, h - 4), col)
		else:
			draw_rect(Rect2(0, 2, x, h - 4), Color(col, 0.85))
		for v in lim:
			var px: float = f.call(v)
			draw_line(Vector2(px, 0), Vector2(px, h), Color(1, 1, 1, 0.5), 1.0)
