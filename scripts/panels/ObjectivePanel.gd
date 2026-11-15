extends VBoxContainer
## Level objective screen: story, what the player decides here, and what was carried in.

var info: Dictionary = {}   # {level, title, goal, story, decisions: [], note}

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var lv: Dictionary = LevelFlow.current() if LevelFlow.index >= 0 else {"n": info.get("level", 0), "title": info.get("title", "")}
	add_child(FUI.t("LEVEL %d · %s" % [lv["n"], lv["title"]], 15, FUI.SKY, "mono_semi"))
	add_child(FUI.t(info.get("goal", ""), 30, FUI.WHITE, "sans_semi"))
	var story := FUI.t(info.get("story", ""), 17, FUI.TEXT2)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(story)
	add_child(FUI.hline())
	add_child(FUI.t("YOUR DECISIONS IN THIS LEVEL", 13, FUI.AMBER, "mono_semi"))
	for d in info.get("decisions", []):
		var l := FUI.t("•  " + d, 16, FUI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)
	var carry := LevelFlow.carry_line()
	if carry != "":
		add_child(FUI.hline())
		var c := FUI.t(carry, 14, FUI.MUTED, "mono")
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(c)
	if info.get("note", "") != "":
		var n := FUI.t(info["note"], 13, FUI.DIM, "mono")
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(n)
