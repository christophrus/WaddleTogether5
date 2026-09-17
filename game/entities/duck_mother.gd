extends CharacterBody3D
## The player's duck. The body never rotates around Y: the Model child turns towards
## the walking direction and CameraRig owns the camera yaw. That keeps every bit of
## direction maths trivial (5.1).

const WALK_SPEED := 4.2
const SWIM_SPEED := 2.6
const GRAVITY := 18.0
const INTERACT_RANGE := 2.3
const FLOAT_OFFSET := 0.38        # body origin above the water line: a duck sits high, ~1/3 submerged
const DABBLE_DEPTH := 0.12        # target depth below the surface, not a velocity (8.B.2); the tilt does the rest
const DABBLE_SECONDS := 3.0
const GATHER_RANGE := 11.0
const LOOK_DISTANCE := 4.0
const STEP_LIFT := 0.35

var is_in_water := false
var is_dabbling := false
var facing := Vector3(0, 0, 1)
var nearest_interactable: Node = null
var current_prompt := ""
var look_point := Vector3.ZERO
var dabble_timer := 0.0

@onready var model: Node3D = $Model
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

var _park: Node3D
var _graybox: Node3D
var _animator: Node
var _swim_teach_timer := 0.0
var _courage_teach_timer := 0.0
var _waddle_t := 0.0
var _dabble_cooldown := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("duck")
	add_to_group("saveable")
	_park = get_tree().get_first_node_in_group("park")
	# rotation_degrees in code, never hand-written matrices (8.A.1).
	spring_arm.position = Vector3(0, 1.0, 0)
	spring_arm.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	spring_arm.spring_length = 5.0
	spring_arm.add_excluded_object(get_rid())
	camera_rig.rotation_degrees.y = 180.0  # camera behind a duck facing +Z
	_build_graybox()
	var loader = load("res://game/entities/model_loader.gd").new()
	add_child(loader)
	# The model already faces +Z (its wide X extent is the wingspan, not its length).
	_animator = loader.mount(model, "res://assets/models/duck_mother.glb", _graybox, 1.0, 0.0)
	InputRouter.interact_pressed.connect(_on_interact)
	InputRouter.call_gesture.connect(_on_call_gesture)
	_rng.randomize()

# --- Movement ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var move := InputRouter.get_move_vector()
	var turn := InputRouter.get_camera_turn()
	if turn != 0.0:
		camera_rig.rotation.y -= turn * delta * 2.2
	is_in_water = _park.is_water(global_position)
	var surface: float = _park.WATER_SURFACE_Y
	var dive_held := InputRouter.is_dive_held()

	# Camera-relative direction. CameraRig yaw only, so the maths stays planar.
	var dir := Vector3.ZERO
	if move.length() > 0.01:
		var yaw := camera_rig.rotation.y
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		dir = (fwd * -move.y + right * move.x).normalized()
		facing = dir
	var speed := SWIM_SPEED if is_in_water else WALK_SPEED
	if is_dabbling:
		speed *= 0.3
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if is_in_water:
		_update_dabbling(delta, dive_held)
		var target_y := surface - DABBLE_DEPTH if is_dabbling else surface + FLOAT_OFFSET
		# Buoyancy as a damped spring towards a target height: it settles instead of sinking.
		velocity.y = (target_y - global_position.y) * 6.0 - velocity.y * 0.3
		_swim_teach_timer += delta
		if _swim_teach_timer >= 1.0 and dir != Vector3.ZERO:
			_swim_teach_timer = 0.0
			EventBus.mother_demonstrated.emit("swimming", global_position, 0.06)
	else:
		if is_dabbling:
			_end_dabble("nothing")
		velocity.y -= GRAVITY * delta
		_step_assist(delta)
	move_and_slide()
	_teach_courage(delta)
	_animate(delta)
	_scan_interactables()

## Capsule-vs-step (8.B.1): a rounded bottom pressed against a ledge yields a combined
## normal that blocks forward *and* up. If the horizontal move is blocked but would be
## free after a small lift, lift first.
func _step_assist(delta: float) -> void:
	var horiz := Vector3(velocity.x, 0, velocity.z) * delta
	if horiz.length() < 0.001 or not is_on_floor():
		return
	if test_move(global_transform, horiz):
		var lifted := global_transform.translated(Vector3(0, STEP_LIFT, 0))
		if not test_move(lifted, horiz):
			global_position.y += STEP_LIFT * 0.6
			velocity.y = maxf(velocity.y, 1.5)

func _update_dabbling(delta: float, dive_held: bool) -> void:
	_dabble_cooldown = maxf(0.0, _dabble_cooldown - delta)
	if dive_held and not is_dabbling and _dabble_cooldown <= 0.0:
		is_dabbling = true
		dabble_timer = 0.0
		AudioManager.muffled = true
		# Teaching moment at the *start*: the brood learns from watching the pose.
		EventBus.mother_demonstrated.emit("dabbling", global_position, 0.25)
	elif is_dabbling:
		dabble_timer += delta
		if not dive_held or dabble_timer >= DABBLE_SECONDS:
			var result := "nothing"
			if dabble_timer >= DABBLE_SECONDS:
				result = "keepsake" if _rng.randf() < 0.2 and GameState.mother["carried_keepsake"] == "" else "food"
			_end_dabble(result)

