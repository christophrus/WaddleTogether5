extends CharacterBody3D
## A duckling: composed from components, driven by a small state machine. Its record
## in GameState is the single source of truth (`data`), so saving is free and every
## behaviour reads the same values the learning component writes.
##
## What the player sees is *only* behaviour: an untaught duckling waddles past food
## as if it were nothing; one that has never seen the water stops at the shore and
## peeps after its swimming mother. That is the whole display (rule 3.1).

enum State { NEST, FOLLOW, SLEEP, LOOK, ROAM, FETCH_FOOD, RESCUE, DABBLE, HELPER }

const GRAVITY := 18.0
const NEST_WANDER := 0.9
const WARM_DISTANCE := 5.0
const SLEEP_NEST_RADIUS := 3.0
const FOOD_DETOUR := 4.0
const ROAM_RADIUS := 9.0

var data: Dictionary
var temperament: Resource
var state: State = State.NEST
var is_in_water := false
var lullaby_sleep := false
var alone_since := -1.0
var next_peep_in := 6.0
var carried_food := false
var carried_keepsake := ""
var peep_pitch := 1.0

@onready var model: Node3D = $Model
@onready var needs: Node = $Needs
@onready var growth: Node = $Growth
@onready var follow: Node = $Follow
@onready var learning: Node = $Learning

var _park: Node3D
var _graybox: Node3D
var _animator: Node
var _target := Vector3.ZERO
var _roam_target := Vector3.ZERO
var _roam_timer := 0.0
var _dabble_timer := 0.0
var _dabble_cooldown := 0.0
var _rescue_target: Node3D
var _fetch_target: Node3D
var _rng := RandomNumberGenerator.new()
var _shore_peep_t := 0.0
var _waddle_t := 0.0
var _helper_teach_t := 0.0
var _wander_t := 0.0
var _wander_off := Vector3.ZERO
var _tint_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("duckling")
	add_to_group("saveable")
	add_to_group("interactable")
	_park = get_tree().get_first_node_in_group("park")
	_rng.seed = int(data["id"]) * 7919
	temperament = load("res://game/data/temperaments.gd").get_by_id(data["temperament"])
	needs.bind(data)
	growth.bind(data)
	learning.bind(data, self, temperament)
	if temperament != null:
		follow.follow_distance = temperament.follow_distance
		peep_pitch = temperament.pitch
	_build_graybox()
	var loader = load("res://game/entities/model_loader.gd").new()
	add_child(loader)
	_animator = loader.mount(model, "res://assets/models/duckling.glb", _graybox, 0.6, 0.0, temperament.color_tint if temperament != null else Color.WHITE)
	_apply_visuals()
	state = State.NEST if bool(data["nest_bound"]) else State.FOLLOW
	if bool(data.get("is_helper", false)):
		state = State.HELPER
	EventBus.duckling_grew.connect(func(id, _s): if id == int(data["id"]): _apply_visuals())
	EventBus.night_fell.connect(func(): alone_since = -1.0)

func _apply_visuals() -> void:
	var s := 1.0
	if temperament != null:
		s = temperament.scale_mult
	growth.apply_visuals(model, s)
	if _tint_mat != null:
		_tint_mat.albedo_color = growth.stage().color * (temperament.color_tint if temperament != null else Color.WHITE)

