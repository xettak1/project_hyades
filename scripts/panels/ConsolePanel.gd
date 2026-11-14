extends VBoxContainer
## Mission console screen: current orbit / trajectory, rocket, lifetime and cost.

var status_text := ""

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	MissionState.design_changed.connect(refresh)
	refresh()

func set_status(t: String) -> void:
	status_text = t
	refresh()

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var o := MissionState.orbit()
	var r := MissionState.rocket()
	var x: Dictionary = MissionState.compute()["extra"]
	var accent: Color = MissionState.mission()["env"]["accent"]
	add_child(UI.label("MISSION CONSOLE", 20, accent))
	add_child(UI.label(("TRAJECTORY: " if MissionState.has_fuel_system() else "ORBIT: ") + o["name"], 20))
	if MissionState.has_fuel_system():
		add_child(UI.label("Trip %d days, braking burn %.0f m/s, lunar eclipse up to %.0f min, Earth contact %.0f min/day" % [o["transfer_days"], o["delta_v_insert"], o["eclipse_min"], o["contact_min_per_day"]], 15, UI.COLOR_MUTED))
		add_child(UI.label("Fuel: %.0f kg loaded, %.0f kg to brake, %.0f kg left (lasts ~%.1f years)" % [x["fuel"], x["fuel_insert"], x["fuel_left"], x["life_cap"]], 16, UI.COLOR_BAD if x["fuel_left"] < 0.0 else Color.WHITE))
	else:
		add_child(UI.label("Eclipse %.0f min per orbit, ground contact %.0f min/day, revisit every %d days, orbit lasts ~%d years" % [o["eclipse_min"], o["contact_min_per_day"], o["revisit_days"], o["life_years"]], 15, UI.COLOR_MUTED))
	add_child(UI.label(o["tooltip"], 15, UI.COLOR_MUTED))
	var cap: float = x["rocket_cap"]
	var reach := "cannot reach this orbit!" if cap <= 0.0 else "carries up to %.0f kg there" % cap
	add_child(UI.label("ROCKET: %s  ($%.2fM, %s)" % [r["name"], x["rocket_cost"], reach], 17, UI.COLOR_BAD if cap <= 0.0 or x["mass"] > cap else Color.WHITE))
	add_child(UI.label("PLANNED LIFETIME: %d years (+$%.1fM operations per year)" % [MissionState.lifetime_years, MissionState.mission()["ops_cost_per_year"]], 17))
	add_child(UI.label("Spacecraft %.1f kg at launch   Total cost $%.2fM" % [x["mass"], x["cost"]], 17))
	if status_text != "":
		add_child(UI.label(status_text, 18, UI.COLOR_WARN))
