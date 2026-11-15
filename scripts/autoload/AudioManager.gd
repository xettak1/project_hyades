extends Node

const AUDIO_DIR := "res://audio"

var _music_player := AudioStreamPlayer.new()
var _launch_player := AudioStreamPlayer.new()
var _music_paths: Array[String] = []
var _launch_path := ""

func _ready() -> void:
	add_child(_music_player)
	add_child(_launch_player)
	_music_player.finished.connect(_play_random_music)
	_refresh_audio_files()
	_play_random_music()

func play_launch() -> void:
	if _launch_path.is_empty():
		push_warning("Audio file launch1 was not found in %s." % AUDIO_DIR)
		return
	var stream := ResourceLoader.load(_launch_path) as AudioStream
	if stream == null:
		push_error("Audio file launch1 could not be loaded: %s" % _launch_path)
		return
	_music_player.stop()
	_launch_player.stream = stream
	_launch_player.play()

func resume_music() -> void:
	if not _launch_player.playing:
		_play_random_music()

func _refresh_audio_files() -> void:
	var directory := DirAccess.open(AUDIO_DIR)
	if directory == null:
		push_warning("Audio directory was not found: %s" % AUDIO_DIR)
		return
	for file_name in directory.get_files():
		var base_name := file_name.get_basename().to_lower()
		var path := AUDIO_DIR.path_join(file_name)
		if base_name == "launch1":
			_launch_path = path
		elif base_name in ["space1", "space2"]:
			_music_paths.append(path)

func _play_random_music() -> void:
	if _music_paths.is_empty():
		push_warning("No space1 or space2 audio file was found in %s." % AUDIO_DIR)
		return
	var path: String = _music_paths[randi_range(0, _music_paths.size() - 1)]
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		push_error("Background audio could not be loaded: %s" % path)
		return
	_music_player.stream = stream
	_music_player.play()
