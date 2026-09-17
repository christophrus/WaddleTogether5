extends Node
## The in-game root: park + HUD. Also the home of the pause menu wiring. No test
## hooks here (7.1): tests boot via game/tests/test_runner.tscn.

const PARK_SCENE := preload("res://game/world/park.tscn")
const HUD_SCENE := preload("res://game/ui/hud.tscn")

var park: Node3D
var hud: CanvasLayer

func _ready() -> void:
	park = PARK_SCENE.instantiate()
	add_child(park)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	Daytime.running = true
	InputRouter.pause_toggled.connect(_on_pause)
	AudioManager.play_music("ambient")

func _on_pause(_pid: int) -> void:
	if hud.has_method("toggle_pause"):
		hud.toggle_pause()

func quit_to_menu() -> void:
	SaveManager.save_game()
	Daytime.running = false
	AudioManager.stop_music()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/ui/main_menu.tscn")
