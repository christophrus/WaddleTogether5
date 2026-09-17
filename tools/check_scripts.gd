extends Node
## Loads every .gd under res:// and reports parse errors. Run:
##   godot --headless --path . res://tools/check_scripts.tscn
## Runs inside the normal runtime so autoload identifiers resolve. Cheap guard against
## the "parse error only found at runtime" trap (8.E.2).

func _ready() -> void:
	var bad := 0
	var total := 0
	for path in _collect("res://"):
		total += 1
		var s = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if s == null:
			print("PARSE FAIL: %s" % path)
			bad += 1
			continue
		var err = s.reload()
		if err != OK and err != ERR_ALREADY_IN_USE:  # 22 = script has live instances (autoloads); not a parse error
			print("PARSE FAIL (%d): %s" % [err, path])
			bad += 1
	print("[CHECK] %d scripts, %d failed" % [total, bad])
	get_tree().quit(1 if bad > 0 else 0)

func _collect(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if name != "addons":
				out.append_array(_collect(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
