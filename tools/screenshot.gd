extends Node
## Visual check helper (7.3): boots the real game, sets the time of day and camera,
## waits a few frames and writes a PNG. Needs a GUI run (headless renders nothing):
##   WADDLE_SHOT=out.png WADDLE_TIME=0.45 WADDLE_VIEW=nest godot --path . res://tools/screenshot.tscn
## Views: spawn (default) | nest | pond | top | meadow | forest | night

func _ready() -> void:
	SaveManager.save_path = "user://screenshot_savegame.json"
	SaveManager.autosave_enabled = false
	GameState.reset()
	var main = load("res://game/main/game.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Daytime.running = false
	var t := OS.get_environment("WADDLE_TIME")
	Daytime.set_time(float(t) if t != "" else 0.45)
	var view := OS.get_environment("WADDLE_VIEW")
	var park = main.park
	var brood_env := OS.get_environment("WADDLE_BROOD")
	if brood_env != "":
		park.nest.debug_complete()
		for i in int(brood_env):
			park.nest.lay_egg()
		park.nest.debug_hatch_all()
		for d in park.ducklings():
			d.data["nest_bound"] = false
			d.data["stage"] = 1
			d.state = d.State.FOLLOW
	match view:
		"nest": park.mother.teleport(park.nest.global_position + Vector3(2.5, 0.6, 3.0))
		"pond": park.mother.teleport(park.POND_CENTER + Vector3(0, 0.6, 2.0))
		"meadow": park.mother.teleport(Vector3(17.0, 0.6, 2.0))
		"forest": park.mother.teleport(Vector3(0.0, 0.6, -19.0))
		"night":
			Daytime.set_time(0.9)
			park.mother.teleport(park.nest.global_position + Vector3(2.5, 0.6, 3.0))
		"top":
			var cam := Camera3D.new()
			add_child(cam)
			cam.position = Vector3(0, 55, 0)
			cam.rotation_degrees = Vector3(-90, 0, 0)
			cam.fov = 75
			cam.current = true
	for i in 40:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var out := OS.get_environment("WADDLE_SHOT")
	if out == "":
		out = "user://screenshot.png"
	var err := img.save_png(out)
	print("[SHOT] %s -> %s (%dx%d)" % [view, out, img.get_width(), img.get_height()])
	get_tree().quit(0 if err == OK else 1)
