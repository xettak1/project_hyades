extends Node3D
func _ready() -> void:
	var e := ModelLib.fit("earth", 2.0, "center")
	add_child(e)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color(1, 1, 1)
	en.ambient_light_energy = 1.0
	env.environment = en
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute("/tmp/probe")
	for d in [["px", Vector3(4, 0, 0)], ["nx", Vector3(-4, 0, 0)], ["pz", Vector3(0, 0, 4)], ["nz", Vector3(0, 0, -4)], ["py", Vector3(0, 4, 0.01)]]:
		cam.position = d[1]
		cam.look_at(Vector3.ZERO, Vector3.UP)
		for i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/probe/%s.png" % d[0])
	get_tree().quit()
