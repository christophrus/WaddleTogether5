extends Node
## JSON save to user://, autosave on milestone signals. Tests may point save_path at
## a scratch file; anything that could touch the real file must back it up bytewise.

var save_path := "user://savegame.json"
var autosave_enabled := true

func _ready() -> void:
	EventBus.nest_completed.connect(_on_milestone)
	EventBus.egg_hatched.connect(_on_milestone)
	EventBus.duckling_fledged.connect(_on_milestone)
	EventBus.duckling_named.connect(_on_milestone)
	EventBus.neighbour_befriended.connect(_on_milestone)
	EventBus.keepsake_placed.connect(_on_milestone)
	EventBus.adventure_completed.connect(_on_milestone)
	EventBus.new_generation.connect(_on_milestone)

func _on_milestone(_a = null, _b = null) -> void:
	if autosave_enabled:
		save_game()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_game() -> bool:
	var tree := get_tree()
	if tree != null:
		# Let live nodes write their transient state (positions etc.) into GameState.
		tree.call_group("saveable", "write_state")
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot write %s" % save_path)
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	EventBus.game_saved.emit()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("SaveManager: corrupt save ignored")
		return false
	GameState.from_dict(parsed)
	EventBus.game_loaded.emit()
	return true

func new_game() -> void:
	# All progress lives in the one save file, so wiping it is the whole reset (8.G.6).
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	GameState.reset()
	EventBus.new_game_started.emit()
