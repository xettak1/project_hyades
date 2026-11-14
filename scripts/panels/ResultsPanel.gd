extends VBoxContainer
## Mission report shown on the big screen after the mission.

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var r: Dictionary = MissionState.last_result
	var m := MissionState.mission()
	var score: int = r.get("score", 0)
	var color := UI.COLOR_GOOD if score >= 600 else (UI.COLOR_WARN if score >= 400 else UI.COLOR_BAD)
	add_child(UI.label("MISSION REPORT", 20, UI.COLOR_ACCENT))
	add_child(UI.label("%s   %d / 1000      (best so far %d, run %d)" % [r.get("rating", ""), score, MissionState.best_score, MissionState.runs], 34, color))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var w: Dictionary = GameData.SCORE_WEIGHTS
	var maxes := {"Requirements met": w["requirements"], "Data delivered": w["data"], "Resource efficiency": w["efficiency"], "Survival": w["survival"]}
	for k in r.get("parts", {}):
		left.add_child(UI.label("%s: %d / %d" % [k, int(round(r["parts"][k])), maxes[k]], 18))
	var req: Dictionary = m["requirements"]
	var met: Dictionary = r.get("req_met", {})
	left.add_child(UI.label("REQUIREMENTS", 16, UI.COLOR_ACCENT))
	left.add_child(_req(met.get("revisit", false), "Revisit every %d days or better" % req["max_revisit_days"]))
	left.add_child(_req(met.get("data", false), "%.0f GB/day useful (you: %.1f)" % [req["min_data_delivered"], r.get("avg_useful", 0.0)]))
	left.add_child(_req(met.get("lifetime", false), "%d year(s) of work (you: %d days)" % [req["min_lifetime"], r.get("days", 0)]))
	if met.has("resolution"):
		left.add_child(_req(met["resolution"], "Detail %.1f m or better (you: %.1f m)" % [req["max_resolution_m"], MissionState.compute()["extra"]["resolution"]]))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.6
	cols.add_child(right)
	right.add_child(UI.label("WHY IT WENT THIS WAY", 16, UI.COLOR_ACCENT))
	var why: Array = r.get("why", [])
	for i in mini(3, why.size()):
		right.add_child(UI.label("%d. %s" % [i + 1, why[i]], 17))

	var comp: Dictionary = m.get("comparison", {})
	if not comp.is_empty():
		add_child(UI.label("REAL MISSION MOST LIKE YOURS: " + comp["name"], 16, UI.COLOR_ACCENT))
		add_child(UI.label(comp["text"], 16))
	add_child(UI.label("Walk back to the lab to change the design and launch again. Press Esc to choose another mission.", 16, UI.COLOR_MUTED))

func _req(ok: bool, text: String) -> Label:
	return UI.label(("PASS  " if ok else "FAIL  ") + text, 17, UI.COLOR_GOOD if ok else UI.COLOR_BAD)
