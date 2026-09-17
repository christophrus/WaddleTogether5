extends WaddleTest
## Save/load round trip incl. daytime, keepsakes, neighbours and names, plus "new
## game" wiping everything (8.G.6). The real save file is backed up bytewise and
## restored no matter what (7.2).

const REAL_SAVE := "user://savegame.json"

func _init() -> void:
	test_name = "SAVE_LOAD"

func run(main: Node) -> void:
	var real_backup := backup_file(REAL_SAVE)
	var test_backup := backup_file(SaveManager.save_path)
	await _body(main)
	restore_file(REAL_SAVE, real_backup)
	restore_file(SaveManager.save_path, test_backup)
	check(backup_file(REAL_SAVE) == real_backup, "real save file byte-identical after the test")
	finish()

func _body(main: Node) -> void:
	var p := park(main)
	var m := mother(main)
	var n := nest(main)
	var brood := await bootstrap_brood(main, 2)
	var d0 = brood[0]
	d0.set_duck_name("Krümel")
	d0.data["skills"]["foraging"] = 0.55
	d0.data["nest_bound"] = false
	d0.data["stage"] = 1
	n.place_keepsake("marble", "Krümel")
	# Live nodes write their own state on save, so set the truth on the node itself.
	for nb in get_tree().get_nodes_in_group("neighbour"):
		if nb.neighbour_id == "frog":
			nb.comfort = 2.4
			nb.befriended = true
	GameState.mother["carried_food"] = 3
	Daytime.set_time(0.9)
	m.teleport(Vector3(5, 0.5, 5))
	var saved := spy(EventBus.game_saved)
	check(SaveManager.save_game(), "save succeeds")
	check_eq(saved[0], 1, "game_saved emitted")
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	check(f != null and f.get_length() > 100, "save file written")
	if f != null:
		f.close()

	# Wipe and reload
	GameState.reset()
	check_eq(GameState.ducklings.size(), 0, "state reset before load")
	check(SaveManager.load_game(), "load succeeds")
	check_eq(GameState.ducklings.size(), 2, "ducklings restored")
	var r := GameState.get_duckling(int(d0.data["id"]))
	check_eq(r.get("name", ""), "Krümel", "name restored")
	check_near(float(r["skills"]["foraging"]), 0.55, 0.001, "skills restored")
	check_eq(int(r["stage"]), 1, "stage restored as int")
	check_eq(GameState.keepsakes.size(), 1, "keepsake restored")
	check_eq(GameState.keepsakes[0]["kind"], "marble", "keepsake kind restored")
	check(bool(GameState.neighbours["frog"]["befriended"]), "neighbour friendship restored")
	check_near(GameState.day_time, 0.9, 0.0001, "night save loads at night")
	check(Daytime.is_night(), "clock says night after load")
	check_eq(int(GameState.mother["carried_food"]), 3, "carried food restored")
	check_near(GameState.arr_to_v3(GameState.mother["position"]).x, 5.0, 0.01, "mother position restored")
	check(bool(GameState.nest["built"]), "nest built restored")
	check(GameState.next_id > int(d0.data["id"]), "id counter restored beyond used ids")

	# New game wipes the file and the state.
	SaveManager.new_game()
	check(not SaveManager.has_save(), "new game removes the save file")
	check_eq(GameState.keepsakes.size(), 0, "new game clears keepsakes")
	check_eq(GameState.neighbours.size(), 0, "new game clears neighbour friendships")
	check_eq(GameState.ducklings.size(), 0, "new game clears ducklings")
