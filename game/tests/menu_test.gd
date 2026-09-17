extends WaddleTest
## The main menu and pause flow: the menu scene loads cleanly, Continue follows the
## save file, and the HUD's naming dialog locks input until a name is confirmed.

func _init() -> void:
	test_name = "MENU"

func run(main: Node) -> void:
	var test_backup := backup_file(SaveManager.save_path)
	if SaveManager.has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	var menu = load("res://game/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	check(menu.get_node("%NewGame") != null, "menu has a New Game button")
	check(menu.get_node("%Continue").disabled, "Continue disabled without a save")
	menu.queue_free()
	await frames(1)
	SaveManager.save_game()
	menu = load("res://game/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	check(not menu.get_node("%Continue").disabled, "Continue enabled with a save")
	check_eq(menu.get_node("%Fullscreen").button_pressed, Settings.fullscreen, "fullscreen toggle mirrors Settings")
	menu.queue_free()
	restore_file(SaveManager.save_path, test_backup)

	# Naming dialog locks gameplay input and names the duckling.
	var brood := await bootstrap_brood(main, 1)
	var d = brood[0]
	d.data["nest_bound"] = false
	d.data["stage"] = 1
	var named: Array = []
	EventBus.duckling_named.connect(func(_id, n): named.append(n))
	d.cuddle()
	await frames(2)
	check(InputRouter.locked, "input locked while naming")
	check(main.hud._naming.visible, "naming dialog visible")
	check(main.hud._name_edit.text != "", "a name is suggested", main.hud._name_edit.text)
	main.hud._name_edit.text = "Lotte"
	main.hud._confirm_name()
	check(not InputRouter.locked, "input unlocked after naming")
	check_eq(named, ["Lotte"], "duckling_named emitted with the typed name")
	check_eq(d.data["name"], "Lotte", "name stored in the record")
	d.cuddle()
	await frames(2)
	check(not main.hud._naming.visible, "second cuddle does not ask again")

	# Pause toggles the tree and unpauses cleanly.
	main.hud.toggle_pause()
	check(get_tree().paused, "pause menu pauses the tree")
	main.hud.toggle_pause()
	check(not get_tree().paused, "resume unpauses")
	finish()
