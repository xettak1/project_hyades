extends VBoxContainer
## Live warnings from the four mission advisors (launch review).

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	MissionState.design_changed.connect(refresh)
	refresh()

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var g := MissionState.gate()
	add_child(UI.label("ADVISORS", 22, UI.COLOR_ACCENT))
	if g["hard"].is_empty() and g["warn"].is_empty():
		add_child(UI.label("All checks pass. Ready for launch!", 22, UI.COLOR_GOOD))
	for t in g["hard"]:
		add_child(UI.label("BLOCKED: " + t, 18, UI.COLOR_BAD))
	for t in g["warn"]:
		add_child(UI.label("WARNING: " + t, 18, UI.COLOR_WARN))
