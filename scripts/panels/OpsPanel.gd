extends VBoxContainer
## Mission control side screen: day counter, timeline, data counters, event log.

var _day: Label
var _bar: ProgressBar
var _counts: Label
var _log: VBoxContainer
var _shown := 0

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UI.label("MISSION OPERATIONS", 22, UI.COLOR_ACCENT))
	_day = UI.label("Waiting for launch", 24)
	add_child(_day)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	add_child(_bar)
	_counts = UI.label("", 19)
	add_child(_counts)
	add_child(UI.label("MISSION LOG", 18, UI.COLOR_ACCENT))
	_log = VBoxContainer.new()
	add_child(_log)

func reset() -> void:
	_shown = 0
	for c in _log.get_children():
		c.queue_free()
	_day.text = "Waiting for launch"
	_bar.value = 0.0
	_counts.text = ""

func refresh(sim) -> void:
	if sim.in_cruise():
		_day.text = "Cruise to the Moon: day %d of %d" % [sim.day, sim.cruise_days]
	else:
		_day.text = "Mission day %d of %d" % [sim.day - sim.cruise_days, sim.planned_days - sim.cruise_days]
	_bar.value = sim.progress()
	_counts.text = "Images made %.0f GB   Sent %.0f GB\nUseful %.0f GB   Lost %.0f GB   Stored %.1f GB" % [sim.generated_total, sim.sent_total, sim.useful_total, sim.lost_total, sim.stored]
	while _shown < sim.events.size():
		var e: Dictionary = sim.events[_shown]
		_log.add_child(UI.label("Day %d - %s: %s" % [e["day"], e["title"], e["text"]], 15, UI.COLOR_WARN))
		_shown += 1
		while _log.get_child_count() > 4:
			var old := _log.get_child(0)
			_log.remove_child(old)
			old.queue_free()
