extends Control

@onready var hbox_layout: HBoxContainer = $HBoxLayout
@onready var vbox_main: VBoxContainer = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain
@onready var buttons_container: VBoxContainer = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain/ButtonsContainer
@onready var start_button: Button = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain/ButtonsContainer/StartButton
@onready var settings_button: Button = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain/ButtonsContainer/SettingsButton
@onready var quit_button: Button = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain/ButtonsContainer/QuitButton
@onready var how_to_play_button: Button = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain/ButtonsContainer/HowToPlayButton
@onready var how_to_play_panel: PanelContainer = $HowToPlayPanel
@onready var how_to_back_button: Button = $HowToPlayPanel/HowToVBox/HowToBackButton

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var back_button: Button = $SettingsPanel/SettingsVBox/BackButton
@onready var volume_slider: HSlider = $SettingsPanel/SettingsVBox/VolumeHBox/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/SettingsVBox/VolumeHBox/VolumeValue
@onready var keys_vbox: VBoxContainer = $SettingsPanel/SettingsVBox/KeysScroll/KeysVBox

@onready var pre_countdown_slider: HSlider = $SettingsPanel/SettingsVBox/PreCountdownHBox/PreCountdownSlider
@onready var pre_countdown_value: Label = $SettingsPanel/SettingsVBox/PreCountdownHBox/PreCountdownValue
@onready var memorize_slider: HSlider = $SettingsPanel/SettingsVBox/MemorizeHBox/MemorizeSlider
@onready var memorize_value: Label = $SettingsPanel/SettingsVBox/MemorizeHBox/MemorizeValue

@onready var map_select_panel: PanelContainer = $MapSelectPanel
@onready var map_list_vbox: VBoxContainer = $MapSelectPanel/MapSelectVBox/MapScroll/MapListVBox
@onready var map_back_button: Button = $MapSelectPanel/MapSelectVBox/MapBackButton

@onready var score1_label: Label = $HBoxLayout/RightPanel/RightMargin/PodiumOuter/PodiumPanel/PodiumVBox/Score1
@onready var score2_label: Label = $HBoxLayout/RightPanel/RightMargin/PodiumOuter/PodiumPanel/PodiumVBox/Score2
@onready var score3_label: Label = $HBoxLayout/RightPanel/RightMargin/PodiumOuter/PodiumPanel/PodiumVBox/Score3

@onready var title_label: Label = $HBoxLayout/LeftPanel/LeftMargin/VBoxMain/TitleLabel

var scores: Array[int] = []
const SCORES_PATH := "user://scores.save"
const SETTINGS_PATH := "user://settings.save"
const BINDS_PATH := "user://keybinds.save"

# Keybinding
var waiting_for_key: bool = false
var rebind_action: String = ""
var rebind_button: Button = null
var bind_buttons: Dictionary = {}
var menu_music: AudioStreamPlayer = null

# Actions rebindables
var bindable_actions: Dictionary = {
	"car_forward": "AVANCER",
	"car_backward": "RECULER",
	"car_left": "GAUCHE",
	"car_right": "DROITE",
	"car_drift": "DRIFT",
	"car_honk": "KLAXON",
	"car_reset": "RESET",
}


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	how_to_back_button.pressed.connect(_on_how_to_back_pressed)
	back_button.pressed.connect(_on_back_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	map_back_button.pressed.connect(_on_map_back_pressed)
	pre_countdown_slider.value_changed.connect(_on_pre_countdown_changed)
	memorize_slider.value_changed.connect(_on_memorize_changed)

	_setup_button_hover(start_button)
	_setup_button_hover(settings_button)
	_setup_button_hover(quit_button)
	_setup_button_hover(how_to_play_button)
	_setup_button_hover(how_to_back_button)
	_setup_button_hover(back_button)
	_setup_button_hover(map_back_button)

	_load_keybinds()
	_build_keybind_rows()
	_load_scores()
	_load_settings()
	_update_podium_display()
	_animate_title_entrance()

	menu_music = AudioStreamPlayer.new()
	var music_stream = load("res://sounds/menu_sound_track.mp3")
	if music_stream:
		music_stream.loop = true
		menu_music.stream = music_stream
		menu_music.volume_db = -5.0
		add_child(menu_music)
		menu_music.play()


# ==============================
#       BOUTONS DU MENU
# ==============================

func _on_start_pressed() -> void:
	if menu_music and menu_music.playing:
		var music_tween := create_tween()
		music_tween.tween_property(menu_music, "volume_db", -40.0, 0.4)
		music_tween.tween_callback(func(): menu_music.stop())
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/loading.tscn")
	)


