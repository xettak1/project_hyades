extends CanvasLayer
## DECISION CARD: appears on the RIGHT (under the Mission Instructions) only while you look at a part,
## to help you compare and choose. It shows just:
##   option name · cost · one advantage · one disadvantage · resource impact (top 3 changes) · [E] select
## Press F for more details (all the numbers, warnings and what it means for later levels).
## Wording: data/dialogue/decision_cards.json. Numbers: data/tables/parts.csv via MissionState.

const CARDS := "res://data/dialogue/decision_cards.json"
const WIDTH := 300.0

var _panel: PanelContainer
var _box: VBoxContainer
var _cat := ""
var _id := ""
var _details := false
var _text: Dictionary = {}

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
	var s := FUI.box(Color(0.025, 0.05, 0.1, 0.94), Color(FUI.SKY, 0.5), 10, 12)
	s.border_width_left = 3
	_panel.add_theme_stylebox_override("panel", s)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_panel)
	_box = FUI.vb(4)
	_panel.add_child(_box)
	_panel.visible = false
	var f := FileAccess.open(CARDS, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_text = d
	MissionState.design_changed.connect(func():
		if _panel.visible and _cat != "":
			_build())

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

func show_part(cat: String, id: String) -> void:
	if MissionState.phase != "design":
		return
	_cat = cat
	_id = id
	_details = false
	_build()
	_panel.visible = true

func hide_part(cat: String, id: String) -> void:
	if cat == _cat and id == _id:
		_cat = ""
		_panel.visible = false

func _line(text: String, size: int, color: Color, kind: String = "sans") -> Label:
	var l := FUI.t(text, size, color, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 28, 0)
	_box.add_child(l)
	return l

func _pair(label: String, text: String, color: Color) -> void:
	var h := FUI.hb(6)
	var a := FUI.t(label, 13, color, "sans_semi")
	a.custom_minimum_size = Vector2(22, 0)
	h.add_child(a)
	var b := FUI.t(text, 13, FUI.TEXT2)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(WIDTH - 56, 0)
	h.add_child(b)
	_box.add_child(h)

func _build() -> void:
	_clear()
	var opts: Dictionary = GameData.parts_for(MissionState.mission_id)[_cat]
	var installed: String = MissionState.picks.get(_cat, "")
	var p: Dictionary = opts[_id]
	var is_installed := installed == _id
	var tier := str(p.get("tier", ""))
	var t: Dictionary = _text.get(_cat, {}).get(tier, {})
	_line(Lab_CAT.get(_cat, _cat.to_upper()), 11, FUI.SKY, "mono_semi")
	_line(str(t.get("name", p["name"])).to_upper(), 16, FUI.WHITE, "sans_semi")
	var chip := FUI.hb(8)
	chip.add_child(FUI.chip("$%.2fM" % p.get("cost", 0.0), FUI.AMBER, true))
	chip.add_child(FUI.chip("%.2f kg" % p.get("mass", 0.0), FUI.MUTED, true))
	if is_installed:
		chip.add_child(FUI.chip("INSTALLED", FUI.GREEN, true))
	_box.add_child(chip)
	_pair("+", str(t.get("pro", p.get("tooltip", ""))), FUI.GREEN)
	_pair("−", str(t.get("con", "")), FUI.AMBER)
	# Resource impact: what installing this (or switching away, if installed) changes.
	var other := _id
	if is_installed:
		for k in opts:
			if k != _id:
				other = k
	var before := MissionState.current()
	var after := MissionState.preview("part", _cat, other) if other != installed else before
	var ch := Consequences.compact(before, after, 3)
	if not ch.is_empty():
		_line("IF YOU SWITCH" if is_installed else "RESOURCE IMPACT", 10, FUI.MUTED, "mono_semi")
		for c in ch:
			var h := FUI.hb(6)
			var a := FUI.t(c[0], 12, FUI.TEXT)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(a)
			h.add_child(FUI.t(c[1], 12, Consequences.color(c[2]), "mono_semi"))
			_box.add_child(h)
	if _details:
		_box.add_child(FUI.hline())
		_line(p["name"], 13, FUI.TEXT2, "sans_semi")
		_line(_specs(p), 12, FUI.MUTED, "mono")
		for c in Consequences.changes(before, after, 8).slice(3):
			_line(c[0], 12, Consequences.color(c[1]), "mono")
		for row in Consequences.verdicts(before, after):
			_line(row[0], 12, Consequences.color(row[1]), "sans")
		_line(p.get("tooltip", ""), 13, FUI.TEXT)
		_line("LATER: " + LATER.get(_cat, ""), 12, Color("#fde68a"))
	var keys := FUI.hb(10)
	keys.add_child(FUI.chip("E  SELECT", FUI.SKY, true) if not is_installed else FUI.t("Installed", 12, FUI.GREEN, "mono_semi"))
	keys.add_child(FUI.grow())
	keys.add_child(FUI.t("F  less" if _details else "F  more details", 12, FUI.DIM, "mono"))
	_box.add_child(keys)
	_panel.size = Vector2.ZERO
	_panel.reset_size.call_deferred()

func _input(event: InputEvent) -> void:
	if _panel.visible and _cat != "" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_details = not _details
		_build()

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

func _process(_delta: float) -> void:
	# Fixed on the right, under the Mission Instructions panel.
	var vp := get_viewport().get_visible_rect().size
	var top := 56.0
	for n in get_tree().get_nodes_in_group("instructions"):
		if n.is_showing():
			top = n.bottom() + 10.0
	var limit := vp.y - 8.0
	for t in get_tree().get_nodes_in_group("tutor"):
		limit = vp.y - t.used_height() - 6.0
	top = minf(top, limit - _panel.size.y)
	_panel.position = Vector2(vp.x - _panel.size.x - 12, top)
	if _panel.visible:
		for n in get_tree().get_nodes_in_group("screenview"):
			if n.is_open():
				_panel.visible = false

func is_showing() -> bool:
	return _panel.visible

func width() -> float:
	return _panel.size.x
