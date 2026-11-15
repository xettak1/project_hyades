class_name SaveGame
## Settings (options menu) and mission progress (Continue). Stored in the user folder:
##   user://settings.cfg  and  user://progress.json

const SETTINGS := "user://settings.cfg"
const PROGRESS := "user://progress.json"

static var tutor := true
static var play_intro := true
static var fullscreen := false
static var mouse_sens := 1.0     # multiplier on the default look speed
static var music_volume := 0.8
static var _loaded := false

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		tutor = c.get_value("game", "tutor", true)
		play_intro = c.get_value("game", "play_intro", true)
		fullscreen = c.get_value("video", "fullscreen", false)
		mouse_sens = c.get_value("input", "mouse_sens", 1.0)
		music_volume = c.get_value("audio", "music", 0.8)
	apply()

static func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("game", "tutor", tutor)
	c.set_value("game", "play_intro", play_intro)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("input", "mouse_sens", mouse_sens)
	c.set_value("audio", "music", music_volume)
	c.save(SETTINGS)
	apply()

static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	if fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## Called when a level starts: remember where the player is and what they designed.
static func save_progress(index: int) -> void:
	var d := {"version": 1, "index": index, "mission": MissionState.mission_id,
		"picks": MissionState.picks, "orbit": MissionState.orbit_id, "rocket": MissionState.rocket_id,
		"lifetime": MissionState.lifetime_years, "results": MissionState.level_results,
		"tutor": MissionState.tutor_enabled, "time": Time.get_datetime_string_from_system(false, true)}
	var f := FileAccess.open(PROGRESS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

static func clear_progress() -> void:
	if FileAccess.file_exists(PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))

static func progress() -> Dictionary:
	if not FileAccess.file_exists(PROGRESS):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS))
	return d if d is Dictionary and d.has("index") else {}

## Restore a saved mission into MissionState. Returns the level index to resume, or -1.
static func restore() -> int:
	var d := progress()
	if d.is_empty():
		return -1
	MissionState.start_mission(String(d.get("mission", "flood_watch")))
	var picks: Dictionary = d.get("picks", {})
	for k in picks:
		MissionState.picks[k] = String(picks[k])
	MissionState.orbit_id = String(d.get("orbit", MissionState.orbit_id))
	MissionState.rocket_id = String(d.get("rocket", MissionState.rocket_id))
	MissionState.lifetime_years = int(d.get("lifetime", MissionState.lifetime_years))
	MissionState.level_results = d.get("results", {})
	MissionState.tutor_enabled = bool(d.get("tutor", true))
	MissionState.tutor_steps = {}
	MissionState.design_changed.emit()
	return int(d["index"])
