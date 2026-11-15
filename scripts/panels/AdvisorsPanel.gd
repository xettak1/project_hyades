extends VBoxContainer
## ADVISORS: every check that is not nominal, worst first, with why it matters and how to fix it.
## Levels come from data/tables/thresholds.csv. CRITICAL with a launch block stops the launch.

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	MissionState.design_changed.connect(refresh)
	refresh()

func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(UI.label("ADVISORS", 22, UI.COLOR_ACCENT))
	var g := MissionState.gate()
	for t in g["hard"]:
		_item("⛔ LAUNCH BLOCKED", t, Consequences.color("critical"))
	var rows := MissionState.assess()
	rows.sort_custom(func(a, b): return a["level"] > b["level"])
	var shown := 0
	for r in rows:
		if r["level"] == MissionState.NOMINAL or (r["level"] == MissionState.CRITICAL and r["blocks"]):
			continue
		var tag: String = ["", "🟡 CAUTION", "🔴 WARNING", "⛔ CRITICAL"][r["level"]]
		_item("%s  %s: %s" % [tag, r["label"], r["shown"]], r["why"] + "  FIX: " + r["fix"], Consequences.level_color(r["level"]))
		shown += 1
	if g["hard"].is_empty() and shown == 0:
		add_child(UI.label("All checks nominal. Ready for launch!", 22, UI.COLOR_GOOD))

func _item(title: String, body: String, color: Color) -> void:
	add_child(UI.label(title, 17, color))
	var b := UI.label(body, 14, UI.COLOR_MUTED)
	add_child(b)
