extends Control
## Start scene. Deliberately free of any test hooks: tests boot through
## game/tests/test_runner.tscn and never pass through here.

const GAME_SCENE := "res://game/main/game.tscn"

@onready var _continue: Button = %Continue

func _ready() -> void:
	Daytime.running = false
	_continue.disabled = not SaveManager.has_save()
	%NewGame.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	%Fullscreen.button_pressed = Settings.fullscreen
	%Fullscreen.toggled.connect(func(v): Settings.fullscreen = v)
	%Quit.pressed.connect(func(): get_tree().quit())
	%NewGame.grab_focus()

func _on_new_game() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file(GAME_SCENE)
