extends CanvasLayer
## In-game UI. Shows *object* counters (food, material, brood progress) and prompts —
## never a bar or number for anything relational (rule 3.1). Also hosts the naming
## scene, the journal panel and the pause menu.

var _counters: Label
var _prompt: Label
var _toast: Label
var _toast_t := 0.0
var _naming: PanelContainer
var _name_edit: LineEdit
var _naming_id := -1
var _journal: PanelContainer
var _journal_text: RichTextLabel
var _pause: PanelContainer
var _park: Node3D

func _ready() -> void:
	_park = get_tree().get_first_node_in_group("park")
	_build()
	InputRouter.journal_toggled.connect(func(_p): _toggle_journal())
	EventBus.naming_requested.connect(_on_naming_requested)
	EventBus.journal_entry_added.connect(_on_journal_entry)
	EventBus.zone_unlocked.connect(func(z): _show_toast("Neuer Weg: %s" % _zone_name(z)))
	EventBus.adventure_started.connect(func(_a): _show_toast("Ein kleines Abenteuer beginnt."))
	EventBus.adventure_completed.connect(func(_a): _show_toast("Geschafft. Alle sind da."))
	EventBus.game_saved.connect(func(): _show_toast("Gespeichert.", 1.5))

func _process(delta: float) -> void:
	var m: Dictionary = GameState.mother
	var parts: Array[String] = []
	parts.append("Futter: %d" % int(m["carried_food"]))
	parts.append("Nistmaterial: %d" % int(m["carried_material"]))
	if m["carried_keepsake"] != "":
		parts.append("Fundstück: %s" % _keepsake_name(m["carried_keepsake"]))
	if _park != null and _park.nest != null and not GameState.eggs.is_empty():
		parts.append("Eier: %d  (Brüten %d %%)" % [GameState.eggs.size(), int(_park.nest.brood_progress() * 100.0)])
	_counters.text = "   ".join(parts)
	if _park != null and _park.mother != null:
		var p: String = _park.mother.current_prompt
		_prompt.text = "[Leertaste]  %s" % p if p != "" else ""
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.text = ""

# --- Naming (5.4) --------------------------------------------------------------

func _on_naming_requested(id: int, suggestion: String) -> void:
	_naming_id = id
	_name_edit.text = suggestion
	_naming.visible = true
	InputRouter.locked = true
	_name_edit.grab_focus()
	_name_edit.select_all()

func _confirm_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		return
	var d = _park.duckling_by_id(_naming_id)
	if d != null:
		d.set_duck_name(n)
	_naming.visible = false
	InputRouter.locked = false
	_naming_id = -1

# --- Journal -------------------------------------------------------------------

func _toggle_journal() -> void:
	_journal.visible = not _journal.visible
	if _journal.visible:
		_journal_text.clear()
		var last_day := -1
		for e in Journal.entries():
			if int(e["day"]) != last_day:
				last_day = int(e["day"])
				_journal_text.append_text("[b]Tag %d[/b]\n" % last_day)
			_journal_text.append_text("  %s\n" % e["text"])
		if Journal.entries().is_empty():
			_journal_text.append_text("[i]Noch leer. Das ändert sich.[/i]")

func _on_journal_entry(text: String) -> void:
	_show_toast(text, 4.0)

# --- Pause ---------------------------------------------------------------------

func toggle_pause() -> void:
	if _naming.visible:
		return
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible
	InputRouter.locked = _pause.visible

# --- Build ---------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_counters = Label.new()
	_counters.position = Vector2(16, 12)
	_counters.add_theme_font_size_override("font_size", 18)
	_counters.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_counters.add_theme_constant_override("shadow_offset_x", 1)
	_counters.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_counters)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.offset_top = -70
	_prompt.offset_bottom = -30
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_prompt)

	_toast = Label.new()
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_top = 40
	_toast.offset_bottom = 80
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	root.add_child(_toast)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 16
	hint.offset_top = -30
	hint.text = "WASD laufen · Q/E Kamera · Leertaste interagieren · F rufen (tippen/doppelt/halten) · Shift gründeln · J Tagebuch"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.75)
	root.add_child(hint)

	# Naming dialog
	_naming = PanelContainer.new()
	_naming.visible = false
	_naming.set_anchors_preset(Control.PRESET_CENTER)
	_naming.offset_left = -200
	_naming.offset_right = 200
	_naming.offset_top = -70
	_naming.offset_bottom = 70
	root.add_child(_naming)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_naming.add_child(vb)
	var l := Label.new()
	l.text = "Wie soll dieses Küken heißen?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	vb.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	vb.add_child(_name_edit)
	var ok := Button.new()
	ok.text = "So heißt es"
	ok.pressed.connect(_confirm_name)
	vb.add_child(ok)

	# Journal
	_journal = PanelContainer.new()
	_journal.visible = false
	_journal.set_anchors_preset(Control.PRESET_CENTER)
	_journal.offset_left = -300
	_journal.offset_right = 300
	_journal.offset_top = -220
	_journal.offset_bottom = 220
	root.add_child(_journal)
	var jv := VBoxContainer.new()
	_journal.add_child(jv)
	var jt := Label.new()
	jt.text = "Tagebuch"
	jt.add_theme_font_size_override("font_size", 24)
	jv.add_child(jt)
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journal_text.custom_minimum_size = Vector2(560, 360)
	jv.add_child(_journal_text)

	# Pause menu
	_pause = PanelContainer.new()
	_pause.visible = false
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	_pause.offset_left = -150
	_pause.offset_right = 150
	_pause.offset_top = -100
	_pause.offset_bottom = 100
	root.add_child(_pause)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	_pause.add_child(pv)
	var pt := Label.new()
	pt.text = "Pause"
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt.add_theme_font_size_override("font_size", 24)
	pv.add_child(pt)
	var resume := Button.new()
	resume.text = "Weiterspielen"
	resume.pressed.connect(toggle_pause)
	pv.add_child(resume)
	var save := Button.new()
	save.text = "Speichern"
	save.pressed.connect(func(): SaveManager.save_game())
	pv.add_child(save)
	var fs := CheckButton.new()
	fs.text = "Vollbild"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(v): Settings.fullscreen = v)
	pv.add_child(fs)
	var menu := Button.new()
	menu.text = "Zum Hauptmenü"
	menu.pressed.connect(func(): get_parent().quit_to_menu())
	pv.add_child(menu)

func _show_toast(text: String, seconds := 3.0) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = seconds

func _zone_name(z: String) -> String:
	match z:
		"meadow": return "die Wiese"
		"forest_edge": return "der Waldrand"
	return z

func _keepsake_name(k: String) -> String:
	match k:
		"bottle_cap": return "Kronkorken"
		"marble": return "Murmel"
		"button": return "Knopf"
		"blue_glass": return "blaue Glasscherbe"
		"pebble": return "glatter Kiesel"
	return k
