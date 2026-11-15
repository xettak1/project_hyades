extends CanvasLayer
## TOP of the screen: the current mission stage and overall progress through the four segments.
##   ✓ LAUNCH ── ● SPACE ── ○ GROUND ── ○ USER          MISSION 25%  ● status

var _bar: Control

func _ready() -> void:
	layer = 3
	add_to_group("progress_bar")
	var p := PanelContainer.new()
	var s := FUI.box(Color(0.025, 0.05, 0.1, 0.88), Color(FUI.SKY, 0.3), 8, 6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.custom_minimum_size = Vector2(600, 0)
	p.position = Vector2(-300, 8)
	add_child(p)
	_bar = _Stages.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	p.add_child(_bar)

func _process(_d: float) -> void:
	_bar.queue_redraw()

class _Stages extends Control:
	func _draw() -> void:
		var f := FUI.font("JetBrainsMono-SemiBold")
		var cur := maxi(LevelFlow.index, 0)
		var levels: Array = LevelFlow.LEVELS
		var n := levels.size()
		var w := size.x - 150.0
		var step := w / n
		var y := size.y / 2.0
		for i in n:
			var x := i * step + 8.0
			var done := i < cur
			var now := i == cur
			var c: Color = FUI.GREEN if done else (FUI.SKY if now else FUI.FAINT)
			var name_w := f.get_string_size(levels[i]["title"].split(" ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			if i < n - 1:
				draw_line(Vector2(x + 20 + name_w, y), Vector2(x + step - 12, y), Color(FUI.GREEN if done else FUI.BORDER, 0.9), 2.0)
			draw_circle(Vector2(x, y), 7.0, FUI.BG)
			if done:
				draw_circle(Vector2(x, y), 7.0, c)
				draw_polyline(PackedVector2Array([Vector2(x - 3, y), Vector2(x - 1, y + 3), Vector2(x + 4, y - 3)]), FUI.BG, 2.0, true)
			elif now:
				draw_circle(Vector2(x, y), 7.0, c)
				draw_arc(Vector2(x, y), 10.0, 0, TAU, 20, Color(c, 0.5), 1.5, true)
			else:
				draw_arc(Vector2(x, y), 7.0, 0, TAU, 20, c, 1.5, true)
			var name: String = levels[i]["title"].split(" ")[0]
			draw_string(f, Vector2(x + 14, y + 4), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FUI.WHITE if now else c)
		var pct := int(100.0 * cur / n)
		draw_string(f, Vector2(size.x - 140, y + 4), "MISSION %d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FUI.MUTED)
		var st: int = MissionState.worst_level(MissionState.assess()) if cur == 0 else int(MissionState.live.get("status_level", 0))
		var sc: Color = [FUI.GREEN, FUI.AMBER, FUI.RED, Color("#ff3b3b")][clampi(st, 0, 3)]
		var building := cur == 0 and (not MissionState.missing_parts().is_empty() or MissionState.rocket_id == "")
		if building:
			sc = FUI.SKY
		draw_circle(Vector2(size.x - 40, y), 5.0, sc)
		draw_string(f, Vector2(size.x - 31, y + 4), "BUILD" if building else ["OK", "CAUT", "WARN", "CRIT"][clampi(st, 0, 3)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, sc)
