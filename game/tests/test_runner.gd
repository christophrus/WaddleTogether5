extends Node
## File dispatcher: WADDLE_TEST=<name> loads res://game/tests/<name>_test.gd, boots the
## real game scene underneath it and calls run(main). One test = one file; the main
## scene and the menu never learn that tests exist (the first build's biggest mistake).

const GAME_SCENE := "res://game/main/game.tscn"

func _ready() -> void:
	var test_name := OS.get_environment("WADDLE_TEST")
	if test_name == "":
		print("[RUNNER] RESULT: FAIL - WADDLE_TEST not set")
		get_tree().quit(2)
		return
	var path := "res://game/tests/%s_test.gd" % test_name
	if not ResourceLoader.exists(path):
		print("[RUNNER] RESULT: FAIL - no such test file %s" % path)
		get_tree().quit(2)
		return
	var script: GDScript = load(path)
	if script == null:
		print("[RUNNER] RESULT: FAIL - %s failed to load (parse error?)" % path)
		get_tree().quit(2)
		return
	# Tests own the save file question: start from a clean state, real save untouched.
	SaveManager.save_path = "user://test_savegame.json"
	SaveManager.autosave_enabled = false
	GameState.reset()
	Daytime.running = false
	var main = load(GAME_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var test: Node = script.new()
	test.name = "Test_" + test_name
	add_child(test)
	await test.run(main)