# --- Main loop -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _park == null or _park.mother == null:
		return
	needs.tick(delta)
	is_in_water = _park.is_water(global_position)
	var mother: CharacterBody3D = _park.mother
	var planar := Vector3.ZERO
	_dabble_cooldown = maxf(0.0, _dabble_cooldown - delta)

	_update_sleep(mother)
	match state:
		State.NEST: planar = _do_nest(delta)
		State.FOLLOW: planar = _do_follow(delta, mother)
		State.SLEEP: planar = Vector3.ZERO
		State.LOOK: planar = _do_look(delta, mother)
		State.ROAM: planar = _do_roam(delta, mother)
		State.FETCH_FOOD: planar = _do_fetch(delta, mother)
		State.RESCUE: planar = _do_rescue(delta, mother)
		State.DABBLE: planar = _do_dabble(delta)
		State.HELPER: planar = _do_helper(delta, mother)

	planar = _gate_water(planar)
	velocity.x = planar.x
	velocity.z = planar.z
	if is_in_water:
		var target_y: float = _park.WATER_SURFACE_Y + 0.08
		if state == State.DABBLE:
			target_y -= 0.2
		velocity.y = (target_y - global_position.y) * 6.0 - velocity.y * 0.3
	else:
		velocity.y -= GRAVITY * delta
		_step_assist(delta)
	move_and_slide()
	_update_warmth(delta, mother)
	_animate(delta, planar)

## Same capsule-vs-step fix as the mother (8.B.1b): two bodies sharing a movement
## style share the fix.
func _step_assist(delta: float) -> void:
	var horiz := Vector3(velocity.x, 0, velocity.z) * delta
	if horiz.length() < 0.001 or not is_on_floor():
		return
	if test_move(global_transform, horiz):
		var lifted := global_transform.translated(Vector3(0, 0.25, 0))
		if not test_move(lifted, horiz):
			global_position.y += 0.15
			velocity.y = maxf(velocity.y, 1.2)

# --- States --------------------------------------------------------------------

func _do_nest(delta: float) -> Vector3:
	# Nest-bound hatchlings potter around the rim, never further.
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = _rng.randf_range(1.5, 4.0)
		var a := _rng.randf() * TAU
		_wander_off = Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.3, NEST_WANDER)
	var target: Vector3 = _park.nest.global_position + _wander_off
	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if to.length() < 0.15:
		return Vector3.ZERO
	return to.normalized() * 0.8

func _do_follow(delta: float, mother: Node3D) -> Vector3:
	# Opportunities first: they are what makes a taught duckling look taught.
	if learning.has("foraging", 1) and needs.is_hungry() and _dabble_cooldown <= 0.0:
		var food := _nearest_pickup("food", FOOD_DETOUR)
		if food != null:
			_fetch_target = food
			state = State.FETCH_FOOD
			return Vector3.ZERO
	if learning.has("courage", 2):
		var stray := _find_stray(mother)
		if stray != null:
			_rescue_target = stray
			state = State.RESCUE
			return Vector3.ZERO
	if learning.has("courage", 1) and _rng.randf() < temperament.roam_chance * delta and not Daytime.is_night():
		var a := _rng.randf() * TAU
		_roam_target = mother.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.0, ROAM_RADIUS)
		_roam_timer = 8.0
		state = State.ROAM
	if learning.has("dabbling", 1) and is_in_water and mother.is_dabbling and _dabble_cooldown <= 0.0:
		state = State.DABBLE
		_dabble_timer = 0.0
		return Vector3.ZERO
	var target: Vector3 = mother.global_position
	return follow.compute(global_position, target, _siblings(), delta)

func _do_look(delta: float, mother: Node3D) -> Vector3:
	var to := Vector3(_target.x - global_position.x, 0, _target.z - global_position.z)
	if to.length() < 0.5:
		# Arrived: if there is food here, eating it is the lesson made concrete.
		var food := _nearest_pickup("food", 1.5)
		if food != null:
			_eat(food)
			learning._on_demonstrated("foraging", global_position, 0.15)
		state = State.FOLLOW
		return Vector3.ZERO
	return to.normalized() * follow.speed * 0.9

func _do_roam(delta: float, mother: Node3D) -> Vector3:
	_roam_timer -= delta
	var to := Vector3(_roam_target.x - global_position.x, 0, _roam_target.z - global_position.z)
	if to.length() < 0.6 or _roam_timer <= 0.0:
		if carried_keepsake == "" and _rng.randf() < 0.35:
			carried_keepsake = ["bottle_cap", "marble", "button", "blue_glass", "pebble"][_rng.randi_range(0, 4)]
		state = State.FOLLOW
		return Vector3.ZERO
	if global_position.distance_to(mother.global_position) > ROAM_RADIUS + 4.0:
		state = State.FOLLOW
	return to.normalized() * follow.speed * 0.7

