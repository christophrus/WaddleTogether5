extends Node3D
## One empty node in park.tscn; the three neighbours are built here in code so the
## world scene never changes when an animal is added or tuned.

func build() -> void:
	var park := get_tree().get_first_node_in_group("park")
	var specs := [
		["res://game/entities/neighbours/frog.gd", Vector3(-11.0, 0.0, -2.0)],
		["res://game/entities/neighbours/heron.gd", Vector3(9.5, 0.0, -14.0)],
		["res://game/entities/neighbours/turtle.gd", Vector3(-6.0, 0.0, 4.5)],
	]
	for s in specs:
		var n: Node3D = load(s[0]).new()
		var home: Vector3 = s[1]
		home.y = park.ground_height(home.x, home.z)
		n.home = home
		add_child(n)
