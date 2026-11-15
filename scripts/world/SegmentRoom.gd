extends Node3D
## Base for the walkable rooms of Levels 2-4 (Space, Ground and User segments).
## Builds the room, the player, HUD, pause menu, full-screen view and the Mission Control Console strip.
## Each level script extends this and fills in _build_level() with its screens and controls,
## then calls finish_level(results) when the player completes it.

const Player := preload("res://scripts/world/Player.gd")
const HUD := preload("res://scripts/world/HUD.gd")
const PauseMenu := preload("res://scripts/world/PauseMenu.gd")
const ScreenView := preload("res://scripts/world/ScreenView.gd")
const Screen3D := preload("res://scripts/world/Screen3D.gd")
const Button3D := preload("res://scripts/world/Button3D.gd")
const Instruments := preload("res://scripts/ui/InstrumentationPanel.gd")
const ProgressBarUI := preload("res://scripts/ui/MissionProgressBar.gd")
const TutorManager := preload("res://scripts/ui/TutorDialogueManager.gd")

var R := Vector3(16, 6, 14)
var accent := FUI.SKY
var floor_tint := Color.WHITE
var light := Color(0.92, 0.95, 1.0)
var title := ""
var player: CharacterBody3D
var hud: CanvasLayer
var spawn := Vector3.ZERO

func _ready() -> void:
	if MissionState.picks.is_empty():
		MissionState.start_mission("flood_watch")
	MissionState.phase = LevelFlow.current_id() if LevelFlow.index >= 0 else "segment"
	add_to_group("level")
	MissionState.live = {}
	_configure()
	_build_world()
	spawn = Vector3(0, 0.1, R.z / 2 - 2.5)
	_build_level()
	hud = HUD.new()
	add_child(hud)
	player = Player.new()
	add_child(player)
	player.teleport(spawn, 0.0)
	add_child(PauseMenu.new())
	var sv := ScreenView.new()
	sv.player = player
	add_child(sv)
	add_child(Instruments.new())
	add_child(ProgressBarUI.new())
	add_child(preload("res://scripts/world/DecisionCard.gd").new())
	var instr := preload("res://scripts/ui/MissionInstructions.gd").new()
	instr.room = self
	add_child(instr)
	var tutor := TutorManager.new()
	tutor.room = self
	add_child(tutor)

## Override: set R, accent, title, floor_tint.
func _configure() -> void:
	pass

## Override: the building and the world outside it. Default: a closed worn-metal room.
func _build_world() -> void:
	RoomKit.environment(self, R, light, 0.9)
	RoomKit.shell(self, R, floor_tint)
	if title != "":
		RoomKit.sign(self, title, Vector3(0, R.y - 0.45, -R.z / 2 + 0.05), 0.0, 72, accent)

## Override: add screens, buttons and props.
func _build_level() -> void:
	pass

# ---------------------------------------------------------------- helpers for level scripts
func screen(name: String, heading: String, size_m: Vector2, pixels: Vector2i, pos: Vector3, yaw: float, panel: Control) -> Node3D:
	var s := Screen3D.new()
	s.position = pos
	s.rotation_degrees.y = yaw
	add_child(s)
	s.setup(size_m, pixels, heading, accent, name)
	if panel:
		s.set_panel(panel)
	return s

func desk(pos: Vector3, size: Vector3 = Vector3(3.0, 1.0, 1.0)) -> void:
	RoomKit.solid(self, size, pos + Vector3(0, size.y / 2.0 - 0.0, 0), PartModels.mat(Color(0.18, 0.2, 0.25), 0.5, 0.4))

func button(text: String, color: Color, action: Callable, pos: Vector3, yaw: float = 0.0, big := false) -> Node3D:
	var b := Button3D.new()
	b.position = pos
	b.rotation_degrees.y = yaw
	add_child(b)
	b.setup(text, color, action, big)
	return b

## End this level and hand its results to the next one.
func finish_level(results: Dictionary) -> void:
	get_tree().call_group("screenview", "close")
	get_tree().call_group("tutor", "on_event", "level_done")
	hud.show_message("LEVEL COMPLETE", 2.0, FUI.GREEN)
	LevelFlow.complete(results)