func _on_settings_pressed() -> void:
	# Transition douce : cacher tout le layout, afficher les settings
	var tween := create_tween()
	tween.tween_property(hbox_layout, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		hbox_layout.visible = false
		settings_panel.visible = true
		settings_panel.modulate.a = 0.0
		settings_panel.position.y -= 30
		var tween2 := create_tween().set_parallel(true)
		tween2.tween_property(settings_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		tween2.tween_property(settings_panel, "position:y", settings_panel.position.y + 30, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	)


func _on_quit_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().quit()
	)


func _on_how_to_play_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(hbox_layout, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		hbox_layout.visible = false
		how_to_play_panel.visible = true
		how_to_play_panel.modulate.a = 0.0
		how_to_play_panel.position.y -= 30
		var tween2 := create_tween().set_parallel(true)
		tween2.tween_property(how_to_play_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		tween2.tween_property(how_to_play_panel, "position:y", how_to_play_panel.position.y + 30, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	)


func _on_how_to_back_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(how_to_play_panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		how_to_play_panel.visible = false
		hbox_layout.visible = true
		hbox_layout.modulate.a = 0.0
		var tween2 := create_tween()
		tween2.tween_property(hbox_layout, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	)


func _on_back_pressed() -> void:
	# Transition douce : cacher settings, réafficher le layout complet
	var tween := create_tween()
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		settings_panel.visible = false
		hbox_layout.visible = true
		hbox_layout.modulate.a = 0.0
		var tween2 := create_tween()
		tween2.tween_property(hbox_layout, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	)


# ==============================
#       VOLUME / SETTINGS
# ==============================

func _on_volume_changed(value: float) -> void:
	var db: float
	if value <= 0:
		db = -80.0
	else:
		db = linear_to_db(value / 100.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	volume_value.text = str(int(value)) + "%"
	_save_settings()


func _on_pre_countdown_changed(value: float) -> void:
	GameData.pre_countdown_time = value
	pre_countdown_value.text = "%ds" % int(value)
	_save_settings()


func _on_memorize_changed(value: float) -> void:
	GameData.memorize_time = value
	memorize_value.text = "%ds" % int(value)
	_save_settings()


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		var data := {
			"volume": volume_slider.value,
			"pre_countdown": GameData.pre_countdown_time,
			"memorize": GameData.memorize_time,
		}
		file.store_string(JSON.stringify(data))
		file.close()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		volume_slider.value = 80.0
		_on_volume_changed(80.0)
		pre_countdown_slider.value = GameData.pre_countdown_time
		pre_countdown_value.text = "%ds" % int(GameData.pre_countdown_time)
		memorize_slider.value = GameData.memorize_time
		memorize_value.text = "%ds" % int(GameData.memorize_time)
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var result := json.parse(file.get_as_text())
		file.close()
		if result == OK:
			var data: Dictionary = json.data
			if data.has("volume"):
				volume_slider.value = data["volume"]
				_on_volume_changed(data["volume"])
			if data.has("pre_countdown"):
				GameData.pre_countdown_time = data["pre_countdown"]
				pre_countdown_slider.value = data["pre_countdown"]
				pre_countdown_value.text = "%ds" % int(data["pre_countdown"])
			else:
				pre_countdown_slider.value = GameData.pre_countdown_time
				pre_countdown_value.text = "%ds" % int(GameData.pre_countdown_time)
			if data.has("memorize"):
				GameData.memorize_time = data["memorize"]
				memorize_slider.value = data["memorize"]
				memorize_value.text = "%ds" % int(data["memorize"])
			else:
				memorize_slider.value = GameData.memorize_time
				memorize_value.text = "%ds" % int(GameData.memorize_time)


# ==============================
#       PODIUM / SCORES
# ==============================

func _load_scores() -> void:
	scores.clear()
	if not FileAccess.file_exists(SCORES_PATH):
		return

	var file := FileAccess.open(SCORES_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var result := json.parse(file.get_as_text())
		file.close()
		if result == OK and json.data is Array:
			for s in json.data:
				if s is float or s is int:
					scores.append(int(s))
			scores.sort()
			scores.reverse()
			if scores.size() > 3:
				scores.resize(3)


func save_score(new_score: int) -> void:
	_load_scores()
	scores.append(new_score)
	scores.sort()
	scores.reverse()
	if scores.size() > 3:
		scores.resize(3)

	var file := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scores))
		file.close()

	_update_podium_display()


func _update_podium_display() -> void:
	var labels := [score1_label, score2_label, score3_label]
	for i in range(3):
		if i < scores.size():
			labels[i].text = "%d. %d pts" % [i + 1, scores[i]]
		else:
			labels[i].text = "%d. ---" % [i + 1]


# ==============================
#       ANIMATIONS & HOVER
# ==============================

func _animate_title_entrance() -> void:
	title_label.modulate.a = 0.0
	title_label.position.y -= 40
	var original_y := title_label.position.y + 40

	var tween := create_tween().set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_delay(0.2)
	tween.tween_property(title_label, "position:y", original_y, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.2)


func _setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func():
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func():
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
	)
	button.pivot_offset = button.size / 2.0


# ==============================
#       KEYBINDING
# ==============================

func _build_keybind_rows() -> void:
	for child in keys_vbox.get_children():
		child.queue_free()
	bind_buttons.clear()

	var font_res := load("res://fonts/RacingFont.otf")

	for action_name in bindable_actions.keys():
		var display_name: String = bindable_actions[action_name]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = display_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_override("font", font_res)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = _get_action_key_name(action_name)
		btn.custom_minimum_size = Vector2(160, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		btn.add_theme_font_override("font", font_res)
		btn.add_theme_font_size_override("font_size", 16)

		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		style_normal.border_color = Color(0.9, 0.25, 0.1, 0.6)
		style_normal.set_border_width_all(1)
		style_normal.set_corner_radius_all(4)
		style_normal.content_margin_left = 10
		style_normal.content_margin_right = 10
		btn.add_theme_stylebox_override("normal", style_normal)

		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = Color(0.2, 0.15, 0.15, 0.95)
		style_hover.border_color = Color(0.9, 0.25, 0.1, 1.0)
		style_hover.set_border_width_all(2)
		style_hover.set_corner_radius_all(4)
		style_hover.content_margin_left = 10
		style_hover.content_margin_right = 10
		btn.add_theme_stylebox_override("hover", style_hover)

		btn.pressed.connect(_on_rebind_pressed.bind(action_name, btn))
		row.add_child(btn)

		keys_vbox.add_child(row)
		bind_buttons[action_name] = btn


func _get_action_key_name(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.size() == 0:
		return "???"
	var ev = events[0]
	if ev is InputEventKey:
		var kc: int = ev.keycode
		if kc == 0:
			kc = ev.physical_keycode
		return OS.get_keycode_string(kc)
	return "???"


func _on_rebind_pressed(action_name: String, btn: Button) -> void:
	if waiting_for_key:
		rebind_button.text = _get_action_key_name(rebind_action)

	waiting_for_key = true
	rebind_action = action_name
	rebind_button = btn
	btn.text = "..."


func _input(event: InputEvent) -> void:
	if not waiting_for_key:
		return
	if not event is InputEventKey:
		return
	if not event.pressed:
		return

	# Touche Escape = annuler le rebind
	if event.keycode == KEY_ESCAPE:
		waiting_for_key = false
		rebind_button.text = _get_action_key_name(rebind_action)
		rebind_action = ""
		rebind_button = null
		get_viewport().set_input_as_handled()
		return

	# Effacer les anciennes touches de l'action et mettre la nouvelle
	InputMap.action_erase_events(rebind_action)

	var new_event := InputEventKey.new()
	new_event.keycode = event.keycode
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(rebind_action, new_event)

	rebind_button.text = _get_action_key_name(rebind_action)

	waiting_for_key = false
	rebind_action = ""
	rebind_button = null

	get_viewport().set_input_as_handled()
	_save_keybinds()


func _save_keybinds() -> void:
	var data: Dictionary = {}
	for action_name in bindable_actions.keys():
		var events := InputMap.action_get_events(action_name)
		if events.size() > 0:
			var ev = events[0]
			if ev is InputEventKey:
				data[action_name] = {
					"keycode": ev.keycode,
					"physical_keycode": ev.physical_keycode,
				}
	var file := FileAccess.open(BINDS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_keybinds() -> void:
	if not FileAccess.file_exists(BINDS_PATH):
		return

	var file := FileAccess.open(BINDS_PATH, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()

	if result != OK:
		return

	var data: Dictionary = json.data
	for action_name in data.keys():
		if not InputMap.has_action(action_name):
			continue
		var info: Dictionary = data[action_name]
		InputMap.action_erase_events(action_name)

		var ev := InputEventKey.new()
		ev.keycode = int(info.get("keycode", 0)) as Key
		ev.physical_keycode = int(info.get("physical_keycode", 0)) as Key
		InputMap.action_add_event(action_name, ev)


# ==============================
#       MAP SELECTION
# ==============================

func _on_map_back_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(map_select_panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		map_select_panel.visible = false
		hbox_layout.visible = true
		hbox_layout.modulate.a = 0.0
		var tween2 := create_tween()
		tween2.tween_property(hbox_layout, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	)


func _build_map_list() -> void:
	for child in map_list_vbox.get_children():
		child.queue_free()

	var font_res := load("res://fonts/RacingFont.otf")

	# Bouton "ALEATOIRE" (generation procedurale)
	var random_btn := Button.new()
	random_btn.text = "ALEATOIRE"
	random_btn.custom_minimum_size = Vector2(0, 52)
	random_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_btn.add_theme_font_override("font", font_res)
	random_btn.add_theme_font_size_override("font_size", 22)
	var random_style := StyleBoxFlat.new()
	random_style.bg_color = Color(0.12, 0.35, 0.12, 0.9)
	random_style.border_color = Color(0.3, 0.8, 0.3, 0.6)
	random_style.set_border_width_all(2)
	random_style.set_corner_radius_all(6)
	random_style.content_margin_left = 20
	random_style.content_margin_right = 20
	random_style.skew = Vector2(-0.05, 0)
	random_btn.add_theme_stylebox_override("normal", random_style)
	var random_hover := StyleBoxFlat.new()
	random_hover.bg_color = Color(0.15, 0.45, 0.15, 1.0)
	random_hover.border_color = Color(0.3, 1.0, 0.3, 0.9)
	random_hover.set_border_width_all(2)
	random_hover.set_corner_radius_all(6)
	random_hover.content_margin_left = 20
	random_hover.content_margin_right = 20
	random_hover.skew = Vector2(-0.05, 0)
	random_btn.add_theme_stylebox_override("hover", random_hover)
	random_btn.pressed.connect(_on_map_selected.bind(""))
	_setup_button_hover(random_btn)
	map_list_vbox.add_child(random_btn)

	# Scanner le dossier maps/
	var maps_dir := DirAccess.open("res://maps")
	if not maps_dir:
		return

	maps_dir.list_dir_begin()
	var dir_name := maps_dir.get_next()
	while dir_name != "":
		if maps_dir.current_is_dir() and not dir_name.begins_with("."):
			var map_path := "res://maps/" + dir_name
			# Verifier que les 3 fichiers existent
			var has_grid := ResourceLoader.exists(map_path + "/grid.png") or FileAccess.file_exists(map_path + "/grid.png")
			var has_visual := ResourceLoader.exists(map_path + "/visual.png") or FileAccess.file_exists(map_path + "/visual.png")
			var has_spawns := FileAccess.file_exists(map_path + "/spawns.json")
			if has_grid and has_visual and has_spawns:
				_add_map_button(dir_name, map_path, font_res)
		dir_name = maps_dir.get_next()
	maps_dir.list_dir_end()


func _add_map_button(display_name: String, map_path: String, font_res: Font) -> void:
	# Formater le nom (remplacer _ par espace, capitaliser)
	var pretty_name := display_name.replace("_", " ").to_upper()

	var btn := Button.new()
	btn.text = pretty_name
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", font_res)
	btn.add_theme_font_size_override("font_size", 20)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = Color(0.9, 0.25, 0.1, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.skew = Vector2(-0.05, 0)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.15, 0.15, 1.0)
	hover_style.border_color = Color(0.9, 0.25, 0.1, 1.0)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)
	hover_style.content_margin_left = 20
	hover_style.content_margin_right = 20
	hover_style.skew = Vector2(-0.05, 0)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(_on_map_selected.bind(map_path))
	_setup_button_hover(btn)
	map_list_vbox.add_child(btn)


func _on_map_selected(map_path: String) -> void:
	GameData.selected_map = map_path
	if menu_music and menu_music.playing:
		var music_tween := create_tween()
		music_tween.tween_property(menu_music, "volume_db", -40.0, 0.4)
		music_tween.tween_callback(func(): menu_music.stop())
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/loading.tscn")
	)