func _do_fetch(delta: float, mother: Node3D) -> Vector3:
	if _fetch_target == null or not is_instance_valid(_fetch_target) or not _fetch_target.active:
		state = State.FOLLOW
		return Vector3.ZERO
	var to := Vector3(_fetch_target.global_position.x - global_position.x, 0, _fetch_target.global_position.z - global_position.z)
	if to.length() < 0.5:
		if learning.has("foraging", 2) and not needs.is_hungry():
			_fetch_target.collect()
			carried_food = true
		else:
			_eat(_fetch_target)
		_dabble_cooldown = 2.0
		state = State.FOLLOW
		return Vector3.ZERO
	if global_position.distance_to(mother.global_position) > 12.0:
		state = State.FOLLOW
	return to.normalized() * follow.speed

func _do_rescue(delta: float, mother: Node3D) -> Vector3:
	if _rescue_target == null or not is_instance_valid(_rescue_target):
		state = State.FOLLOW
		return Vector3.ZERO
	var to := Vector3(_rescue_target.global_position.x - global_position.x, 0, _rescue_target.global_position.z - global_position.z)
	if to.length() < 1.0:
		_rescue_target.on_call("gather", mother, mother.global_position, true)
		state = State.FOLLOW
		return Vector3.ZERO
	return to.normalized() * follow.speed

func _do_dabble(delta: float) -> Vector3:
	_dabble_timer += delta
	if _dabble_timer > 2.5 or not is_in_water:
		_dabble_cooldown = 4.0
		state = State.FOLLOW
	return Vector3.ZERO

func _do_helper(delta: float, mother: Node3D) -> Vector3:
	# Grown helpers loosely follow, and when they forage they *teach* the same way the
	# mother does — the same signal, so the learners need no new code (5.10).
	_helper_teach_t += delta
	var food := _nearest_pickup("food", 5.0)
	if food != null and _helper_teach_t > 6.0:
		var to := Vector3(food.global_position.x - global_position.x, 0, food.global_position.z - global_position.z)
		if to.length() < 0.5:
			_helper_teach_t = 0.0
			food.collect()
			EventBus.mother_demonstrated.emit("foraging", food.global_position, 0.2)
			return Vector3.ZERO
		return to.normalized() * follow.speed * 0.8
	var stray := _find_stray(mother)
	if stray != null and stray != self:
		var to := Vector3(stray.global_position.x - global_position.x, 0, stray.global_position.z - global_position.z)
		if to.length() < 1.0:
			stray.on_call("gather", mother, mother.global_position, true)
		else:
			return to.normalized() * follow.speed
	var f = follow.compute(global_position, mother.global_position, [], delta)
	if global_position.distance_to(mother.global_position) < 4.0:
		return Vector3.ZERO
	return f

# --- Water gating --------------------------------------------------------------

## A duckling that has never been shown the water refuses to enter it and peeps after
## the swimming mother. This *is* the swimming display.
func _gate_water(planar: Vector3) -> Vector3:
	if learning.has("swimming", 1) or state == State.HELPER:
		return planar
	var next := global_position + planar * 0.25
	if _park.is_water(next):
		_shore_peep_t -= get_physics_process_delta_time()
		if _shore_peep_t <= 0.0:
			_shore_peep_t = 2.5
			AudioManager.peep(global_position, peep_pitch)
		if is_in_water:
			var shore: Vector3 = _park.pond.nearest_shore(global_position)
			return Vector3(shore.x - global_position.x, 0, shore.z - global_position.z).normalized() * 1.5
		return Vector3.ZERO
	return planar

# --- Sleep (5.6, 8.G.1) --------------------------------------------------------

