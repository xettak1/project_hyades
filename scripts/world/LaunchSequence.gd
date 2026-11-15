extends Node
## LAUNCH SEQUENCE (about 17 s, SPACE skips): countdown in launch control, ignition, smoke and flames,
## liftoff seen through the windows, then a chase camera climbing through the clouds while the sky
## turns from blue to black. Hands the Level 1 results to Level 2 at the end.

var lab
var complex
var results: Dictionary = {}
var t := 0.0
var _chase: Camera3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _sky_top: Color
var _sky_hor: Color
var _phase := ""
var _done := false
var _alt := 0.0
var _vel := 0.0

func start() -> void:
	_sky = lab.outdoor["sky"]
	_env = lab.outdoor["env"]
	_sky_top = _sky.sky_top_color
	_sky_hor = _sky.sky_horizon_color
	for g in ["instrumentation", "decision", "progress_bar"]:
		for n in get_tree().get_nodes_in_group(g):
			n.visible = false
	get_tree().call_group("screenview", "close")
	lab.player.frozen = true
	# Stand at the window, facing the pad
	var at: Vector3 = Vector3(-4.0, 0.1, lab.hz - 1.6)
	var to_pad: Vector3 = complex.to_global(complex.pad) - at
	lab.player.teleport(at, rad_to_deg(atan2(-to_pad.x, -to_pad.z)))
	lab.player.cam.rotation.x = deg_to_rad(10.0)
	_chase = Camera3D.new()
	_chase.far = 6000.0
	_chase.fov = 60.0
	lab.add_child(_chase)
	_say("T minus 3... All systems are go. The spacecraft you built is on top of that rocket.")

func _say(text: String) -> void:
	get_tree().call_group("tutor", "react", text, "good")

func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	if t < 3.0:
		lab.hud.show_message("T - %d" % (3 - int(t)), 0.5, FUI.AMBER)
	elif _phase == "":
		_phase = "ignition"
		complex.flame.visible = true
		complex.exhaust.emitting = true
		complex.smoke.emitting = true
		lab.hud.show_message("IGNITION", 1.2, FUI.AMBER)
		_say("Ignition! Those engines are burning tonnes of fuel every second.")
	if _phase == "ignition" or _phase == "climb" or _phase == "chase":
		complex.glow.light_energy = 8.0 + randf() * 3.0
		complex.flame.scale = Vector3.ONE * (0.92 + randf() * 0.16)
	if t > 4.5:
		if _phase == "ignition":
			_phase = "climb"
			lab.hud.show_message("LIFTOFF!", 2.0, FUI.GREEN)
			_say("Liftoff! We're on our way. Everything we decided in this room is now flying.")
		var acc := 4.0 if t < 10.0 else 40.0
		_vel += acc * delta
		_alt += _vel * delta
		complex.rocket.position.y = 0.6 + _alt
		complex.arm.rotation_degrees.y = minf((t - 4.5) * 25.0, 75.0)
		if t > 6.0:
			complex.smoke.emitting = t < 9.0
	if t > 10.0 and _phase == "climb":
		_phase = "chase"
		_chase.current = true
		_say("We're climbing through the clouds. The sky gets darker as the air gets thinner.")
	if _phase == "chase":
		var top: Vector3 = complex.rocket.global_position
		_chase.global_position = top + Vector3(26.0, -40.0, 30.0)
		_chase.look_at(top + Vector3(0, complex.rocket_h * 0.6, 0), Vector3.UP)
		var k := clampf((_alt - 250.0) / 1100.0, 0.0, 1.0)
		_sky.sky_top_color = _sky_top.lerp(Color(0.0, 0.0, 0.02), k)
		_sky.sky_horizon_color = _sky_hor.lerp(Color(0.05, 0.12, 0.35), k)
		_env.fog_density = lerpf(0.0006, 0.0, k)
	if t > 17.0:
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	LevelFlow.complete(results)

func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		_finish()
