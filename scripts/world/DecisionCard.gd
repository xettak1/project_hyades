extends CanvasLayer
## DECISION CARD: when you look at a part on a shelf, this card shows the choice you are making
## and its consequences, worked out with the data team's numbers:
## what changes (data, power, battery, mass, cost...), which checks it fixes or breaks,
## and the trade-off in words. If the part is already installed, it shows what switching away would do.
## After every decision (part installed, orbit, rocket, lifetime) it shows a "DECISION MADE" card:
## the choice, its cost, its trade-off, what it did to the resources, and what it means for later levels.
## Fixed on the RIGHT of the screen.

var _panel: PanelContainer
var _box: VBoxContainer
var _cat := ""
var _id := ""
var _mode := ""                 # "part" (looking at a part) or "made" (a decision just happened)
var _made_time := 0.0
var _prev_state: Dictionary = {}
var _prev_cfg: Dictionary = {}

## What a decision means for the later mission segments.
const LATER := {
	"payload": "Level 2: more or fewer pictures to store. Level 3: more or less data to squeeze through the radio link.",
	"solar": "Level 2: decides how much can run at once while observing.",
	"battery": "Level 2: decides whether the satellite survives each trip through Earth's shadow.",
	"comms": "Level 3: sets how fast the pictures get home.",
	"computer": "Level 2: how many pictures we can keep before the next ground pass.",
	"adcs": "Level 2: how many pictures come out sharp. Level 4: clearer flood maps.",
	"propulsion": "Level 2: whether we can hold our orbit for the whole mission.",
	"thermal": "Level 2: keeps the battery healthy in the cold.",
	"orbit": "Level 2: how often we see the farms. Level 3: how many minutes a day we can talk to Earth.",
	"rocket": "Every dollar spent on the launch is a dollar less for operations in Levels 2 and 3.",
	"lifetime": "A longer mission collects more pictures, but every year costs operations money.",
}
func _ready() -> void:
	layer = 4
	add_to_group("decision")
	_panel = PanelContainer.new()
	var s := FUI.box(Color(0.03, 0.06, 0.12, 0.94), Color(FUI.SKY, 0.5), 10, 14)
	s.border_width_left = 4
	_panel.add_theme_stylebox_override("panel", s)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_box = FUI.vb(4)
	_panel.add_child(_box)
	_panel.visible = false
	_prev_state = MissionState.current()
	_prev_cfg = _cfg()
	MissionState.design_changed.connect(_on_design_changed)

func _cfg() -> Dictionary:
	return {"picks": MissionState.picks.duplicate(), "orbit": MissionState.orbit_id, "rocket": MissionState.rocket_id, "lifetime": MissionState.lifetime_years}

func _on_design_changed() -> void:
	var now := MissionState.current()
	var cfg := _cfg()
	if MissionState.phase == "design":
		var what := ""
		var key := ""
		for cat in cfg["picks"]:
			if cfg["picks"][cat] != _prev_cfg["picks"].get(cat, ""):
				what = "part"
				key = cat
		if cfg["orbit"] != _prev_cfg["orbit"]:
			what = "orbit"
		elif cfg["rocket"] != _prev_cfg["rocket"]:
			what = "rocket"
		elif cfg["lifetime"] != _prev_cfg["lifetime"]:
			what = "lifetime"
		if what != "":
			_build_made(what, key, _prev_state, now)
	_prev_state = now
	_prev_cfg = cfg

## "DECISION MADE" card: selected option, cost, benefit and drawback, resource impact, later consequences.
func _build_made(what: String, cat: String, before: Dictionary, after: Dictionary) -> void:
	_clear()
	var title := ""
	var name := ""
	var cost := ""
	var trade := ""
	match what:
		"part":
			var p: Dictionary = GameData.part(cat, MissionState.picks[cat])
			title = Lab_CAT.get(cat, cat.to_upper())
			name = p["name"]
			cost = _specs(p)
			trade = p.get("tooltip", "")
		"orbit":
			var o := MissionState.orbit()
			title = "ORBIT"
			name = o["name"]
			cost = "revisit %d days · contact %d min/day · eclipse %d min" % [o["revisit_days"], int(o["contact_min_per_day"]), int(o["eclipse_min"])]
			trade = o.get("tooltip", "")
			cat = "orbit"
		"rocket":
			var r := MissionState.rocket()
			title = "LAUNCH VEHICLE"
			name = r["name"]
			cost = "$%.2fM for this spacecraft" % after["x"]["rocket_cost"]
			trade = r.get("tooltip", "")
			cat = "rocket"
		"lifetime":
			title = "MISSION LIFETIME"
			name = "%d years" % MissionState.lifetime_years
			cost = "$%.1fM operations per year" % MissionState.mission()["ops_cost_per_year"]
			cat = "lifetime"
	_line("DECISION MADE · " + title, 12, FUI.GREEN, "mono_semi")
	_line(name, 18, FUI.WHITE, "sans_semi")
	_line("COST  " + cost, 12, FUI.MUTED, "mono")
	if trade != "":
		_line(trade, 13, FUI.TEXT)
	_box.add_child(FUI.hline())
	_line("Impact on resources:", 13, FUI.TEXT2, "sans_semi")
	var ch := Consequences.changes(before, after, 6)
	if ch.is_empty():
		_line("No change to the numbers.", 13, FUI.MUTED)
	for c in ch:
		_line(c[0], 13, Consequences.color(c[1]), "mono")
	for row in Consequences.verdicts(before, after):
		_line(row[0], 13, Consequences.color(row[1]), "sans_semi" if row[1] != "warn" else "sans")
	_box.add_child(FUI.hline())
	_line("LATER IN THE MISSION", 11, FUI.AMBER, "mono_semi")
	_line(LATER.get(cat, ""), 13, Color("#fde68a"))
	_mode = "made"
	_made_time = 7.0
	_panel.visible = true
	_panel.size = Vector2.ZERO
	_panel.reset_size.call_deferred()

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