func _update_sleep(mother: Node3D) -> void:
	var at_nest: bool = _park.nest.global_position.distance_to(global_position) <= SLEEP_NEST_RADIUS
	var warm := global_position.distance_to(mother.global_position) <= WARM_DISTANCE
	if state == State.SLEEP:
		# Both routes into sleep share the same exit: the mother walks away (8.G.3).
		if not warm:
			state = State.FOLLOW if not bool(data["nest_bound"]) else State.NEST
			lullaby_sleep = false
		return
	if bool(data["nest_bound"]):
		return
	# Passive sleep needs warm AND actually at the nest — otherwise the walk home
	# would mean nothing (8.G.1).
	if Daytime.is_night() and warm and at_nest and state == State.FOLLOW:
		_fall_asleep()

func _fall_asleep() -> void:
	state = State.SLEEP
	velocity = Vector3.ZERO
	EventBus.duckling_slept.emit(int(data["id"]))

# --- Warmth: the night peep (5.6) ----------------------------------------------

func _update_warmth(delta: float, mother: Node3D) -> void:
	if not Daytime.is_night() or state == State.SLEEP or bool(data["nest_bound"]):
		alone_since = -1.0
		return
	var warm := global_position.distance_to(mother.global_position) <= WARM_DISTANCE
	if warm:
		alone_since = -1.0   # silent the moment you arrive
		return
	if alone_since < 0.0:
		alone_since = 0.0
		next_peep_in = 6.0
	alone_since += delta
	next_peep_in -= delta
	if next_peep_in <= 0.0:
		AudioManager.peep(global_position, peep_pitch)
		# Interval ramps from 6 s down to 2 s over a minute alone. No number, no penalty.
		next_peep_in = lerpf(6.0, 2.0, clampf(alone_since / 60.0, 0.0, 1.0))

# --- Calls ---------------------------------------------------------------------

func on_call(kind: String, mother: Node3D, point: Vector3, forced := false) -> void:
	if bool(data["nest_bound"]):
		if kind == "lullaby":
			_fall_asleep()
			lullaby_sleep = true
		return
	match kind:
		"gather":
			if forced or mother.is_within_gather_range(global_position):
				_wake()
				state = State.FOLLOW
		"look":
			if mother.is_within_gather_range(global_position):
				_wake()
				_target = point
				state = State.LOOK
		"far":
			_wake()
			state = State.FOLLOW
		"lullaby":
			if _park.nest.is_near(global_position):
				_fall_asleep()
				lullaby_sleep = true

func _wake() -> void:
	if state == State.SLEEP:
		state = State.FOLLOW
		lullaby_sleep = false

# --- Interaction ---------------------------------------------------------------

func get_interaction_prompt(duck: Node) -> String:
	if bool(data["nest_bound"]):
		return ""   # hatchlings are fed through the nest
	if GameState.mother["carried_food"] > 0 and needs.is_hungry():
		return "Füttern"
	if carried_food:
		return "Futter annehmen"
	return "Kuscheln"

func interact(duck: Node) -> void:
	if GameState.mother["carried_food"] > 0 and needs.is_hungry():
		GameState.mother["carried_food"] -= 1
		receive_feeding()
		return
	if carried_food:
		carried_food = false
		GameState.mother["carried_food"] += 1
		AudioManager.play_sfx("pickup")
		return
	cuddle()

func receive_feeding() -> void:
	needs.feed()
	growth.feed()
	AudioManager.play_sfx("feed")
	EventBus.duckling_fed.emit(int(data["id"]))

func cuddle() -> void:
	needs.cuddle()
	EventBus.duckling_cuddled.emit(int(data["id"]))
	if data["name"] == "":
		var suggestion: String = temperament.name_suggestions[_rng.randi_range(0, temperament.name_suggestions.size() - 1)] if temperament != null else "Piep"
		EventBus.naming_requested.emit(int(data["id"]), suggestion)

func set_duck_name(n: String) -> void:
	data["name"] = n
	EventBus.duckling_named.emit(int(data["id"]), n)

