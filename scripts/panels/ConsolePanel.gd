extends VBoxContainer
## Mission console screen. Open it full view (E) and click to choose orbit / trajectory,
## rocket and lifetime, then LAUNCH. The physical buttons on the desk do the same.

var status_text := ""

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	MissionState.design_changed.connect(refresh)
	refresh()

func set_status(t: String) -> void:
	status_text = t
	refresh()

func _choice_row(title: String, ids: Array, table: Dictionary, current: String, setter: Callable) -> void:
	var row := UI.hbox(8)
	var t := _tag(title, 15)
	t.custom_minimum_size = Vector2(110, 0)
	row.add_child(t)
	for id in ids:
		var b := UI.button(_short(table[id]["name"]), 14)
		b.toggle_mode = true
		b.button_pressed = (id == current)
		b.custom_minimum_size = Vector2(60, 34)
		b.clip_text = true
		b.tooltip_text = table[id]["name"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(setter.bind(id))
		row.add_child(b)
	add_child(row)

## A label that stays on one line (inside rows, wrapping labels shrink to one letter wide).
func _tag(text: String, size: int, color: Color = UI.COLOR_MUTED) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

## "If you switch to X: ..." for every option that is not selected.
func _alternatives(kind: String, ids: Array, table: Dictionary, current: String, now: Dictionary) -> void:
	for id in ids:
		if id == current:
			continue
		var sm := Consequences.summary(now, MissionState.preview(kind, "", id))
		_cons("IF %s → %s" % [_short(table[id]["name"]).to_upper(), sm[0]], sm[1])

func _cons(text: String, kind: String) -> void:
	var l := UI.label(text, 13, Consequences.color(kind))
	add_child(l)

func _short(n: String) -> String:
	return n if n.length() <= 34 else n.substr(0, 32) + "..."

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var m := MissionState.mission()
	var o := MissionState.orbit()
	var r := MissionState.rocket()
	var x: Dictionary = MissionState.compute()["extra"]
	var accent: Color = m["env"]["accent"]
	var fuel := MissionState.has_fuel_system()
	add_child(UI.label("MISSION CONSOLE", 20, accent))

	var now := MissionState.current()
	_choice_row("TRAJECTORY" if fuel else "ORBIT", m["orbits"], GameData.ORBITS, MissionState.orbit_id, MissionState.set_orbit)
	if fuel:
		add_child(UI.label("Trip %d days, braking burn %.0f m/s. Fuel: %.0f kg loaded, %.0f kg to brake, %.0f kg left (lasts ~%.1f years)" % [o["transfer_days"], o["delta_v_insert"], x["fuel"], x["fuel_insert"], x["fuel_left"], x["life_cap"]], 14, UI.COLOR_BAD if x["fuel_left"] < 0.0 else UI.COLOR_MUTED))
	else:
		add_child(UI.label("NOW: eclipse %.0f of %.0f min per orbit, ground contact %.0f min/day, revisit %d days, orbit lasts ~%d years" % [o["eclipse_min"], o["period_min"], o["contact_min_per_day"], o["revisit_days"], o["life_years"]], 13, UI.COLOR_MUTED))
	_alternatives("orbit", m["orbits"], GameData.ORBITS, MissionState.orbit_id, now)

	_choice_row("ROCKET", m["rockets"], GameData.ROCKETS, MissionState.rocket_id, MissionState.set_rocket)
	var cap: float = x["rocket_cap"]
	var reach := "cannot reach this orbit!" if cap <= 0.0 else "carries up to %.0f kg there" % cap
	add_child(UI.label(("NOW: %s, $%.2fM, %s" % [r["name"], x["rocket_cost"], reach]) if not r.is_empty() else "NO ROCKET CHOSEN YET: pick one above", 13, UI.COLOR_BAD if cap <= 0.0 or x["mass"] > cap else UI.COLOR_MUTED))
	_alternatives("rocket", m["rockets"], GameData.ROCKETS, MissionState.rocket_id, now)

	var life := UI.hbox(10)
	life.add_child(_tag("PLANNED LIFETIME", 15))
	var minus := UI.button("  -  ", 18)
	minus.pressed.connect(func(): MissionState.set_lifetime(maxi(1, MissionState.lifetime_years - 1)))
	life.add_child(minus)
	life.add_child(_tag("%d years" % MissionState.lifetime_years, 18, Color.WHITE))
	var plus := UI.button("  +  ", 18)
	plus.pressed.connect(func(): MissionState.set_lifetime(mini(12, MissionState.lifetime_years + 1)))
	life.add_child(plus)
	life.add_child(_tag("(+$%.1fM operations per year)" % m["ops_cost_per_year"], 14))
	add_child(life)
	var more := Consequences.summary(now, MissionState.preview("lifetime", "", MissionState.lifetime_years + 1))
	_cons("+1 year → " + more[0], more[1])

	add_child(UI.label("Spacecraft %.1f kg at launch   |   Total cost $%.2fM of $%.0fM" % [x["mass"], x["cost"], m["budget"]], 17))
	var launch := UI.button("LAUNCH", 22)
	launch.custom_minimum_size = Vector2(0, 46)
	launch.add_theme_color_override("font_color", UI.COLOR_BAD)
	launch.pressed.connect(func(): get_tree().call_group("lab", "request_launch"))
	add_child(launch)
	if status_text != "":
		add_child(UI.label(status_text, 16, UI.COLOR_WARN))
