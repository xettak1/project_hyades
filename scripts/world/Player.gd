extends CharacterBody3D
## First-person player: WASD to walk, mouse to look, E or left-click to use things.

const SPEED := 4.0
const SENS := 0.0025
const GRAVITY := 9.8

var cam: Camera3D
var ray: RayCast3D
var focused: Object = null
var frozen := false   # true while a screen is open full view

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)

	cam = Camera3D.new()
	cam.position.y = 1.6
	cam.fov = 75.0
	cam.current = true
	add_child(cam)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	ray.add_exception(self)
	cam.add_child(ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func teleport(pos: Vector3, yaw_deg: float) -> void:
	global_position = pos
	rotation_degrees.y = yaw_deg
	cam.rotation = Vector3.ZERO
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		cam.rotate_x(-event.relative.y * SENS)
		cam.rotation.x = clampf(cam.rotation.x, -1.4, 1.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			use()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			use()

func use() -> void:
	if focused and focused.has_method("interact"):
		focused.interact()

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	dir = (transform.basis * dir).normalized() * SPEED
	velocity.x = dir.x
	velocity.z = dir.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_focus()

func _update_focus() -> void:
	var hit: Object = ray.get_collider() if ray.is_colliding() else null
	if hit != null and not hit.has_method("interact"):
		hit = null
	if hit != focused:
		if focused and is_instance_valid(focused) and focused.has_method("on_focus"):
			focused.on_focus(false)
		focused = hit
		if focused and focused.has_method("on_focus"):
			focused.on_focus(true)
	var prompt := ""
	if focused and focused.has_method("get_prompt"):
		prompt = focused.get_prompt()
	get_tree().call_group("hud", "set_prompt", prompt)