## Called by the nest when the family comes home with a find.
func deliver_keepsake() -> String:
	var k := carried_keepsake
	carried_keepsake = ""
	return k

func promote_to_helper() -> void:
	data["is_helper"] = true
	state = State.HELPER
	EventBus.helper_promoted.emit(int(data["id"]))

# --- Helpers -------------------------------------------------------------------

func _eat(pickup: Node) -> void:
	pickup.collect()
	needs.feed(0.4)
	AudioManager.play_sfx_at("feed", global_position, peep_pitch)

func _nearest_pickup(kind: String, radius: float) -> Node:
	var best: Node = null
	var best_d := radius
	for p in get_tree().get_nodes_in_group("pickup"):
		if p.kind != kind or not p.active:
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < best_d:
			best = p
			best_d = d
	return best

func _siblings() -> Array:
	return get_tree().get_nodes_in_group("duckling").filter(func(d): return d != self and not d.data["nest_bound"] and d.global_position.distance_to(global_position) < 4.0)

func _find_stray(mother: Node3D) -> Node3D:
	for d in get_tree().get_nodes_in_group("duckling"):
		if d == self or d.data["nest_bound"] or d.state == State.SLEEP or d.state == State.HELPER:
			continue
		if d.global_position.distance_to(mother.global_position) > 14.0:
			return d
	return null

func display_name() -> String:
	return data["name"] if data["name"] != "" else "Küken"

func write_state() -> void:
	data["position"] = GameState.v3_to_arr(global_position)

func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO

func _animate(delta: float, planar: Vector3) -> void:
	var flat := planar.length()
	if flat > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(planar.x, planar.z), delta * 10.0)
	var tilt := -70.0 if state == State.DABBLE else 0.0
	model.rotation_degrees.x = lerp(model.rotation_degrees.x, tilt, delta * 6.0)
	var lying := state == State.SLEEP
	model.rotation_degrees.z = lerp(model.rotation_degrees.z, 12.0 if lying else 0.0, delta * 4.0)
	if _animator != null:
		var s := "idle"
		if state == State.DABBLE: s = "dive"
		elif state == State.SLEEP: s = "idle"
		elif is_in_water: s = "swim"
		elif flat > 0.05: s = "walk"
		_animator.set_state(s)
	else:
		_waddle_t += delta * flat * 4.0
		model.rotation.z += sin(_waddle_t) * 0.1 * clampf(flat, 0.0, 1.0)

func _build_graybox() -> void:
	_graybox = Node3D.new()
	_graybox.name = "Graybox"
	model.add_child(_graybox)
	_tint_mat = StandardMaterial3D.new()
	_tint_mat.albedo_color = Color(0.98, 0.88, 0.35)
	_tint_mat.roughness = 1.0
	var body := SphereMesh.new()
	body.radius = 0.2
	body.height = 0.32
	var b := MeshInstance3D.new()
	b.mesh = body
	b.material_override = _tint_mat
	b.position = Vector3(0, 0.2, 0)
	b.scale = Vector3(1, 1, 1.3)
	_graybox.add_child(b)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.24
	var h := MeshInstance3D.new()
	h.mesh = head
	h.material_override = _tint_mat
	h.position = Vector3(0, 0.42, 0.18)
	_graybox.add_child(h)
	var beak := BoxMesh.new()
	beak.size = Vector3(0.08, 0.04, 0.12)
	var bk := MeshInstance3D.new()
	bk.mesh = beak
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.95, 0.6, 0.2)
	bk.material_override = bm
	bk.position = Vector3(0, 0.4, 0.3)
	_graybox.add_child(bk)
	for side in [-1.0, 1.0]:
		var e := SphereMesh.new()
		e.radius = 0.025
		e.height = 0.05
		var em := MeshInstance3D.new()
		em.mesh = e
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.05, 0.05, 0.05)
		em.material_override = emat
		em.position = Vector3(side * 0.07, 0.47, 0.27)
		_graybox.add_child(em)