func _end_dabble(result: String) -> void:
	is_dabbling = false
	AudioManager.muffled = false
	_dabble_cooldown = 0.6
	if result == "food":
		GameState.mother["carried_food"] += 1
		AudioManager.play_sfx("pickup")
	elif result == "keepsake":
		GameState.mother["carried_keepsake"] = _random_keepsake()
	EventBus.dabble_finished.emit(result)

func _teach_courage(delta: float) -> void:
	_courage_teach_timer += delta
	if _courage_teach_timer < 5.0:
		return
	_courage_teach_timer = 0.0
	if _park.nest != null and global_position.distance_to(_park.nest.global_position) > 18.0:
		EventBus.mother_demonstrated.emit("courage", global_position, 0.06)

func _animate(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 0.1:
		var target := atan2(facing.x, facing.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, delta * 10.0)
	var tilt := -70.0 if is_dabbling else 0.0
	model.rotation_degrees.x = lerp(model.rotation_degrees.x, tilt, delta * 6.0)
	if _animator != null:
		_animator.set_state("dive" if is_dabbling else ("swim" if is_in_water else ("walk" if flat > 0.1 else "idle")))
	else:
		# Procedural waddle only while the graybox is up (8.C.3).
		_waddle_t += delta * flat * 2.5
		model.rotation.z = sin(_waddle_t) * 0.08 * clampf(flat, 0.0, 1.0)
		model.position.y = -0.5 + absf(sin(_waddle_t)) * 0.04 * clampf(flat, 0.0, 1.0)

# --- Interaction ---------------------------------------------------------------

func _scan_interactables() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	var prompt := ""
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or n == self:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			var p: String = n.get_interaction_prompt(self)
			if p != "":
				best = n
				best_d = d
				prompt = p
	nearest_interactable = best
	current_prompt = prompt

func _on_interact(_pid: int) -> void:
	interact()

func interact() -> void:
	_scan_interactables()
	if nearest_interactable != null:
		nearest_interactable.interact(self)

## Pickups call this when the duck walks over them.
func try_collect_pickup(pickup: Node) -> bool:
	match pickup.kind:
		"food":
			GameState.mother["carried_food"] += 1
			AudioManager.play_sfx("pickup")
			EventBus.pickup_collected.emit("food")
			# Ordinary foraging is the lesson: the brood watches where and how.
			EventBus.mother_demonstrated.emit("foraging", pickup.global_position, 0.2)
			return true
		"material":
			GameState.mother["carried_material"] += 1
			AudioManager.play_sfx("pickup")
			EventBus.pickup_collected.emit("material")
			return true
	return false

# --- Quack grammar (5.2) ---------------------------------------------------------

func _on_call_gesture(_pid: int, gesture: String) -> void:
	match gesture:
		"tap": make_call("gather")
		"double": make_call("look")
		"hold":
			# Hold resolves by *place*: at the nest it is a lullaby, elsewhere a far call.
			make_call("lullaby" if _park.nest != null and _park.nest.is_near(global_position) else "far")

func make_call(kind: String) -> void:
	look_point = global_position + facing * LOOK_DISTANCE
	AudioManager.play_sfx("duck_call", 0.0, 0.8 if kind == "far" else (0.7 if kind == "lullaby" else 1.0))
	EventBus.call_made.emit(kind)
	for d in get_tree().get_nodes_in_group("duckling"):
		d.on_call(kind, self, look_point)

func is_within_gather_range(pos: Vector3) -> bool:
	return global_position.distance_to(pos) <= GATHER_RANGE

# --- Keepsakes -----------------------------------------------------------------

func _random_keepsake() -> String:
	return ["bottle_cap", "marble", "button", "blue_glass", "pebble"][_rng.randi_range(0, 4)]

# --- Persistence ---------------------------------------------------------------

func write_state() -> void:
	GameState.mother["position"] = GameState.v3_to_arr(global_position)

func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO

# --- Graybox -------------------------------------------------------------------

func _build_graybox() -> void:
	_graybox = Node3D.new()
	_graybox.name = "Graybox"
	model.add_child(_graybox)
	var body := SphereMesh.new()
	body.radius = 0.38
	body.height = 0.6
	_part(body, Color(0.55, 0.38, 0.22), Vector3(0, 0.38, 0)).scale = Vector3(1.0, 1.0, 1.35)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.36
	var h := _part(head, Color(0.15, 0.4, 0.25), Vector3(0, 0.78, 0.4))
	var beak := BoxMesh.new()
	beak.size = Vector3(0.14, 0.07, 0.24)
	_part(beak, Color(0.95, 0.7, 0.2), Vector3(0, 0.74, 0.62))
	for side in [-1.0, 1.0]:
		var e := SphereMesh.new()
		e.radius = 0.035
		e.height = 0.07
		_part(e, Color(0.05, 0.05, 0.05), Vector3(side * 0.12, 0.85, 0.53))

func _part(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	_graybox.add_child(mi)
	return mi
