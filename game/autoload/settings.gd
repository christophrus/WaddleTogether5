extends Node
## Player-facing settings (fullscreen etc.), persisted separately from the save so a
## new game does not reset display preferences.

const PATH := "user://settings.cfg"

var fullscreen := false : set = set_fullscreen

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		set_fullscreen(bool(cfg.get_value("display", "fullscreen", false)))

func set_fullscreen(v: bool) -> void:
	fullscreen = v
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", v)
	cfg.save(PATH)
