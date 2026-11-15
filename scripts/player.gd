extends CharacterBody3D
## Chi tiene in mano la videocamera: prima persona, camminata lenta, corsa con stamina.
## Stamina "da persona normale": ~7 s di corsa piena, si ricarica in ~5 s da fermo
## (più lentamente camminando). Se la svuoti sei senza fiato e non puoi correre
## finché non torna al 35%.

signal step

const WALK_SPEED := 2.2
const SPRINT_SPEED := 4.4
const TIRED_SPEED := 1.9
const SPRINT_DRAIN := 1.0 / 7.0
const REGEN_IDLE := 1.0 / 5.0
const REGEN_WALK := 1.0 / 8.0
const REGEN_DELAY := 1.1
const RECOVER_AT := 0.35

var camera: Camera3D
var yaw := 0.0
var pitch := 0.0
var locked := false
var look_locked := false

var stamina := 1.0
var exhausted := false
var sprinting := false
var sprint_toggle_on := false

var _bob := 0.0
var _t := 0.0
var _dist := 0.0
var _regen_wait := 0.0
var _speed := 0.0
var _fov_kick := 0.0


func setup(pos: Vector3, yaw0: float) -> void:
	position = pos
	yaw = yaw0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.fov = 68.0
	camera.near = 0.12
	camera.far = 260.0
	add_child(camera)
	floor_snap_length = 0.3


func look_at_point(p: Vector3) -> void:
	var d := p - global_position
	yaw = atan2(-d.x, -d.z)
	var horiz := Vector2(d.x, d.z).length()
	pitch = atan2(d.y - 1.55, horiz)


func _unhandled_input(event: InputEvent) -> void:
	if look_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens := 0.0022 * float(Settings.g("sens"))
		var inv := -1.0 if bool(Settings.g("invert_y")) else 1.0
		yaw -= mm.relative.x * sens
		pitch = clampf(pitch - mm.relative.y * sens * inv, -1.2, 1.2)


func _physics_process(delta: float) -> void:
	_t += delta
	rotation.y = yaw
	camera.rotation.x = pitch
	var bob_on := bool(Settings.g("head_bob"))
	camera.rotation.z = (sin(_t * 0.7) * 0.006 + sin(_t * 1.9) * 0.003) if bob_on else 0.0

	var input := Vector2.ZERO
	if not locked:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			input.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			input.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			input.x += 1.0
	var moving := input.length() > 0.0

	# --- stamina
	var want := false
	if bool(Settings.g("sprint_toggle")):
		want = sprint_toggle_on
	else:
		want = Input.is_physical_key_pressed(KEY_SHIFT)
	sprinting = want and moving and input.y < 0.0 and not locked and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - SPRINT_DRAIN * delta)
		_regen_wait = REGEN_DELAY
		if stamina <= 0.0:
			exhausted = true
			sprint_toggle_on = false
	else:
		if _regen_wait > 0.0:
			_regen_wait -= delta
		else:
			stamina = minf(1.0, stamina + (REGEN_WALK if moving else REGEN_IDLE) * delta)
		if exhausted and stamina >= RECOVER_AT:
			exhausted = false
	if not moving:
		sprint_toggle_on = false

	var target_speed := 0.0
	if moving:
		target_speed = SPRINT_SPEED if sprinting else (TIRED_SPEED if exhausted else WALK_SPEED)
	_speed = move_toward(_speed, target_speed, delta * 9.0)

	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length() > 0.0:
		dir = dir.normalized()
	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * delta
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_dist += moved
	_bob += moved * 3.6
	var amp := (0.05 if sprinting else 0.03) if bob_on else 0.0
	camera.position.y = 1.55 + sin(_bob) * amp
	camera.position.x = cos(_bob * 0.5) * amp * 0.7
	_fov_kick = move_toward(_fov_kick, 6.0 if sprinting else 0.0, delta * 20.0)
	camera.fov = float(Settings.g("fov")) + _fov_kick
	camera.far = Settings.view_far()
	if _dist > (1.5 if sprinting else 1.1):
		_dist = 0.0
		step.emit()
