extends Node3D
## A shy park animal. Comfort distance shrinks while the family idles nearby and grows
## back on a fast approach or a far call — never above the starting value, so a fright
## costs progress but can never make things worse than day one. Below the friend
## threshold the animal is befriended forever and never flees again.
##
## Subclasses only override how they flee and their signature behaviour: the *kind* of
## shyness matters more than the numbers.

var neighbour_id := "frog"
var home := Vector3.ZERO
var start_comfort := 6.0
var friend_threshold := 2.0
var calm_rate := 0.08         # metres of comfort lost per calm second nearby
var startle_penalty := 1.5
var calm_speed := 1.2         # mother slower than this counts as calm
var wander_radius := 2.5

var comfort := 6.0
var befriended := false
var model: Node3D
var _park: Node3D
var _flee_cooldown := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("neighbour")
	add_to_group("keep_out")
	add_to_group("saveable")
	add_to_group("interactable")
	_park = get_tree().get_first_node_in_group("park")
	_rng.seed = hash(neighbour_id)
	comfort = start_comfort
	var saved: Dictionary = GameState.neighbours.get(neighbour_id, {})
	if not saved.is_empty():
		comfort = float(saved.get("comfort", start_comfort))
		befriended = bool(saved.get("befriended", false))
	global_position = home
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	build_model(model)
	EventBus.call_made.connect(_on_call)

func build_model(_root: Node3D) -> void:
	pass

func _physics_process(delta: float) -> void:
	if _park == null or _park.mother == null:
		return
	_flee_cooldown = maxf(0.0, _flee_cooldown - delta)
	var m: CharacterBody3D = _park.mother
	var dist := _flat(m.global_position).distance_to(_flat(global_position))
	if not befriended:
		var mother_speed := Vector2(m.velocity.x, m.velocity.z).length()
		var calm: bool = mother_speed < calm_speed or m.is_dabbling
		if dist < comfort + 4.0 and calm and dist > 0.5:
			comfort = maxf(friend_threshold - 0.01, comfort - calm_rate * delta)
			if comfort < friend_threshold:
				_befriend()
		elif dist < comfort + 2.0 and not calm and _flee_cooldown <= 0.0:
			startle()
		if not befriended and dist < comfort:
			flee_step(delta, (global_position - m.global_position))
	else:
		signature_behaviour(delta, m)
	idle_animate(delta)

func startle() -> void:
	# Never above the start value: a fright costs progress, it does not add fear.
	comfort = minf(start_comfort, comfort + startle_penalty)
	_flee_cooldown = 2.0

func _on_call(kind: String) -> void:
	if kind == "far" and not befriended:
		startle()

func _befriend() -> void:
	befriended = true
	write_state()
	EventBus.neighbour_befriended.emit(neighbour_id)

## How this animal moves away. Default: nothing (the turtle).
func flee_step(_delta: float, _away: Vector3) -> void:
	pass

func signature_behaviour(_delta: float, _mother: Node3D) -> void:
	pass

func idle_animate(_delta: float) -> void:
	pass

func write_state() -> void:
	GameState.neighbours[neighbour_id] = {"comfort": comfort, "befriended": befriended}

func get_interaction_prompt(_duck: Node) -> String:
	return ""

func interact(_duck: Node) -> void:
	pass

func keep_out_circle() -> Array:
	return [Vector2(home.x, home.z), wander_radius + 2.0]

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

## Keep the animal on the ground and inside its wander radius.
func _settle(pos: Vector3) -> Vector3:
	var off := Vector2(pos.x - home.x, pos.z - home.z)
	if off.length() > wander_radius:
		off = off.normalized() * wander_radius
	var p := Vector3(home.x + off.x, 0.0, home.z + off.y)
	p.y = _park.ground_height(p.x, p.z)
	return p

static func make_part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Two dark dots turn a sphere into a head — the cheapest readability trick (8.G.2).
static func add_eyes(head: Node3D, radius: float, forward_z: float) -> void:
	for side in [-1.0, 1.0]:
		var e := SphereMesh.new()
		e.radius = radius
		e.height = radius * 2.0
		make_part(head, e, Color(0.08, 0.08, 0.08), Vector3(side * radius * 2.2, radius * 1.5, forward_z))
