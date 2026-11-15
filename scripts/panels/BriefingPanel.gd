extends VBoxContainer
## Mission briefing wall screen.

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var m := MissionState.mission()
	var req: Dictionary = m["requirements"]
	var t: Array = m["req_text"]
	add_child(UI.label("MISSION BRIEFING  -  " + m["difficulty"].to_upper(), 20, m["env"]["accent"]))
	add_child(UI.label(m["name"] + "  -  " + m["spacecraft_class"], 30))
	add_child(UI.label(m["objective"], 21))
	add_child(UI.label("Budget $%sM     Mass limit %s kg" % [_n(m["budget"]), _n(m["mass_limit"])], 19, UI.COLOR_MUTED))
	add_child(UI.label("REQUIREMENTS", 19, m["env"]["accent"]))
	add_child(UI.label("1. " + t[0] % req["max_revisit_days"], 20))
	add_child(UI.label("2. " + t[1] % req["min_data_delivered"], 20))
	add_child(UI.label("3. " + t[2] % req["min_lifetime"], 20))
	if req.has("max_resolution_m"):
		add_child(UI.label("4. " + t[3] % req["max_resolution_m"], 20))
	add_child(UI.label("MAIN CHALLENGE: " + m["challenge"], 18, UI.COLOR_WARN))
	add_child(UI.label("Look at a part on the shelves to read it, press E to install it. Check Resources and Advisors, set orbit and rocket at the Mission Console, then press LAUNCH.", 17, UI.COLOR_MUTED))

func _n(v: float) -> String:
	return ("%.0f" % v) if v >= 10.0 else ("%.1f" % v)
