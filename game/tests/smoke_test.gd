extends WaddleTest
## Boots the real game scene and checks that the autoloads and the park skeleton exist.

func _init() -> void:
	test_name = "SMOKE"

func run(main: Node) -> void:
	check(main.park != null, "park instantiated")
	check(main.hud != null, "hud instantiated")
	for a in ["EventBus", "GameState", "InputRouter", "SaveManager", "AudioManager", "Settings", "Journal", "Progression", "Daytime"]:
		check(get_node_or_null("/root/" + a) != null, "autoload present: " + a)
	check(get_tree().get_nodes_in_group("water").size() >= 1, "pond registered in group water", get_tree().get_nodes_in_group("water").size())
	check(get_tree().get_nodes_in_group("duck").size() == 1, "exactly one mother duck", get_tree().get_nodes_in_group("duck").size())
	check(get_tree().get_nodes_in_group("nest_site").size() == 1, "exactly one nest site")
	finish()
