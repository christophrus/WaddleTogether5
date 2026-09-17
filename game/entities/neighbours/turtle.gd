extends "res://game/entities/neighbours/neighbour.gd"
## Never flees and cannot be impressed — which makes it the easiest to befriend.
## That is the joke. Befriended, it slowly turns to face whoever is near.

func _init() -> void:
	neighbour_id = "turtle"
	start_comfort = 3.0
	friend_threshold = 2.2
	calm_rate = 0.15
	startle_penalty = 0.0   # unimpressable

func build_model(root: Node3D) -> void:
	var shell := SphereMesh.new()
	shell.radius = 0.3
	shell.height = 0.3
	make_part(root, shell, Color(0.3, 0.42, 0.22), Vector3(0, 0.15, 0))
	var head := SphereMesh.new()
	head.radius = 0.09
	head.height = 0.16
	var h := make_part(root, head, Color(0.45, 0.55, 0.3), Vector3(0, 0.14, 0.34))
	add_eyes(h, 0.02, 0.07)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := SphereMesh.new()
			leg.radius = 0.06
			leg.height = 0.1
			make_part(root, leg, Color(0.45, 0.55, 0.3), Vector3(sx * 0.24, 0.05, sz * 0.18))

func startle() -> void:
	pass  # unimpressable, on purpose

func signature_behaviour(delta: float, mother: Node3D) -> void:
	var to := mother.global_position - global_position
	if Vector2(to.x, to.z).length() < 4.0:
		var target := atan2(to.x, to.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, delta * 0.6)
