extends VBoxContainer
## MISSION CONSOLE (Level 1, right wall). One decision at a time, in four steps:
##   1 ORBIT  ·  2 ROCKET  ·  3 LIFETIME  ·  4 REVIEW & LAUNCH
## Each choice is shown as option cards with a one-line plain description, three key facts and what
## changes if you pick it. Open the screen full view (E) and click; the desk buttons still work too.
## Card wording: data/dialogue/decision_cards.json ("orbits", "rockets").

const STEPS := ["ORBIT", "ROCKET", "LIFETIME", "LAUNCH"]
const QUESTIONS := [
	"Where should the satellite fly?",
	"How will the satellite get to space?",
	"How long should the mission run?",
	"Check everything, then launch.",
]

var status_text := ""
var step := 0
var _text: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var f := FileAccess.open("res://data/dialogue/decision_cards.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_text = d
	MissionState.design_changed.connect(refresh)
	refresh()

func set_status(t: String) -> void:
	status_text = t
	if t != "":
		step = 3            # launch problems are shown on the review step
	refresh()

func go_step(i: int) -> void:
	step = clampi(i, 0, STEPS.size() - 1)
	refresh()

# ------------------------------------------------------------------ small builders
func _t(text: String, size: int, color: Color = FUI.TEXT, kind := "sans") -> Label:
	var l := FUI.t(text, size, color, kind)
	return l

func _wrap(text: String, size: int, color: Color = FUI.TEXT, kind := "sans") -> Label:
	var l := FUI.t(text, size, color, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _fact(box: VBoxContainer, label: String, value: String, color: Color = FUI.WHITE) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := _t(label, 16, FUI.MUTED, "sans_med")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(_t(value, 17, color, "mono_semi"))
	box.add_child(h)

func _btn(text: String, tint: Color, action: Callable, min_w := 140.0) -> Button:
	var b := FUI.button(text, tint)
	b.custom_minimum_size = Vector2(min_w, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(action)
	return b

## A clickable option card. Its content ignores the mouse so the whole card is one button.
func _option(title: String, line: String, selected: bool, on_pick: Callable) -> VBoxContainer:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var col := FUI.SKY if selected else FUI.BORDER
	for s in ["normal", "hover", "pressed", "focus"]:
		var st := FUI.box(Color(0.06, 0.11, 0.2, 0.95) if selected else (Color(0.07, 0.1, 0.16) if s == "hover" else FUI.CARD), col if s != "hover" or selected else Color(FUI.SKY, 0.6), 10, 14, 2 if selected else 1)
		b.add_theme_stylebox_override(s, st)
	b.pressed.connect(on_pick)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := _wrap(title, 21, FUI.WHITE, "sans_semi")
	head.add_child(tl)
	if selected:
		head.add_child(FUI.chip("SELECTED", FUI.SKY, true))
	v.add_child(head)
	v.add_child(_wrap(line, 16, FUI.TEXT2))
	v.add_child(FUI.hline())
	add_child(b)
	# make the card's height follow its content
	b.custom_minimum_size = Vector2(0, 0)
	b.set_meta("content", v)
	return v

func _impact(v: VBoxContainer, kind: String, id, selected: bool) -> void:
	if selected:
		return
	var now := MissionState.current()
	var after := MissionState.preview(kind, "", id)
	var rows := Consequences.compact(now, after, 3)
	if rows.is_empty():
		return
	v.add_child(_t("IF YOU PICK THIS", 12, FUI.DIM, "mono_semi"))
	for r in rows:
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _t(r[0], 16, FUI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(_t(r[1], 16, Consequences.color(r[2]), "mono_semi"))
		v.add_child(h)

# ------------------------------------------------------------------ screen
func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	# step tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	for i in STEPS.size():
		var done := _step_done(i)
		var tb := FUI.button(("✓ " if done and i != step else "%d  " % (i + 1)) + STEPS[i], FUI.SKY if i == step else Color(0, 0, 0, 0))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 34)
		tb.add_theme_font_size_override("font_size", 14)
		if i != step:
			tb.add_theme_color_override("font_color", FUI.GREEN if done else FUI.MUTED)
		tb.pressed.connect(go_step.bind(i))
		tabs.add_child(tb)
	add_child(_t("STEP %d OF %d" % [step + 1, STEPS.size()], 12, FUI.DIM, "mono_semi"))
	add_child(_t(QUESTIONS[step], 26, FUI.WHITE, "sans_semi"))
	match step:
		0: _orbit_step()
		1: _rocket_step()
		2: _life_step()
		3: _launch_step()
	# navigation
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	if step > 0:
		nav.add_child(_btn("◀  BACK", FUI.MUTED, go_step.bind(step - 1)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	if step < STEPS.size() - 1:
		nav.add_child(_btn("NEXT  ▶", FUI.SKY, go_step.bind(step + 1)))
	add_child(nav)

func _step_done(i: int) -> bool:
	match i:
		0: return MissionState.orbit_id != ""
		1: return MissionState.rocket_id != ""
		2: return true
	return MissionState.gate()["hard"].is_empty()

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return h

func _orbit_step() -> void:
	var m := MissionState.mission()
	var row := _row()
	add_child(row)
	for id in m["orbits"]:
		var o: Dictionary = GameData.ORBITS[id]
		var t: Dictionary = _text.get("orbits", {}).get(id, {})
		var sel: bool = id == MissionState.orbit_id
		var v := _option(t.get("name", o["name"]), t.get("line", ""), sel, MissionState.set_orbit.bind(id))
		var card: Control = v.get_parent().get_parent()
		remove_child(card)
		row.add_child(card)
		_fact(v, "Sees each farm every", "%d days" % int(o["revisit_days"]))
		_fact(v, "Talks to the ground", "%d min / day" % int(o["contact_min_per_day"]))
		_fact(v, "In Earth's shadow", "%d of %d min" % [int(o["eclipse_min"]), int(o["period_min"])])
		_impact(v, "orbit", id, sel)

func _rocket_step() -> void:
	var m := MissionState.mission()
	var x: Dictionary = MissionState.compute()["extra"]
	var row := _row()
	add_child(row)
	for id in m["rockets"]:
		var r: Dictionary = GameData.ROCKETS[id]
		var t: Dictionary = _text.get("rockets", {}).get(id, {})
		var sel: bool = id == MissionState.rocket_id
		var v := _option(t.get("name", r["name"]), t.get("line", ""), sel, MissionState.set_rocket.bind(id))
		var card: Control = v.get_parent().get_parent()
		remove_child(card)
		row.add_child(card)
		var cap: float = float(r.get("capacity", {}).get(MissionState.orbit_id, 0.0))
		var price: float = float(r.get("cost", 0.0)) + maxf(0.0, float(x["mass"]) - float(r.get("included_kg", 0.0))) * float(r.get("per_kg", 0.0))
		_fact(v, "Price", "$%.2fM" % price)
		_fact(v, "Can carry to your orbit", ("%d kg" % int(cap)) if cap > 0.0 else "can't reach it", FUI.WHITE if cap > 0.0 else FUI.RED)
		_fact(v, "Your satellite weighs", "%.1f kg" % float(x["mass"]), FUI.WHITE if cap <= 0.0 or x["mass"] <= cap else FUI.RED)
		_impact(v, "rocket", id, sel)
	if MissionState.rocket_id == "":
		add_child(_t("No rocket chosen yet: click one.", 15, FUI.AMBER, "sans_med"))

func _life_step() -> void:
	var m := MissionState.mission()
	var x: Dictionary = MissionState.compute()["extra"]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", FUI.box(FUI.CARD, FUI.BORDER, 10, 18))
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(_wrap("Each extra year means more pictures for farmers, but the team that runs the satellite costs money every year.", 15, FUI.TEXT2))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	h.add_child(_btn("–  1 YEAR", FUI.SKY, func(): MissionState.set_lifetime(maxi(1, MissionState.lifetime_years - 1)), 150))
	h.add_child(_t("%d years" % MissionState.lifetime_years, 34, FUI.WHITE, "sans_semi"))
	h.add_child(_btn("+  1 YEAR", FUI.SKY, func(): MissionState.set_lifetime(mini(12, MissionState.lifetime_years + 1)), 150))
	v.add_child(h)
	v.add_child(FUI.hline())
	var req := int(m["requirements"]["min_lifetime"])
	_fact(v, "The mission needs at least", "%d years" % req, FUI.WHITE if MissionState.lifetime_years >= req else FUI.RED)
	_fact(v, "Your orbit can last", "about %d years" % int(x["life_cap"]), FUI.WHITE if x["life_cap"] >= MissionState.lifetime_years else FUI.AMBER)
	_fact(v, "Running cost", "$%.1fM per year" % float(m["ops_cost_per_year"]))
	var more := Consequences.compact(MissionState.current(), MissionState.preview("lifetime", "", MissionState.lifetime_years + 1), 2)
	if not more.is_empty():
		v.add_child(_t("ONE MORE YEAR WOULD CHANGE", 12, FUI.DIM, "mono_semi"))
		for r in more:
			_fact(v, r[0], r[1], Consequences.color(r[2]))

func _launch_step() -> void:
	var m := MissionState.mission()
	var x: Dictionary = MissionState.compute()["extra"]
	var g := MissionState.gate()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", FUI.box(FUI.CARD, FUI.BORDER, 10, 16))
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var missing := MissionState.missing_parts().size()
	var n := MissionState.categories().size()
	_fact(v, "Parts installed", "%d of %d" % [n - missing, n], FUI.GREEN if missing == 0 else FUI.AMBER)
	_fact(v, "Orbit", MissionState.orbit().get("name", "-").split(" (")[0])
	_fact(v, "Rocket", MissionState.rocket().get("name", "not chosen").split(" (")[0], FUI.WHITE if MissionState.rocket_id != "" else FUI.AMBER)
	_fact(v, "Lifetime", "%d years" % MissionState.lifetime_years)
	_fact(v, "Mass", "%.1f of %.0f kg" % [x["mass"], float(m["mass_limit"])], FUI.WHITE if x["mass"] <= float(m["mass_limit"]) else FUI.RED)
	_fact(v, "Cost", "$%.2fM of $%.0fM" % [x["cost"], float(m["budget"])], FUI.WHITE if x["cost"] <= float(m["budget"]) else FUI.RED)
	v.add_child(FUI.hline())
	if not g["hard"].is_empty():
		v.add_child(_t("NOT READY YET", 14, FUI.RED, "mono_semi"))
		for msg in g["hard"].slice(0, 2):
			v.add_child(_wrap("• " + str(msg), 14, FUI.TEXT2))
	elif not g["warn"].is_empty():
		v.add_child(_t("READY, WITH %d WARNING%s (see the Advisors screen)" % [g["warn"].size(), "S" if g["warn"].size() > 1 else ""], 14, FUI.AMBER, "mono_semi"))
	else:
		v.add_child(_t("ALL SYSTEMS GO", 15, FUI.GREEN, "mono_semi"))
	var launch := FUI.button("LAUNCH", FUI.RED)
	launch.custom_minimum_size = Vector2(0, 50)
	launch.add_theme_font_size_override("font_size", 22)
	launch.pressed.connect(func(): get_tree().call_group("lab", "request_launch"))
	add_child(launch)
	if status_text != "":
		add_child(_wrap(status_text, 14, FUI.AMBER, "sans_med"))
