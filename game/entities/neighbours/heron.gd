extends "res://game/entities/neighbours/neighbour.gd"
## Dignified: stalks away at a steady pace instead of hopping, and takes the longest.
## Befriended, it bows once when the family comes close.

var _bow_t := 0.0
var _bow_cooldown := 0.0
var _neck: Node3D

func _init() -> void:
	neighbour_id = "heron"
	start_comfort = 8.0
	friend_threshold = 2.5
	calm_rate = 0.05
	startle_penalty = 2.0
	wander_radius = 4.0

func build_model(root: Node3D) -> void:
	# Every part on the same axis side (+Z is forward), see 8.G.2.
	var legs := CylinderMesh.new()
	legs.top_radius = 0.03
	legs.bottom_radius = 0.03
	legs.height = 0.8
	make_part(root, legs, Color(0.3, 0.3, 0.28), Vector3(0.08, 0.4, 0))
	make_part(root, legs, Color(0.3, 0.3, 0.28), Vector3(-0.08, 0.4, 0))
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.8
	var b := make_part(root, body, Color(0.6, 0.65, 0.7), Vector3(0, 0.95, 0))
	b.rotation_degrees.x = 90.0
	_neck = Node3D.new()
	_neck.position = Vector3(0, 1.05, 0.3)
	root.add_child(_neck)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.05
	neck.bottom_radius = 0.07
	neck.height = 0.7
	var n := make_part(_neck, neck, Color(0.62, 0.66, 0.72), Vector3(0, 0.3, 0.12))
	n.rotation_degrees.x = 20.0
	var head := SphereMesh.new()
	head.radius = 0.11
	head.height = 0.2
	# Head sits where the tilted neck ends (+Z side), not on the opposite side.
	var h := make_part(_neck, head, Color(0.65, 0.68, 0.74), Vector3(0, 0.66, 0.25))
	add_eyes(h, 0.025, 0.08)
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.035
	beak.height = 0.3
	var bk := make_part(h, beak, Color(0.85, 0.7, 0.3), Vector3(0, 0.0, 0.2))
	bk.rotation_degrees.x = 90.0

func flee_step(delta: float, away: Vector3) -> void:
	var dir := Vector3(away.x, 0, away.z).normalized()
	var p := _settle(global_position + dir * 1.4 * delta)
	global_position = p
	model.rotation.y = atan2(dir.x, dir.z)

func signature_behaviour(delta: float, mother: Node3D) -> void:
	_bow_cooldown -= delta
	if _bow_t > 0.0:
		_bow_t -= delta
		_neck.rotation.x = sin((1.0 - _bow_t / 1.6) * PI) * 0.9
	elif _bow_cooldown <= 0.0 and _flat(mother.global_position).distance_to(_flat(global_position)) < 3.5:
		_bow_t = 1.6
		_bow_cooldown = 12.0
		var to := mother.global_position - global_position
		model.rotation.y = atan2(to.x, to.z)
