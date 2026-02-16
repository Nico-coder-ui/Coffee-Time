extends Control

@onready var progress_bar: ProgressBar = $CenterContainer/VBox/ProgressBar
@onready var loading_label: Label = $CenterContainer/VBox/LoadingLabel
@onready var percent_label: Label = $CenterContainer/VBox/PercentLabel
@onready var tip_label: Label = $CenterContainer/VBox/TipLabel

var loading_messages: Array[String] = [
	"DEMARRAGE DU MOTEUR...",
	"CHAUFFAGE DES PNEUS...",
	"CHARGEMENT DE LA VILLE...",
	"VERIFICATION DU GPS...",
	"PREPARATION DE LA COMMANDE...",
	"GO !"
]

var tips: Array[String] = [
	"MEMORISEZ LA CARTE POUR ALLER PLUS VITE",
	"ATTENTION AUX VIRAGES, LE CAFE PEUT SE RENVERSER",
	"LES RACCOURCIS NE SONT PAS TOUJOURS LES MEILLEURS",
	"LIVREZ LE CAFE TANT QU'IL EST CHAUD",
	"CHAQUE SECONDE COMPTE POUR LE SCORE FINAL",
]

var target_scene: String = "res://scenes/game.tscn"
var engine_player: AudioStreamPlayer = null


func _ready() -> void:
	tip_label.text = tips[randi() % tips.size()]

	engine_player = AudioStreamPlayer.new()
	var engine_streams := [
		load("res://sounds/lowCarEngine.mp3"),
		load("res://sounds/hardCarEngine.mp3"),
	]
	var chosen_engine = engine_streams[randi() % 2]
	if chosen_engine:
		engine_player.stream = chosen_engine
		add_child(engine_player)

	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.3)
	fade_in.tween_callback(_start_loading)


func _start_loading() -> void:
	# Demarrer le son moteur
	if engine_player and engine_player.stream:
		engine_player.play()

	var tween := create_tween()

	# etape 1
	tween.tween_method(_update_progress, 0.0, 20.0, 0.5)
	tween.tween_callback(func(): _set_message(0))
	tween.tween_interval(0.3)

	# etape 2
	tween.tween_method(_update_progress, 20.0, 45.0, 0.7)
	tween.tween_callback(func(): _set_message(1))
	tween.tween_interval(0.35)

	# etape 3
	tween.tween_method(_update_progress, 45.0, 70.0, 0.6)
	tween.tween_callback(func(): _set_message(2))
	tween.tween_interval(0.3)

	# etape 4
	tween.tween_method(_update_progress, 70.0, 85.0, 0.4)
	tween.tween_callback(func(): _set_message(3))
	tween.tween_interval(0.25)

	# etape 5
	tween.tween_method(_update_progress, 85.0, 98.0, 0.4)
	tween.tween_callback(func(): _set_message(4))
	tween.tween_interval(0.3)

	# final
	tween.tween_method(_update_progress, 98.0, 100.0, 0.2)
	tween.tween_callback(func(): _set_message(5))
	tween.tween_interval(0.5)
	tween.tween_callback(_go_to_game)


func _update_progress(value: float) -> void:
	progress_bar.value = value
	percent_label.text = str(int(value)) + "%"


func _set_message(index: int) -> void:
	if index < loading_messages.size():
		loading_label.text = loading_messages[index]


func _go_to_game() -> void:
	# Couper le son moteur
	if engine_player and engine_player.playing:
		engine_player.stop()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(target_scene)
	)