func show_part(cat: String, id: String) -> void:
	if MissionState.phase != "design":
		return
	_cat = cat
	_id = id
	if _mode == "made" and _made_time > 0.0:
		return
	_mode = "part"
	_build()
	_panel.visible = true

func hide_part(cat: String, id: String) -> void:
	if cat == _cat and id == _id:
		_cat = ""
		if _mode == "part":
			_panel.visible = false

func _line(text: String, size: int, color: Color, kind: String = "sans") -> Label:
	var l := FUI.t(text, size, color, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(392, 0)
	_box.add_child(l)
	return l

func _build() -> void:
	_clear()
	var opts: Dictionary = GameData.parts_for(MissionState.mission_id)[_cat]
	var installed: String = MissionState.picks.get(_cat, "")
	var looking: Dictionary = opts[_id]
	var is_installed := installed == _id
	# What we compare: installing the part you look at, or (if it's installed) switching to the other one.
	var other_id := _id          # the option the comparison switches to
	if is_installed:
		other_id = ""
		for k in opts:
			if k != _id:
				other_id = k
				break
	var title: String = Lab_CAT.get(_cat, _cat.to_upper())
	_line("DECISION · " + title, 12, FUI.SKY, "mono_semi")
	_line(looking["name"], 18, FUI.WHITE, "sans_semi")
	_line(("INSTALLED  ·  " if is_installed else "") + str(looking.get("tier", "")).to_upper() + "  ·  " + _specs(looking), 12, FUI.GREEN if is_installed else FUI.MUTED, "mono")
	if looking.has("science"):
		_line("Science value: %d / 100" % int(looking["science"]), 12, FUI.AMBER, "mono")
	_box.add_child(FUI.hline())
	var before := MissionState.current()
	if other_id == "":
		_line("This is the only option for this slot.", 13, FUI.MUTED)
	else:
		var after := MissionState.preview("part", _cat, other_id)
		if is_installed:
			_line("If you switch to %s:" % opts[other_id]["name"], 13, FUI.TEXT2, "sans_semi")
		else:
			_line("If you install this instead of %s:" % opts[installed]["name"], 13, FUI.TEXT2, "sans_semi")
		var ch := Consequences.changes(before, after, 7)
		if ch.is_empty():
			_line("No change to the numbers.", 13, FUI.MUTED)
		for c in ch:
			_line(c[0], 13, Consequences.color(c[1]), "mono")
		var v := Consequences.verdicts(before, after)
		if not v.is_empty():
			_box.add_child(FUI.hline())
		for row in v:
			_line(row[0], 13, Consequences.color(row[1]), "sans_semi" if row[1] != "warn" else "sans")
	_box.add_child(FUI.hline())
	_line(looking.get("tooltip", ""), 13, FUI.TEXT)
	_line("[E] install" if not is_installed else "Installed. Look at the other one to compare.", 12, FUI.DIM, "mono")
	_panel.size = Vector2.ZERO
	_panel.reset_size.call_deferred()

const Lab_CAT := {"payload": "PAYLOAD (INSTRUMENT)", "solar": "SOLAR POWER", "battery": "BATTERY", "comms": "RADIO",
	"computer": "COMPUTER & STORAGE", "adcs": "POINTING (ATTITUDE CONTROL)", "propulsion": "PROPULSION", "thermal": "THERMAL CONTROL"}

func _specs(p: Dictionary) -> String:
	var bits: Array = ["%.2f kg" % p.get("mass", 0.0), "$%.2fM" % p.get("cost", 0.0)]
	if p.has("power"):
		bits.append("%.1f W" % p["power"])
	if p.has("power_gen"):
		bits.append("makes %.1f W" % p["power_gen"])
	if p.has("energy"):
		bits.append("%.0f Wh" % p["energy"])
	if p.has("data"):
		bits.append("%.2f GB/day" % p["data"])
	if p.has("mbps"):
		bits.append("%.1f Mbps" % p["mbps"])
	if p.has("storage"):
		bits.append("%.0f GB" % p["storage"])
	if p.has("pointing"):
		bits.append("%d%% sharp" % int(100 * p["pointing"]))
	if p.has("delta_v"):
		bits.append("%.0f m/s" % p["delta_v"])
	return "  ".join(bits)

func _process(delta: float) -> void:
	# Fixed on the right, below the progress bar.
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp.x - _panel.size.x - 12, 56)
	if _mode == "made" and _made_time > 0.0:
		_made_time -= delta
		if _made_time <= 0.0:
			# back to the part you're looking at, if any
			if _cat != "" and _id != "" and MissionState.phase == "design":
				_mode = "part"
				_build()
			else:
				_panel.visible = false
	if not _panel.visible:
		return
	for n in get_tree().get_nodes_in_group("screenview"):
		if n.is_open() and _mode == "part":
			_panel.visible = false

func is_showing() -> bool:
	return _panel.visible

func width() -> float:
	return _panel.size.x
