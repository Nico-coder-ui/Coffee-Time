extends Node2D

# =============================================================
#  ENUMS
# =============================================================
enum Phase { PRE_COUNTDOWN, MEMORIZE, TRANSITION, RACE_COUNTDOWN, RACING, FINISHED, RETURN_TRANSITION, DARK_COUNTDOWN, DARK_RACING, DARK_FINISHED }

# =============================================================
#  CONSTANTES MAP
# =============================================================
var CELL := 128
const BLOCK_W := 5
const BLOCK_H := 5
const ROAD_W := 3
const SW_W := 1
const BLOCKS_X := 4
const BLOCKS_Y := 4

# Types de cellules
const C_ROAD := 0
const C_SIDEWALK := 1
const C_BUILDING := 2

# =============================================================
#  CONSTANTES GAMEPLAY
# =============================================================
var PRE_COUNTDOWN_TIME := 5.0
var MEMORIZE_TIME := 15.0
const TRANSITION_TIME := 1.2
var RACE_COUNTDOWN_TIME := 4.0   # 3, 2, 1, GO (1s chacun)
const MAX_RACE_TIME := 120.0
const NPC_VISIBLE_DISTANCE := 1500.0

# =============================================================
#  CONSTANTES SCORE
# =============================================================
const SCORE_MAX := 100000
const SCORE_TIME_MULT := 500
const WALL_TIME_PENALTY := 10  # chaque mur = +10s au temps final

# =============================================================
#  PRELOADS
# =============================================================
var car_scene := preload("res://scenes/car.tscn")
var font := preload("res://fonts/RacingFont.otf")

# Audio
var countdown_sound: AudioStreamPlayer = null
var race_music: AudioStreamPlayer = null
var menu_music: AudioStreamPlayer = null

# =============================================================
#  VARIABLES MAP
# =============================================================
var grid: Array = []
var col_types: Array[int] = []
var row_types: Array[int] = []
var grid_w: int = 0
var grid_h: int = 0
var map_px_w: int = 0
var map_px_h: int = 0
var memo_cell_size: int = 12

# Custom map
var use_custom_map: bool = false
var custom_map_path: String = ""
var custom_visual_tex: Texture2D
var custom_car_heading: float = -PI / 2.0

# =============================================================
#  VARIABLES GAMEPLAY
# =============================================================
var phase: int = Phase.PRE_COUNTDOWN
var phase_timer: float = 0.0
var race_time: float = 0.0
var penalties_sw: float = 0.0
var penalties_wall: int = 0
var was_on_sidewalk: bool = false
var wall_cooldown: float = 0.0
var initial_distance: float = 0.0
var car_start_pos: Vector2 = Vector2.ZERO
var last_safe_car_pos: Vector2 = Vector2.ZERO   # derniere position sur route/trottoir
var npc_pos: Vector2 = Vector2.ZERO
var countdown_num: int = 0

# Tour sombre (2e livraison)
var first_round_time: float = 0.0   # temps du premier tour
var dark_time_limit: float = 0.0    # temps limite tour sombre = first_round_time + 20
var dark_race_time: float = 0.0     # chrono du tour sombre
var dark_round_success: bool = false
var canvas_modulate: CanvasModulate = null  # assombrit tout le canvas pour le tour sombre
var car_light: PointLight2D = null
const DARK_BONUS_TIME := 10.0
const DARK_LIGHT_RADIUS := 0.40       # 20px au-dela de la voiture (~85px rayon total)
const DARK_LIGHT_RADIUS_BONUS := 1  # 100px au-dela de la voiture (~165px rayon total)

# =============================================================
#  REFERENCES NODES
# =============================================================
var car: CharacterBody2D
var camera: Camera2D
var map_node: Node2D
var buildings_node: Node2D
var decor_sprite: Sprite2D = null   # reference au decor (firstmap) pour shader reveal
var npc_sprite: Sprite2D
var objective_area: Area2D

# HUD
var hud_layer: CanvasLayer
var timer_label: Label
var penalty_label: Label
var countdown_label: Label
var minimap_container: Control
var minimap_clip: Control          # zone circulaire clippee
var minimap_tex_rect: TextureRect  # image collision qui bouge
var minimap_car_dot: ColorRect
var minimap_npc_dot: ColorRect
var minimap_obj_dot: ColorRect     # point objectif sur minimap
const MINIMAP_RADIUS := 70

# Overlay
var overlay_layer: CanvasLayer
var gray_overlay: ColorRect
var memo_container: CenterContainer
var memo_tex_rect: TextureRect
var memo_car_dot: ColorRect
var memo_npc_dot: ColorRect
var memo_timer_label: Label

# End screen
var end_screen: Control
var end_overlay: ColorRect
var end_vbox: VBoxContainer

# Pause menu
var pause_menu: Control
var pause_overlay: ColorRect
var game_paused: bool = false

# Textures
var minimap_image: Image
var minimap_texture: ImageTexture
var memo_texture: ImageTexture
var building_textures: Array[Texture2D] = []
var npc_textures: Array[Texture2D] = []
var deco_textures: Array[Texture2D] = []

# NPC animation
var npc_anim_timer: float = 0.0
var npc_anim_frame: int = 0
var npc_frame_w: int = 112
var npc_frame_h: int = 130
const NPC_ANIM_SPEED := 0.5

var objective_pos: Vector2 = Vector2.ZERO

var bonus_pos: Vector2 = Vector2.ZERO
var bonus_sprite: Sprite2D = null
var bonus_area: Area2D = null
var bonus_collected: bool = false
var bonus_color := Color("827bba")

# =============================================================
#  READY
# =============================================================
func _ready() -> void:
	randomize()
	PRE_COUNTDOWN_TIME = GameData.pre_countdown_time
	MEMORIZE_TIME = GameData.memorize_time
	RACE_COUNTDOWN_TIME = GameData.race_countdown_time
	_load_textures()
	_load_firstmap()
	_spawn_car()
	_spawn_npc()
	_spawn_bonus()
	_generate_minimap_textures()
	_setup_camera()
	_create_hud()
	_create_overlay()
	# CanvasModulate pour le tour sombre (enfant du Node2D principal, pas du CanvasLayer)
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color.WHITE
	add_child(canvas_modulate)
	_create_end_screen()
	_create_pause_menu()

	countdown_sound = AudioStreamPlayer.new()
	var cd_stream = load("res://sounds/321-go.mp3")
	if cd_stream:
		countdown_sound.stream = cd_stream
		add_child(countdown_sound)
	race_music = AudioStreamPlayer.new()
	add_child(race_music)

	menu_music = AudioStreamPlayer.new()
	var menu_stream = load("res://sounds/menu_sound_track.mp3")
	if menu_stream:
		menu_stream.loop = true
		menu_music.stream = menu_stream
		menu_music.volume_db = -5.0
		add_child(menu_music)

	_start_phase(Phase.PRE_COUNTDOWN)


# =============================================================
#  PROCESS
# =============================================================
func _process(delta: float) -> void:
	if game_paused:
		return
	_update_phase(delta)
	_update_camera()
	_update_decor_reveal()
	_update_hud()
	_update_minimap_dots()
	_update_npc_animation(delta)
	_check_sidewalk_penalty()
	_keep_car_on_road()
	_update_wall_cooldown(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if end_screen and end_screen.visible:
			return
		_toggle_pause()


# =============================================================
#  CHARGEMENT TEXTURES
# =============================================================
# Tile textures
var street_textures: Array[Texture2D] = []
var sidewalk_tex: Texture2D
var bricks_tex: Texture2D
var sw_corner_textures: Array[Texture2D] = []
var bricks_corner_textures: Array[Texture2D] = []

func _load_textures() -> void:
	# Buildings
	for i in range(1, 11):
		var path := "res://map_spritesheets/building_%02d.png" % i
		if ResourceLoader.exists(path):
			building_textures.append(load(path))

	# NPCs
	var npc_names := ["atok", "chinese_woman", "indian_woman", "malay_woman", "uncle_fisherman", "village_head"]
	for n in npc_names:
		var path := "res://npc/%s.png" % n
		if ResourceLoader.exists(path):
			npc_textures.append(load(path))

	# Decos (charger plus de decos)
	var deco_ids := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 24, 25]
	for i in deco_ids:
		var path := "res://map_spritesheets/deco_%02d.png" % i
		if ResourceLoader.exists(path):
			deco_textures.append(load(path))

	# Street tiles
	for name in ["street_tile_1", "street_tile_2", "street_tile_2_1", "street_tile_4"]:
		var path := "res://map_spritesheets/%s.png" % name
		if ResourceLoader.exists(path):
			street_textures.append(load(path))

	# Sidewalk pattern
	if ResourceLoader.exists("res://map_spritesheets/sidewalk_pattern.png"):
		sidewalk_tex = load("res://map_spritesheets/sidewalk_pattern.png")

	# Bricks pattern
	if ResourceLoader.exists("res://map_spritesheets/bricks_pattern.png"):
		bricks_tex = load("res://map_spritesheets/bricks_pattern.png")

	# Sidewalk corners
	for name in ["sidewalk_corner_0", "sidewalk_corner_00", "sidewalk_corner_1", "sidewalk_corner_2", "sidewalk_corner_3"]:
		var path := "res://map_spritesheets/%s.png" % name
		if ResourceLoader.exists(path):
			sw_corner_textures.append(load(path))

	# Bricks corners
	for name in ["bricks_corner_0", "bricks_corner_00"]:
		var path := "res://map_spritesheets/%s.png" % name
		if ResourceLoader.exists(path):
			bricks_corner_textures.append(load(path))


# =============================================================
#  CHARGEMENT FIRSTMAP (dynamique depuis FirstMap.png)
# =============================================================
func _load_image(path: String) -> Image:
	var img: Image = null
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			img = tex.get_image()
	else:
		img = Image.new()
		var err := img.load(path)
		if err != OK:
			push_error("Echec chargement image: " + path)
			return null
	if img == null:
		return null
	# Toujours convertir en RGBA8 pour que get_pixel() fonctionne correctement
	# (les textures importees peuvent etre compressees VRAM)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	print("Image chargee: %s (%dx%d, format=%d)" % [path, img.get_width(), img.get_height(), img.get_format()])
	return img


func _load_firstmap() -> void:
	# --- Charger les deux couches ---
	var ground_img := _load_image("res://maps/first_map/FirstMapGround.png")
	var decor_img := _load_image("res://maps/first_map/FirstMapDecor.png")

	if ground_img == null:
		push_error("Impossible de charger FirstMapGround.png!")
		_generate_grid()
		_build_map_visuals()
		_build_collisions()
		_choose_spawns()
		return

	var img_w := ground_img.get_width()
	var img_h := ground_img.get_height()

	# Sous-echantillonnage si image trop grande (max ~200 cellules par dimension)
	var max_grid_dim := 200
	var sample_rate := 1
	if maxi(img_w, img_h) > max_grid_dim:
		sample_rate = ceili(float(maxi(img_w, img_h)) / float(max_grid_dim))

	grid_w = img_w / sample_rate
	grid_h = img_h / sample_rate

	# CELL calcule pour une taille de map jouable (~5000px)
	var target_map_size := 5000.0
	CELL = maxi(8, int(target_map_size / float(maxi(grid_w, grid_h))))
	map_px_w = grid_w * CELL
	map_px_h = grid_h * CELL

	# Taille memo adaptee a la grille
	memo_cell_size = maxi(2, mini(12, 600 / maxi(grid_w, grid_h)))

	# Couleurs de reference
	var road_colors: Array[Color] = [
		Color("6c627a"),
		Color("d3d0d7"),
	]
	var sidewalk_colors: Array[Color] = [
		Color("b7bcbb"),
		Color("7e8e8a"),
		Color("363b56"),
		Color("6f7d7a"),
	]

	# --- Passe 1 : Decor en premier. Tout pixel visible = MUR ---
	grid.clear()
	var has_decor: Array = []  # tracker ou le decor pose des murs
	for gy in grid_h:
		var row: Array[int] = []
		var decor_row: Array[bool] = []
		for gx in grid_w:
			row.append(C_BUILDING)  # par defaut tout est mur
			decor_row.append(false)
		grid.append(row)
		has_decor.append(decor_row)

	if decor_img != null:
		var dw := decor_img.get_width()
		var dh := decor_img.get_height()
		# Le ratio peut differer du ground si les images n'ont pas la meme taille
		var d_sample_x := float(dw) / float(grid_w)
		var d_sample_y := float(dh) / float(grid_h)
		for gy in grid_h:
			for gx in grid_w:
				var px := mini(int(gx * d_sample_x + d_sample_x / 2.0), dw - 1)
				var py := mini(int(gy * d_sample_y + d_sample_y / 2.0), dh - 1)
				var pixel := decor_img.get_pixel(px, py)
				if pixel.a > 0.3:
					has_decor[gy][gx] = true
					# C_BUILDING deja mis par defaut

	# --- Passe 2 : Ground. Route overwrite tout. Trottoir overwrite sauf decor ---
	# Aussi detecter la couleur bonus #827bba
	var bonus_pixels: Array[Vector2i] = []
	for gy in grid_h:
		for gx in grid_w:
			var px := mini(gx * sample_rate + sample_rate / 2, img_w - 1)
			var py := mini(gy * sample_rate + sample_rate / 2, img_h - 1)
			var pixel := ground_img.get_pixel(px, py)
			if pixel.a < 0.3:
				continue  # transparent = garder le mur

			# Detecter la couleur bonus
			if _color_distance(pixel, bonus_color) < 0.15:
				bonus_pixels.append(Vector2i(gx, gy))
				grid[gy][gx] = C_ROAD  # le bonus est sur la route
				continue

			var cell_type := _classify_pixel(pixel, road_colors, sidewalk_colors)

			if cell_type == C_ROAD:
				# La route gagne sur TOUT (meme le decor)
				grid[gy][gx] = C_ROAD
			elif cell_type == C_SIDEWALK:
				# Le trottoir ne remplace PAS les murs du decor
				if not has_decor[gy][gx]:
					grid[gy][gx] = C_SIDEWALK
			# Si c'est C_BUILDING, on garde le mur par defaut

	# Calculer la position du bonus (centre de la zone detectee)
	if bonus_pixels.size() > 0:
		var sum_x := 0
		var sum_y := 0
		for bp in bonus_pixels:
			sum_x += bp.x
			sum_y += bp.y
		var avg_x := float(sum_x) / float(bonus_pixels.size())
		var avg_y := float(sum_y) / float(bonus_pixels.size())
		bonus_pos = Vector2(avg_x * CELL + CELL / 2.0, avg_y * CELL + CELL / 2.0)
		print("Bonus detecte: %d pixels, position grille (%d, %d)" % [bonus_pixels.size(), int(avg_x), int(avg_y)])
	else:
		bonus_pos = Vector2.ZERO
		print("Aucun pixel bonus #827bba detecte")

	# Calculer col_types et row_types
	_compute_col_row_types()

	# Debug: compter les types de cellules
	var count_road := 0
	var count_sw := 0
	var count_build := 0
	for gy2 in grid_h:
		for gx2 in grid_w:
			match grid[gy2][gx2]:
				C_ROAD: count_road += 1
				C_SIDEWALK: count_sw += 1
				C_BUILDING: count_build += 1
	print("Grille: %d route, %d trottoir, %d mur (total %d)" % [count_road, count_sw, count_build, grid_w * grid_h])

	# --- Visuels : ground (z=0), voiture (z=5), decor (z=10) au-dessus ---
	map_node = $MapVisuals

	var ground_tex := ImageTexture.create_from_image(ground_img)
	var ground_spr := Sprite2D.new()
	ground_spr.texture = ground_tex
	ground_spr.centered = false
	ground_spr.scale = Vector2(
		float(map_px_w) / float(img_w),
		float(map_px_h) / float(img_h)
	)
	ground_spr.position = Vector2.ZERO
	ground_spr.z_index = 0
	map_node.add_child(ground_spr)

	if decor_img != null:
		var decor_tex := ImageTexture.create_from_image(decor_img)
		var decor_spr := Sprite2D.new()
		decor_spr.texture = decor_tex
		decor_spr.centered = false
		decor_spr.scale = Vector2(
			float(map_px_w) / float(decor_img.get_width()),
			float(map_px_h) / float(decor_img.get_height())
		)
		decor_spr.position = Vector2.ZERO
		decor_spr.z_index = 10
		map_node.add_child(decor_spr)
		# Shader qui rend le decor transparent autour de la voiture
		decor_sprite = decor_spr
		var reveal_shader := Shader.new()
		reveal_shader.code = """
shader_type canvas_item;
uniform vec2 car_pos = vec2(0.0, 0.0);
uniform vec2 map_size = vec2(1.0, 1.0);
uniform float reveal_radius = 90.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 world_pos = UV * map_size;
	float dist = length(world_pos - car_pos);
	if (dist < reveal_radius) {
		float fade = smoothstep(reveal_radius * 0.5, reveal_radius, dist);
		tex.a *= fade;
	}
	COLOR = tex;
}
"""
		var mat := ShaderMaterial.new()
		mat.shader = reveal_shader
		mat.set_shader_parameter("map_size", Vector2(map_px_w, map_px_h))
		mat.set_shader_parameter("reveal_radius", 90.0)
		decor_spr.material = mat

	# Construire les collisions (reutilise l'algo de fusion de rectangles)
	_build_custom_collisions()

	# Choisir les spawns dynamiquement
	_choose_firstmap_spawns()

	use_custom_map = true
	print("FirstMap chargee: %dx%d cellules, CELL=%d" % [grid_w, grid_h, CELL])


func _classify_pixel(pixel: Color, road_colors: Array[Color], sidewalk_colors: Array[Color]) -> int:
	if pixel.a < 0.5:
		return C_BUILDING

	var min_road_dist := 999.0
	for rc in road_colors:
		var d := _color_distance(pixel, rc)
		if d < min_road_dist:
			min_road_dist = d

	var min_sw_dist := 999.0
	for sc in sidewalk_colors:
		var d := _color_distance(pixel, sc)
		if d < min_sw_dist:
			min_sw_dist = d

	var threshold := 0.18
	if min_road_dist < min_sw_dist and min_road_dist < threshold:
		return C_ROAD
	elif min_sw_dist < threshold:
		return C_SIDEWALK
	else:
		return C_BUILDING


func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


func _compute_col_row_types() -> void:
	col_types.clear()
	row_types.clear()

	for x in grid_w:
		var road_count := 0
		var building_count := 0
		for y in grid_h:
			if grid[y][x] == C_ROAD:
				road_count += 1
			elif grid[y][x] == C_BUILDING:
				building_count += 1
		if road_count > grid_h / 4:
			col_types.append(C_ROAD)
		elif building_count > grid_h / 4:
			col_types.append(C_BUILDING)
		else:
			col_types.append(C_SIDEWALK)

	for y in grid_h:
		var road_count := 0
		var building_count := 0
		for x in grid_w:
			if grid[y][x] == C_ROAD:
				road_count += 1
			elif grid[y][x] == C_BUILDING:
				building_count += 1
		if road_count > grid_w / 4:
			row_types.append(C_ROAD)
		elif building_count > grid_w / 4:
			row_types.append(C_BUILDING)
		else:
			row_types.append(C_SIDEWALK)


func _measure_road_run(cx: int, cy: int, dx: int, dy: int) -> int:
	## Compte le nombre de cellules route consecutives depuis (cx,cy) dans la direction (dx,dy).
	var count := 0
	var x := cx + dx
	var y := cy + dy
	while x >= 0 and x < grid_w and y >= 0 and y < grid_h and grid[y][x] == C_ROAD:
		count += 1
		x += dx
		y += dy
	return count


func _find_road_center_pos(cell: Vector2i, horizontal_road: bool) -> Vector2:
	## Trouve le centre exact de la bande de route.
	## horizontal_road = true => la route va a gauche/droite, on centre verticalement
	## horizontal_road = false => la route va haut/bas, on centre horizontalement
	var cx := cell.x
	var cy := cell.y
	if horizontal_road:
		# Chercher les limites verticales de la route
		var y_min := cy
		var y_max := cy
		while y_min > 0 and grid[y_min - 1][cx] == C_ROAD:
			y_min -= 1
		while y_max < grid_h - 1 and grid[y_max + 1][cx] == C_ROAD:
			y_max += 1
		var center_y := (float(y_min) + float(y_max) + 1.0) / 2.0 * CELL
		return Vector2(cx * CELL + CELL / 2.0, center_y)
	else:
		# Chercher les limites horizontales de la route
		var x_min := cx
		var x_max := cx
		while x_min > 0 and grid[cy][x_min - 1] == C_ROAD:
			x_min -= 1
		while x_max < grid_w - 1 and grid[cy][x_max + 1] == C_ROAD:
			x_max += 1
		var center_x := (float(x_min) + float(x_max) + 1.0) / 2.0 * CELL
		return Vector2(center_x, cy * CELL + CELL / 2.0)


func _choose_firstmap_spawns() -> void:
	# === SPAWN VOITURE : au hasard dans un des 4 coins de la map ===
	var quarter_w := maxi(grid_w / 4, 2)
	var quarter_h := maxi(grid_h / 4, 2)

	var corners := [
		{"x0": 0, "x1": quarter_w, "y0": 0, "y1": quarter_h},
		{"x0": grid_w - quarter_w, "x1": grid_w, "y0": 0, "y1": quarter_h},
		{"x0": 0, "x1": quarter_w, "y0": grid_h - quarter_h, "y1": grid_h},
		{"x0": grid_w - quarter_w, "x1": grid_w, "y0": grid_h - quarter_h, "y1": grid_h},
	]

	var corner_indices := [0, 1, 2, 3]
	corner_indices.shuffle()

	var car_placed := false
	for ci in corner_indices:
		var c: Dictionary = corners[ci]
		var road_cells: Array[Vector2i] = []
		for y in range(c["y0"], c["y1"]):
			for x in range(c["x0"], c["x1"]):
				if grid[y][x] == C_ROAD:
					road_cells.append(Vector2i(x, y))
		if road_cells.size() > 0:
			var cell: Vector2i = road_cells[randi() % road_cells.size()]

			# Mesurer la longueur de la route dans les 4 directions
			var run_right := _measure_road_run(cell.x, cell.y, 1, 0)
			var run_left  := _measure_road_run(cell.x, cell.y, -1, 0)
			var run_down  := _measure_road_run(cell.x, cell.y, 0, 1)
			var run_up    := _measure_road_run(cell.x, cell.y, 0, -1)
			var run_h := run_right + run_left
			var run_v := run_up + run_down

			# Orientation selon le coin (vers le centre de la map)
			var is_right: bool = (ci == 1 or ci == 3)
			var is_bottom: bool = (ci == 2 or ci == 3)
			var is_horizontal := run_h >= run_v

			if is_horizontal:
				custom_car_heading = PI if is_right else 0.0
			else:
				custom_car_heading = -PI / 2.0 if is_bottom else PI / 2.0

			# Centrer la voiture au milieu de la largeur de la route
			car_start_pos = _find_road_center_pos(cell, is_horizontal)

			car_placed = true
			break

	if not car_placed:
		car_start_pos = Vector2(map_px_w / 2.0, map_px_h / 2.0)
		custom_car_heading = 0.0

	# === SPAWN PNJ : point aleatoire de la route, trottoir adjacent ===
	var all_road_cells: Array[Vector2i] = []
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] == C_ROAD:
				all_road_cells.append(Vector2i(x, y))

	all_road_cells.shuffle()

	var npc_placed := false
	for road_cell in all_road_cells:
		# Assez loin de la voiture (au moins 30% de la diagonale)
		var road_pos := Vector2(road_cell.x * CELL + CELL / 2.0, road_cell.y * CELL + CELL / 2.0)
		if road_pos.distance_to(car_start_pos) < maxf(map_px_w, map_px_h) * 0.3:
			continue

		# Chercher un trottoir adjacent
		var neighbors := [
			Vector2i(road_cell.x - 1, road_cell.y),
			Vector2i(road_cell.x + 1, road_cell.y),
			Vector2i(road_cell.x, road_cell.y - 1),
			Vector2i(road_cell.x, road_cell.y + 1),
		]
		neighbors.shuffle()

		for n in neighbors:
			if n.x >= 0 and n.x < grid_w and n.y >= 0 and n.y < grid_h:
				if grid[n.y][n.x] == C_SIDEWALK:
					npc_pos = Vector2(n.x * CELL + CELL / 2.0, n.y * CELL + CELL / 2.0)
					objective_pos = road_pos
					initial_distance = car_start_pos.distance_to(objective_pos)
					npc_placed = true
					break
		if npc_placed:
			break

	if not npc_placed:
		# Fallback : PNJ sur la route la plus loin possible
		if all_road_cells.size() > 0:
			var best_cell := all_road_cells[0]
			var best_dist := 0.0
			for rc in all_road_cells:
				var d := Vector2(rc.x * CELL, rc.y * CELL).distance_to(car_start_pos)
				if d > best_dist:
					best_dist = d
					best_cell = rc
			npc_pos = Vector2(best_cell.x * CELL + CELL / 2.0, best_cell.y * CELL + CELL / 2.0)
			objective_pos = npc_pos
		else:
			npc_pos = Vector2(map_px_w * 0.8, map_px_h * 0.8)
			objective_pos = npc_pos
		initial_distance = car_start_pos.distance_to(objective_pos)


# =============================================================
#  GENERATION GRILLE
# =============================================================
func _generate_grid() -> void:
	col_types.clear()
	row_types.clear()

	# Colonnes : [SW] [BLOCK] [SW R R SW] [BLOCK] [SW R R SW] [BLOCK] [SW]
	col_types.append(C_SIDEWALK)
	for bx in BLOCKS_X:
		for _j in BLOCK_W:
			col_types.append(C_BUILDING)
		if bx < BLOCKS_X - 1:
			col_types.append(C_SIDEWALK)
			for _j in ROAD_W:
				col_types.append(C_ROAD)
			col_types.append(C_SIDEWALK)
	col_types.append(C_SIDEWALK)

	# Lignes : [SW] [BLOCK] [SW R R SW] [BLOCK] [SW R R SW] [BLOCK] [SW]
	row_types.append(C_SIDEWALK)
	for by in BLOCKS_Y:
		for _j in BLOCK_H:
			row_types.append(C_BUILDING)
		if by < BLOCKS_Y - 1:
			row_types.append(C_SIDEWALK)
			for _j in ROAD_W:
				row_types.append(C_ROAD)
			row_types.append(C_SIDEWALK)
	row_types.append(C_SIDEWALK)

	grid_w = col_types.size()
	grid_h = row_types.size()
	map_px_w = grid_w * CELL
	map_px_h = grid_h * CELL

	grid.clear()
	for y in grid_h:
		var row: Array[int] = []
		for x in grid_w:
			var ct := col_types[x]
			var rt := row_types[y]
			if ct == C_ROAD or rt == C_ROAD:
				row.append(C_ROAD)
			elif ct == C_SIDEWALK or rt == C_SIDEWALK:
				row.append(C_SIDEWALK)
			else:
				row.append(C_BUILDING)
		grid.append(row)


# =============================================================
#  CHARGEMENT MAP CUSTOM
# =============================================================
func _load_custom_grid() -> void:
	var grid_path := custom_map_path + "/grid.png"
	var img: Image

	# Essayer de charger via le ResourceLoader (fonctionne en jeu exporte)
	if ResourceLoader.exists(grid_path):
		var tex: Texture2D = load(grid_path)
		img = tex.get_image()
	else:
		# Fallback: chargement direct (editeur)
		img = Image.new()
		var err := img.load(grid_path)
		if err != OK:
			push_error("Impossible de charger grid.png: " + grid_path)
			use_custom_map = false
			_generate_grid()
			return

	grid_w = img.get_width()
	grid_h = img.get_height()
	map_px_w = grid_w * CELL
	map_px_h = grid_h * CELL

	# Construire col_types et row_types pour compatibilite
	col_types.clear()
	row_types.clear()
	for x in grid_w:
		col_types.append(C_SIDEWALK)  # sera recalcule
	for y in grid_h:
		row_types.append(C_SIDEWALK)

	# Lire les pixels et construire la grille
	grid.clear()
	for y in grid_h:
		var row: Array[int] = []
		for x in grid_w:
			var pixel := img.get_pixel(x, y)
			var r := pixel.r
			var g := pixel.g
			var b := pixel.b
			# Blanc (>0.9) = Route
			if r > 0.9 and g > 0.9 and b > 0.9:
				row.append(C_ROAD)
			# Noir (<0.1) = Batiment
			elif r < 0.1 and g < 0.1 and b < 0.1:
				row.append(C_BUILDING)
			# Tout le reste = Trottoir
			else:
				row.append(C_SIDEWALK)
		grid.append(row)

	# Recalculer col_types/row_types (type dominant par colonne/ligne)
	for x in grid_w:
		var road_count := 0
		var building_count := 0
		for y in grid_h:
			if grid[y][x] == C_ROAD:
				road_count += 1
			elif grid[y][x] == C_BUILDING:
				building_count += 1
		if road_count > grid_h / 3:
			col_types[x] = C_ROAD
		elif building_count > grid_h / 3:
			col_types[x] = C_BUILDING

	for y in grid_h:
		var road_count := 0
		var building_count := 0
		for x in grid_w:
			if grid[y][x] == C_ROAD:
				road_count += 1
			elif grid[y][x] == C_BUILDING:
				building_count += 1
		if road_count > grid_w / 3:
			row_types[y] = C_ROAD
		elif building_count > grid_w / 3:
			row_types[y] = C_BUILDING

	print("Map custom chargee: %dx%d cellules" % [grid_w, grid_h])


func _build_custom_map_visuals() -> void:
	map_node = $MapVisuals

	# Charger le visual.png
	var visual_path := custom_map_path + "/visual.png"
	if ResourceLoader.exists(visual_path):
		custom_visual_tex = load(visual_path)
	else:
		var img := Image.new()
		var err := img.load(visual_path)
		if err != OK:
			push_error("Impossible de charger visual.png: " + visual_path)
			var bg := ColorRect.new()
			bg.color = Color(0.15, 0.15, 0.2)
			bg.size = Vector2(map_px_w, map_px_h)
			map_node.add_child(bg)
			return
		custom_visual_tex = ImageTexture.create_from_image(img)

	# Afficher le visuel etire sur toute la map
	var spr := Sprite2D.new()
	spr.texture = custom_visual_tex
	spr.centered = false
	spr.scale = Vector2(
		float(map_px_w) / float(custom_visual_tex.get_width()),
		float(map_px_h) / float(custom_visual_tex.get_height())
	)
	spr.position = Vector2.ZERO
	spr.z_index = 0
	map_node.add_child(spr)


func _build_custom_collisions() -> void:
	buildings_node = $Buildings

	# Scanner la grille pour trouver des rectangles de batiments
	# Optimisation : fusionner en rectangles
	var visited: Array = []
	for y in grid_h:
		var row: Array[bool] = []
		for x in grid_w:
			row.append(false)
		visited.append(row)

	var body_count := 0
	for y in grid_h:
		var x := 0
		while x < grid_w:
			if grid[y][x] != C_BUILDING or visited[y][x]:
				x += 1
				continue
			# Trouver la largeur du rectangle
			var rw := 0
			while x + rw < grid_w and grid[y][x + rw] == C_BUILDING and not visited[y][x + rw]:
				rw += 1
			# Trouver la hauteur du rectangle
			var rh := 1
			var can_extend := true
			while y + rh < grid_h and can_extend:
				for rx in range(x, x + rw):
					if grid[y + rh][rx] != C_BUILDING or visited[y + rh][rx]:
						can_extend = false
						break
				if can_extend:
					rh += 1
			# Marquer comme visite
			for ry in range(y, y + rh):
				for rx in range(x, x + rw):
					visited[ry][rx] = true
			# Creer le body (marge de 6px pour eviter les collisions coin)
			var collision_margin := 6.0
			var bpx := float(x * CELL)
			var bpy := float(y * CELL)
			var bpw := float(rw * CELL)
			var bph := float(rh * CELL)
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = Vector2(bpx + bpw / 2.0, bpy + bph / 2.0)
			var shape := RectangleShape2D.new()
			shape.size = Vector2(bpw - collision_margin * 2.0, bph - collision_margin * 2.0)
			var col := CollisionShape2D.new()
			col.shape = shape
			body.add_child(col)
			buildings_node.add_child(body)
			body_count += 1
			x += rw

	print("Collisions: %d bodies crees" % body_count)

	# Murs de bordure
	_add_wall_rect(Vector2(map_px_w / 2.0, -64), Vector2(map_px_w + 256, 128))
	_add_wall_rect(Vector2(map_px_w / 2.0, map_px_h + 64), Vector2(map_px_w + 256, 128))
	_add_wall_rect(Vector2(-64, map_px_h / 2.0), Vector2(128, map_px_h + 256))
	_add_wall_rect(Vector2(map_px_w + 64, map_px_h / 2.0), Vector2(128, map_px_h + 256))


func _load_custom_spawns() -> void:
	var spawns_path := custom_map_path + "/spawns.json"
	var file := FileAccess.open(spawns_path, FileAccess.READ)
	if not file:
		push_error("Impossible de charger spawns.json: " + spawns_path)
		_choose_spawns()  # fallback
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK or not json.data is Dictionary:
		push_error("Erreur de parsing spawns.json")
		_choose_spawns()
		return

	var data: Dictionary = json.data

	# Voiture
	if data.has("car") and data["car"] is Dictionary:
		var car_data: Dictionary = data["car"]
		var cx: int = int(car_data.get("x", 0))
		var cy: int = int(car_data.get("y", 0))
		var heading_deg: float = float(car_data.get("heading", -90))
		car_start_pos = Vector2(cx * CELL + CELL / 2.0, cy * CELL + CELL / 2.0)
		custom_car_heading = deg_to_rad(heading_deg)
	else:
		car_start_pos = Vector2(map_px_w / 2.0, map_px_h / 2.0)

	# PNJ
	if data.has("npc") and data["npc"] is Dictionary:
		var npc_data: Dictionary = data["npc"]
		var nx: int = int(npc_data.get("x", 0))
		var ny: int = int(npc_data.get("y", 0))
		npc_pos = Vector2(nx * CELL + CELL / 2.0, ny * CELL + CELL / 2.0)
	else:
		npc_pos = Vector2(map_px_w * 0.8, map_px_h * 0.8)

	# Trouver la case route la plus proche du NPC pour le marqueur
	var npc_cell := Vector2i(int(npc_pos.x / CELL), int(npc_pos.y / CELL))
	var best_road_dist := 99999.0
	var best_road_cell := npc_cell
	for ry in range(maxi(0, npc_cell.y - 5), mini(grid_h, npc_cell.y + 6)):
		for rx in range(maxi(0, npc_cell.x - 5), mini(grid_w, npc_cell.x + 6)):
			if grid[ry][rx] == C_ROAD:
				var rd := Vector2(rx - npc_cell.x, ry - npc_cell.y).length()
				if rd < best_road_dist:
					best_road_dist = rd
					best_road_cell = Vector2i(rx, ry)
	objective_pos = Vector2(best_road_cell.x * CELL + CELL / 2.0, best_road_cell.y * CELL + CELL / 2.0)
	initial_distance = car_start_pos.distance_to(objective_pos)


# =============================================================
#  CONSTRUCTION VISUELLE DE LA MAP (PROCEDURAL)
# =============================================================
func _build_map_visuals() -> void:
	map_node = $MapVisuals

	# Fond global sombre pour les batiments
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.size = Vector2(map_px_w, map_px_h)
	map_node.add_child(bg)

	# Placer les tiles pour chaque cellule
	for y in grid_h:
		for x in grid_w:
			var cell_type: int = grid[y][x]
			var px := float(x * CELL)
			var py := float(y * CELL)

			match cell_type:
				C_ROAD:
					_place_road_tile(px, py, x, y)
				C_SIDEWALK:
					_place_sidewalk_tile(px, py, x, y)
				C_BUILDING:
					pass

	# --- Couche 1 : marquages routiers (lignes, tirets) ---
	_place_road_markings()

	# --- Couche 2 : passages pietons aux intersections ---
	_place_crosswalks()

	# --- Couche 3 : bordures de trottoir ---
	_place_curbs()

	# --- Couche 4 : plaques d'egout ---
	_place_manholes()

	# --- Couche 5 : batiments ---
	_place_buildings()

	# --- Couche 6 : decorations (intelligentes) ---
	_place_decorations()


# ---- TILES ROUTE ----
func _place_road_tile(px: float, py: float, cx: int, cy: int) -> void:
	if street_textures.is_empty():
		var rect := ColorRect.new()
		rect.color = Color(0.22, 0.22, 0.28)
		rect.size = Vector2(CELL, CELL)
		rect.position = Vector2(px, py)
		map_node.add_child(rect)
		return

	var is_v_road := col_types[cx] == C_ROAD
	var is_h_road := row_types[cy] == C_ROAD
	var is_intersection := is_v_road and is_h_road

	var spr := Sprite2D.new()
	if is_intersection:
		spr.texture = street_textures[3] if street_textures.size() > 3 else street_textures[0]
	else:
		var idx := (cx + cy) % mini(street_textures.size(), 3)
		spr.texture = street_textures[idx]

	spr.centered = false
	var tw := float(spr.texture.get_width())
	var th := float(spr.texture.get_height())

	if is_intersection:
		spr.scale = Vector2(CELL / tw, CELL / th)
	elif is_h_road and not is_v_road:
		spr.centered = true
		spr.position = Vector2(px + CELL / 2.0, py + CELL / 2.0)
		spr.rotation = PI / 2.0
		spr.scale = Vector2(CELL / tw, CELL / th)
		map_node.add_child(spr)
		return
	else:
		spr.scale = Vector2(CELL / tw, CELL / th)

	spr.position = Vector2(px, py)
	map_node.add_child(spr)


# ---- TILES TROTTOIR ----
func _place_sidewalk_tile(px: float, py: float, cx: int, cy: int) -> void:
	var adj_road_h := false
	var adj_road_v := false
	if cx > 0 and grid[cy][cx - 1] == C_ROAD:
		adj_road_h = true
	if cx < grid_w - 1 and grid[cy][cx + 1] == C_ROAD:
		adj_road_h = true
	if cy > 0 and grid[cy - 1][cx] == C_ROAD:
		adj_road_v = true
	if cy < grid_h - 1 and grid[cy + 1][cx] == C_ROAD:
		adj_road_v = true

	var spr := Sprite2D.new()
	spr.centered = false
	spr.position = Vector2(px, py)

	var is_corner := adj_road_h and adj_road_v

	if is_corner and not sw_corner_textures.is_empty():
		var corner_tex: Texture2D = sw_corner_textures[randi() % sw_corner_textures.size()]
		spr.texture = corner_tex
		spr.scale = Vector2(CELL / float(corner_tex.get_width()), CELL / float(corner_tex.get_height()))
	elif sidewalk_tex:
		spr.texture = sidewalk_tex
		var tw := float(sidewalk_tex.get_width())
		var th := float(sidewalk_tex.get_height())
		spr.scale = Vector2(CELL / tw, CELL / th)
	else:
		var rect := ColorRect.new()
		rect.color = Color(0.45, 0.43, 0.40)
		rect.size = Vector2(CELL, CELL)
		rect.position = Vector2(px, py)
		map_node.add_child(rect)
		return

	map_node.add_child(spr)


# ---- MARQUAGES ROUTIERS (lignes centrales + bord) ----
func _place_road_markings() -> void:
	# Trouver le centre de chaque segment de route et dessiner des tirets
	var unit_w := BLOCK_W + 2 * SW_W + ROAD_W
	var unit_h := BLOCK_H + 2 * SW_W + ROAD_W

	# --- Lignes centrales tiretees (jaunes) sur routes verticales ---
	for bx in range(BLOCKS_X - 1):
		var road_center_x: int = 1 + BLOCK_W + SW_W + 1  # colonne centrale de la route (milieu de ROAD_W=3)
		for i in bx:
			road_center_x += unit_w
		# Parcourir toute la hauteur de la grille
		for y in grid_h:
			if grid[y][road_center_x] != C_ROAD:
				continue
			# Intersection : pas de ligne centrale
			if col_types[road_center_x] == C_ROAD and row_types[y] == C_ROAD:
				continue
			# Tiret 1 sur 2 (alternance par cellule)
			if y % 2 == 0:
				var dash := ColorRect.new()
				dash.color = Color(0.95, 0.82, 0.2, 0.7)
				dash.size = Vector2(4, CELL * 0.6)
				dash.position = Vector2(road_center_x * CELL + CELL / 2.0 - 2, y * CELL + CELL * 0.2)
				dash.z_index = 1
				map_node.add_child(dash)

	# --- Lignes centrales tiretees (jaunes) sur routes horizontales ---
	for by in range(BLOCKS_Y - 1):
		var road_center_y: int = 1 + BLOCK_H + SW_W + 1
		for i in by:
			road_center_y += unit_h
		for x in grid_w:
			if grid[road_center_y][x] != C_ROAD:
				continue
			if col_types[x] == C_ROAD and row_types[road_center_y] == C_ROAD:
				continue
			if x % 2 == 0:
				var dash := ColorRect.new()
				dash.color = Color(0.95, 0.82, 0.2, 0.7)
				dash.size = Vector2(CELL * 0.6, 4)
				dash.position = Vector2(x * CELL + CELL * 0.2, road_center_y * CELL + CELL / 2.0 - 2)
				dash.z_index = 1
				map_node.add_child(dash)


# ---- PASSAGES PIETONS ----
func _place_crosswalks() -> void:
	var unit_w := BLOCK_W + 2 * SW_W + ROAD_W
	var unit_h := BLOCK_H + 2 * SW_W + ROAD_W

	# Pour chaque intersection (croisement de route V et H)
	for by in range(BLOCKS_Y - 1):
		for bx in range(BLOCKS_X - 1):
			# Centre de l'intersection en cellules
			var ix: int = 1 + BLOCK_W + SW_W + 1
			var iy: int = 1 + BLOCK_H + SW_W + 1
			for i in bx:
				ix += unit_w
			for i in by:
				iy += unit_h

			# Passage pieton en HAUT de l'intersection (bandes horizontales)
			_draw_crosswalk_h(ix, iy - 1)
			# Passage pieton en BAS de l'intersection
			_draw_crosswalk_h(ix, iy + 1)
			# Passage pieton a GAUCHE (bandes verticales)
			_draw_crosswalk_v(ix - 1, iy)
			# Passage pieton a DROITE
			_draw_crosswalk_v(ix + 1, iy)


func _draw_crosswalk_h(cx: int, cy: int) -> void:
	# Bandes blanches horizontales sur la largeur de la route (ROAD_W cellules)
	var stripe_count := 6
	var stripe_h := 6.0
	var gap := (float(CELL) - stripe_count * stripe_h) / float(stripe_count + 1)

	for rx in range(-1, 2):  # 3 cellules de large (ROAD_W = 3)
		var cell_x := cx + rx
		if cell_x < 0 or cell_x >= grid_w or cy < 0 or cy >= grid_h:
			continue
		if grid[cy][cell_x] != C_ROAD:
			continue
		var px := float(cell_x * CELL)
		var py := float(cy * CELL)
		for s in stripe_count:
			var stripe := ColorRect.new()
			stripe.color = Color(0.95, 0.95, 0.92, 0.85)
			stripe.size = Vector2(CELL * 0.85, stripe_h)
			stripe.position = Vector2(px + CELL * 0.075, py + gap + s * (stripe_h + gap))
			stripe.z_index = 2
			map_node.add_child(stripe)


func _draw_crosswalk_v(cx: int, cy: int) -> void:
	# Bandes blanches verticales sur la hauteur de la route
	var stripe_count := 6
	var stripe_w := 6.0
	var gap := (float(CELL) - stripe_count * stripe_w) / float(stripe_count + 1)

	for ry in range(-1, 2):
		var cell_y := cy + ry
		if cx < 0 or cx >= grid_w or cell_y < 0 or cell_y >= grid_h:
			continue
		if grid[cell_y][cx] != C_ROAD:
			continue
		var px := float(cx * CELL)
		var py := float(cell_y * CELL)
		for s in stripe_count:
			var stripe := ColorRect.new()
			stripe.color = Color(0.95, 0.95, 0.92, 0.85)
			stripe.size = Vector2(stripe_w, CELL * 0.85)
			stripe.position = Vector2(px + gap + s * (stripe_w + gap), py + CELL * 0.075)
			stripe.z_index = 2
			map_node.add_child(stripe)


# ---- BORDURES DE TROTTOIR ----
func _place_curbs() -> void:
	# Ligne fine entre le trottoir et la route
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_SIDEWALK:
				continue
			var px := float(x * CELL)
			var py := float(y * CELL)

			# Bordure cote route (bord interieur du trottoir)
			# A droite
			if x < grid_w - 1 and grid[y][x + 1] == C_ROAD:
				var curb := ColorRect.new()
				curb.color = Color(0.62, 0.60, 0.55, 0.9)
				curb.size = Vector2(4, CELL)
				curb.position = Vector2(px + CELL - 2, py)
				curb.z_index = 2
				map_node.add_child(curb)
			# A gauche
			if x > 0 and grid[y][x - 1] == C_ROAD:
				var curb := ColorRect.new()
				curb.color = Color(0.62, 0.60, 0.55, 0.9)
				curb.size = Vector2(4, CELL)
				curb.position = Vector2(px - 2, py)
				curb.z_index = 2
				map_node.add_child(curb)
			# En bas
			if y < grid_h - 1 and grid[y + 1][x] == C_ROAD:
				var curb := ColorRect.new()
				curb.color = Color(0.62, 0.60, 0.55, 0.9)
				curb.size = Vector2(CELL, 4)
				curb.position = Vector2(px, py + CELL - 2)
				curb.z_index = 2
				map_node.add_child(curb)
			# En haut
			if y > 0 and grid[y - 1][x] == C_ROAD:
				var curb := ColorRect.new()
				curb.color = Color(0.62, 0.60, 0.55, 0.9)
				curb.size = Vector2(CELL, 4)
				curb.position = Vector2(px, py - 2)
				curb.z_index = 2
				map_node.add_child(curb)


# ---- PLAQUES D'EGOUT ----
func _place_manholes() -> void:
	var unit_w := BLOCK_W + 2 * SW_W + ROAD_W
	var unit_h := BLOCK_H + 2 * SW_W + ROAD_W

	for by in range(BLOCKS_Y - 1):
		for bx in range(BLOCKS_X - 1):
			var ix: int = 1 + BLOCK_W + SW_W + 1
			var iy: int = 1 + BLOCK_H + SW_W + 1
			for i in bx:
				ix += unit_w
			for i in by:
				iy += unit_h

			# Plaque d'egout au centre de chaque intersection
			var mh_size := 20.0
			var mh_pos := Vector2(ix * CELL + CELL / 2.0 - mh_size / 2.0, iy * CELL + CELL / 2.0 - mh_size / 2.0)

			# Cercle exterieur
			var outer := _create_circle_sprite(mh_size, Color(0.18, 0.18, 0.22, 0.9))
			outer.position = mh_pos + Vector2(mh_size / 2.0, mh_size / 2.0)
			outer.z_index = 2
			map_node.add_child(outer)

			# Grille (croix a l'interieur)
			var cross_h := ColorRect.new()
			cross_h.color = Color(0.12, 0.12, 0.15, 0.8)
			cross_h.size = Vector2(mh_size * 0.7, 2)
			cross_h.position = Vector2(mh_pos.x + mh_size * 0.15, mh_pos.y + mh_size / 2.0 - 1)
			cross_h.z_index = 3
			map_node.add_child(cross_h)

			var cross_v := ColorRect.new()
			cross_v.color = Color(0.12, 0.12, 0.15, 0.8)
			cross_v.size = Vector2(2, mh_size * 0.7)
			cross_v.position = Vector2(mh_pos.x + mh_size / 2.0 - 1, mh_pos.y + mh_size * 0.15)
			cross_v.z_index = 3
			map_node.add_child(cross_v)

	# Aussi quelques plaques aleatoires sur les routes non-intersection
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_ROAD:
				continue
			if col_types[x] == C_ROAD and row_types[y] == C_ROAD:
				continue  # deja une plaque a l'intersection
			if randf() > 0.03:
				continue
			var mh_s := 14.0
			var mh_spr := _create_circle_sprite(mh_s, Color(0.16, 0.16, 0.20, 0.7))
			mh_spr.position = Vector2(
				x * CELL + CELL / 2.0 + randf_range(-20, 20),
				y * CELL + CELL / 2.0 + randf_range(-20, 20)
			)
			mh_spr.z_index = 2
			map_node.add_child(mh_spr)


func _create_circle_sprite(diameter: float, color: Color) -> Sprite2D:
	var size_i := int(diameter)
	var img := Image.create(size_i, size_i, false, Image.FORMAT_RGBA8)
	var center := diameter / 2.0
	var radius := center - 1.0
	for px in size_i:
		for py in size_i:
			var dist := Vector2(px - center, py - center).length()
			if dist <= radius:
				img.set_pixel(px, py, color)
			elif dist <= radius + 1.0:
				var edge_a := (radius + 1.0 - dist) * color.a
				img.set_pixel(px, py, Color(color.r, color.g, color.b, edge_a))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	return spr


# ---- BATIMENTS ----
func _place_buildings() -> void:
	if building_textures.is_empty():
		return

	var unit_w := BLOCK_W + 2 * SW_W + ROAD_W
	var unit_h := BLOCK_H + 2 * SW_W + ROAD_W

	for by in BLOCKS_Y:
		for bx in BLOCKS_X:
			var cell_x: int = 1
			var cell_y: int = 1
			for i in bx:
				cell_x += unit_w
			for i in by:
				cell_y += unit_h

			var block_px := cell_x * CELL
			var block_py := cell_y * CELL
			var block_pw := BLOCK_W * CELL
			var block_ph := BLOCK_H * CELL

			# Fond briques pour le block
			if bricks_tex:
				var bspr := Sprite2D.new()
				bspr.texture = bricks_tex
				bspr.centered = false
				bspr.scale = Vector2(float(block_pw) / float(bricks_tex.get_width()), float(block_ph) / float(bricks_tex.get_height()))
				bspr.position = Vector2(block_px, block_py)
				bspr.z_index = 0
				map_node.add_child(bspr)

			# Coins de briques decoratifs
			if not bricks_corner_textures.is_empty():
				_place_brick_corners(block_px, block_py, block_pw, block_ph)

			# Placer 1 a 3 batiments par block (plus varie)
			var num_buildings := randi_range(1, 3)
			var used_tex_indices: Array[int] = []  # eviter les doublons
			for bi in num_buildings:
				# Choisir un batiment non encore utilise dans ce block
				var tex_idx := randi() % building_textures.size()
				var attempts := 0
				while tex_idx in used_tex_indices and attempts < 10:
					tex_idx = randi() % building_textures.size()
					attempts += 1
				used_tex_indices.append(tex_idx)

				var tex: Texture2D = building_textures[tex_idx]
				var spr := Sprite2D.new()
				spr.texture = tex
				# Taille adaptee selon le nombre de batiments
				var max_w: float
				var max_h: float
				if num_buildings == 1:
					max_w = block_pw * 0.85
					max_h = block_ph * 0.85
				elif num_buildings == 2:
					max_w = block_pw * 0.45
					max_h = block_ph * 0.8
				else:
					max_w = block_pw * 0.35
					max_h = block_ph * 0.7
				var sx := max_w / float(tex.get_width())
				var sy := max_h / float(tex.get_height())
				var s := minf(sx, sy)
				spr.scale = Vector2(s, s)
				# Position bien repartie dans le block
				var offset_x := 0.0
				var offset_y := 0.0
				if num_buildings == 2:
					offset_x = (float(bi) - 0.5) * block_pw * 0.28
				elif num_buildings == 3:
					if bi == 0:
						offset_x = -block_pw * 0.25
						offset_y = -block_ph * 0.12
					elif bi == 1:
						offset_x = block_pw * 0.25
						offset_y = -block_ph * 0.12
					else:
						offset_y = block_ph * 0.2
				spr.position = Vector2(
					block_px + block_pw / 2.0 + offset_x + randf_range(-8, 8),
					block_py + block_ph / 2.0 + offset_y + randf_range(-5, 5)
				)
				spr.z_index = 1
				map_node.add_child(spr)


func _place_brick_corners(bx: float, by: float, bw: float, bh: float) -> void:
	# Placer des coins decoratifs de briques aux 4 coins du block
	var corner0: Texture2D = bricks_corner_textures[0]
	var corner1: Texture2D = bricks_corner_textures[mini(1, bricks_corner_textures.size() - 1)]
	var corner_scale := 1.2

	# Coin haut-gauche
	var c_tl := Sprite2D.new()
	c_tl.texture = corner0
	c_tl.centered = false
	c_tl.position = Vector2(bx - 4, by - 4)
	c_tl.scale = Vector2(corner_scale, corner_scale)
	c_tl.z_index = 2
	map_node.add_child(c_tl)

	# Coin haut-droit (flip H)
	var c_tr := Sprite2D.new()
	c_tr.texture = corner1
	c_tr.centered = false
	c_tr.position = Vector2(bx + bw + 4, by - 4)
	c_tr.scale = Vector2(-corner_scale, corner_scale)
	c_tr.z_index = 2
	map_node.add_child(c_tr)

	# Coin bas-gauche (flip V)
	var c_bl := Sprite2D.new()
	c_bl.texture = corner1
	c_bl.centered = false
	c_bl.position = Vector2(bx - 4, by + bh + 4)
	c_bl.scale = Vector2(corner_scale, -corner_scale)
	c_bl.z_index = 2
	map_node.add_child(c_bl)

	# Coin bas-droit (flip H+V)
	var c_br := Sprite2D.new()
	c_br.texture = corner0
	c_br.centered = false
	c_br.position = Vector2(bx + bw + 4, by + bh + 4)
	c_br.scale = Vector2(-corner_scale, -corner_scale)
	c_br.z_index = 2
	map_node.add_child(c_br)


# ---- DECORATIONS INTELLIGENTES ----
func _place_decorations() -> void:
	if deco_textures.is_empty():
		return

	# Categoriser les decos par taille pour un placement intelligent
	# Petits (arbustes, poubelles) : taille < 100px max dim
	# Moyens (bancs, lampadaires) : taille 100-200px
	# Grands (arbres, panneaux) : taille > 200px
	var small_decos: Array[Texture2D] = []
	var medium_decos: Array[Texture2D] = []
	var large_decos: Array[Texture2D] = []

	for tex in deco_textures:
		var max_dim := maxi(tex.get_width(), tex.get_height())
		if max_dim < 110:
			small_decos.append(tex)
		elif max_dim < 220:
			medium_decos.append(tex)
		else:
			large_decos.append(tex)

	# --- Pass 1 : Lampadaires / grands decos aux coins (trottoir qui touche 2 routes) ---
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_SIDEWALK:
				continue
			var adj_r := _count_adjacent_roads(x, y)
			if adj_r >= 2 and not large_decos.is_empty():
				# Coin : placer un grand deco (lampadaire, arbre)
				if randf() < 0.7:
					var tex: Texture2D = large_decos[randi() % large_decos.size()]
					var spr := Sprite2D.new()
					spr.texture = tex
					var max_d := float(maxi(tex.get_width(), tex.get_height()))
					var s := CELL * 0.55 / max_d
					spr.scale = Vector2(s, s)
					spr.position = Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0)
					spr.z_index = 2
					map_node.add_child(spr)
					continue

	# --- Pass 2 : Decos moyens le long des routes (bancs, poubelles) ---
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_SIDEWALK:
				continue
			var adj_r := _count_adjacent_roads(x, y)
			if adj_r == 1 and not medium_decos.is_empty():
				if randf() < 0.22:
					var tex: Texture2D = medium_decos[randi() % medium_decos.size()]
					var spr := Sprite2D.new()
					spr.texture = tex
					var max_d := float(maxi(tex.get_width(), tex.get_height()))
					var s := CELL * randf_range(0.4, 0.55) / max_d
					spr.scale = Vector2(s, s)
					# Decaler vers le cote du batiment (loin de la route)
					var off := _get_building_side_offset(x, y)
					spr.position = Vector2(
						x * CELL + CELL / 2.0 + off.x * 15.0,
						y * CELL + CELL / 2.0 + off.y * 15.0
					)
					spr.z_index = 2
					map_node.add_child(spr)

	# --- Pass 3 : Petits decos partout sur les trottoirs restants ---
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_SIDEWALK:
				continue
			if randf() > 0.10:
				continue
			var pool: Array[Texture2D] = small_decos if not small_decos.is_empty() else deco_textures
			var tex: Texture2D = pool[randi() % pool.size()]
			var spr := Sprite2D.new()
			spr.texture = tex
			var max_d := float(maxi(tex.get_width(), tex.get_height()))
			var s := CELL * randf_range(0.25, 0.45) / max_d
			spr.scale = Vector2(s, s)
			spr.position = Vector2(
				x * CELL + CELL / 2.0 + randf_range(-25, 25),
				y * CELL + CELL / 2.0 + randf_range(-25, 25)
			)
			spr.z_index = 2
			map_node.add_child(spr)


func _count_adjacent_roads(x: int, y: int) -> int:
	var count := 0
	if x > 0 and grid[y][x - 1] == C_ROAD:
		count += 1
	if x < grid_w - 1 and grid[y][x + 1] == C_ROAD:
		count += 1
	if y > 0 and grid[y - 1][x] == C_ROAD:
		count += 1
	if y < grid_h - 1 and grid[y + 1][x] == C_ROAD:
		count += 1
	return count


func _get_building_side_offset(x: int, y: int) -> Vector2:
	# Retourne un vecteur pointant vers le cote batiment (oppose a la route)
	var offset := Vector2.ZERO
	if x > 0 and grid[y][x - 1] == C_ROAD:
		offset.x += 1.0  # route a gauche -> decaler a droite
	if x < grid_w - 1 and grid[y][x + 1] == C_ROAD:
		offset.x -= 1.0
	if y > 0 and grid[y - 1][x] == C_ROAD:
		offset.y += 1.0
	if y < grid_h - 1 and grid[y + 1][x] == C_ROAD:
		offset.y -= 1.0
	return offset


# =============================================================
#  COLLISIONS
# =============================================================
func _build_collisions() -> void:
	buildings_node = $Buildings

	var unit_w := BLOCK_W + 2 * SW_W + ROAD_W
	var unit_h := BLOCK_H + 2 * SW_W + ROAD_W

	for by in BLOCKS_Y:
		for bx in BLOCKS_X:
			var cell_x: int = 1
			var cell_y: int = 1
			for i in bx:
				cell_x += unit_w
			for i in by:
				cell_y += unit_h

			var collision_margin := 6.0
			var block_px := float(cell_x * CELL)
			var block_py := float(cell_y * CELL)
			var block_pw := float(BLOCK_W * CELL)
			var block_ph := float(BLOCK_H * CELL)

			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.position = Vector2(block_px + block_pw / 2.0, block_py + block_ph / 2.0)
			var shape := RectangleShape2D.new()
			shape.size = Vector2(block_pw - collision_margin * 2.0, block_ph - collision_margin * 2.0)
			var col := CollisionShape2D.new()
			col.shape = shape
			body.add_child(col)
			buildings_node.add_child(body)

	# Murs de bordure
	_add_wall_rect(Vector2(map_px_w / 2.0, -64), Vector2(map_px_w + 256, 128))
	_add_wall_rect(Vector2(map_px_w / 2.0, map_px_h + 64), Vector2(map_px_w + 256, 128))
	_add_wall_rect(Vector2(-64, map_px_h / 2.0), Vector2(128, map_px_h + 256))
	_add_wall_rect(Vector2(map_px_w + 64, map_px_h / 2.0), Vector2(128, map_px_h + 256))


func _add_wall_rect(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	buildings_node.add_child(body)


# =============================================================
#  SPAWNS
# =============================================================
func _choose_spawns() -> void:
	# Trouver des cellules de route pas aux intersections
	var road_cells: Array[Vector2i] = []
	var sidewalk_cells: Array[Vector2i] = []

	for y in grid_h:
		for x in grid_w:
			if grid[y][x] == C_ROAD:
				# Pas a une intersection (un seul axe est route)
				var col_is_road := col_types[x] == C_ROAD
				var row_is_road := row_types[y] == C_ROAD
				if col_is_road != row_is_road:
					road_cells.append(Vector2i(x, y))
			elif grid[y][x] == C_SIDEWALK:
				# Adjacent a une route
				if _cell_adjacent_to(x, y, C_ROAD):
					sidewalk_cells.append(Vector2i(x, y))

	road_cells.shuffle()
	sidewalk_cells.shuffle()

	# Choisir le spawn voiture
	if road_cells.size() > 0:
		var c: Vector2i = road_cells[0]
		# Orientation selon la direction de la route
		var is_horizontal := row_types[c.y] == C_ROAD
		if col_types[c.x] == C_ROAD:
			custom_car_heading = -PI / 2.0   # route verticale => vers le haut
			is_horizontal = false
		elif is_horizontal:
			custom_car_heading = 0.0          # route horizontale => vers la droite
		# Centrer la voiture au milieu de la largeur de la route
		car_start_pos = _find_road_center_pos(c, is_horizontal)
	else:
		car_start_pos = Vector2(map_px_w / 2.0, map_px_h / 2.0)
		custom_car_heading = 0.0

	# Choisir le spawn NPC le plus loin possible
	var best_dist := 0.0
	if sidewalk_cells.size() > 0:
		npc_pos = Vector2(sidewalk_cells[0].x * CELL + CELL / 2.0, sidewalk_cells[0].y * CELL + CELL / 2.0)
	for sc in sidewalk_cells:
		var p := Vector2(sc.x * CELL + CELL / 2.0, sc.y * CELL + CELL / 2.0)
		var d := p.distance_to(car_start_pos)
		if d > best_dist:
			best_dist = d
			npc_pos = p

	# Trouver la case route la plus proche du NPC pour le marqueur jaune
	var npc_cell := Vector2i(int(npc_pos.x / CELL), int(npc_pos.y / CELL))
	var best_road_dist := 99999.0
	var best_road_cell := npc_cell
	for ry in range(maxi(0, npc_cell.y - 3), mini(grid_h, npc_cell.y + 4)):
		for rx in range(maxi(0, npc_cell.x - 3), mini(grid_w, npc_cell.x + 4)):
			if grid[ry][rx] == C_ROAD:
				var rd := Vector2(rx - npc_cell.x, ry - npc_cell.y).length()
				if rd < best_road_dist:
					best_road_dist = rd
					best_road_cell = Vector2i(rx, ry)
	objective_pos = Vector2(best_road_cell.x * CELL + CELL / 2.0, best_road_cell.y * CELL + CELL / 2.0)

	initial_distance = car_start_pos.distance_to(objective_pos)


func _cell_adjacent_to(x: int, y: int, cell_type: int) -> bool:
	if x > 0 and grid[y][x - 1] == cell_type:
		return true
	if x < grid_w - 1 and grid[y][x + 1] == cell_type:
		return true
	if y > 0 and grid[y - 1][x] == cell_type:
		return true
	if y < grid_h - 1 and grid[y + 1][x] == cell_type:
		return true
	return false


# =============================================================
#  SPAWN VOITURE ET PNJ
# =============================================================
func _spawn_car() -> void:
	car = car_scene.instantiate()
	car.z_index = 5   # Sous le decor (z=10) — visible via shader reveal
	add_child(car)
	car.reset_to(car_start_pos, custom_car_heading)
	car.active = false
	car.map_bounds = Rect2(Vector2.ZERO, Vector2(map_px_w, map_px_h))
	car.hit_wall.connect(_on_car_hit_wall)
	last_safe_car_pos = car_start_pos


func _spawn_npc() -> void:
	if npc_textures.is_empty():
		return

	# Zone objectif (cercle jaune sur la ROUTE, pas sur le NPC)
	var obj_visual := Sprite2D.new()
	var circle_img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for px in 128:
		for py in 128:
			var dist := Vector2(px - 64, py - 64).length()
			if dist < 56.0:
				var alpha := 0.35 - dist * 0.003
				circle_img.set_pixel(px, py, Color(1.0, 0.85, 0.15, maxf(alpha, 0.05)))
			else:
				circle_img.set_pixel(px, py, Color(0, 0, 0, 0))
	obj_visual.texture = ImageTexture.create_from_image(circle_img)
	obj_visual.position = objective_pos
	obj_visual.z_index = 12
	add_child(obj_visual)

	# Pulse animation sur la zone objectif
	var tween := create_tween().set_loops()
	tween.tween_property(obj_visual, "modulate:a", 0.5, 0.8).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(obj_visual, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT)

	# Sprite PNJ (spritesheet 2 frames idle cote a cote, on divise la largeur par 2)
	npc_sprite = Sprite2D.new()
	var npc_tex: Texture2D = npc_textures[randi() % npc_textures.size()]
	npc_sprite.texture = npc_tex
	npc_frame_w = npc_tex.get_width() / 2
	npc_frame_h = npc_tex.get_height()
	npc_sprite.region_enabled = true
	npc_sprite.region_rect = Rect2(0, 0, npc_frame_w, npc_frame_h)
	npc_sprite.position = npc_pos
	npc_sprite.z_index = 13
	var npc_scale := 80.0 / float(npc_frame_h)
	npc_sprite.scale = Vector2(npc_scale, npc_scale)
	add_child(npc_sprite)

	# Area2D pour detecter l'arrivee de la voiture (sur la zone route)
	objective_area = Area2D.new()
	objective_area.collision_layer = 4
	objective_area.collision_mask = 2
	objective_area.position = objective_pos
	var obj_shape := CircleShape2D.new()
	obj_shape.radius = 60.0
	var obj_col := CollisionShape2D.new()
	obj_col.shape = obj_shape
	objective_area.add_child(obj_col)
	add_child(objective_area)
	objective_area.body_entered.connect(_on_objective_reached)


# =============================================================
#  BONUS
# =============================================================
func _spawn_bonus() -> void:
	if bonus_pos == Vector2.ZERO:
		return

	# Charger l'icone bonus
	var bonus_tex_path := "res://maps/first_map/icon_bonus.png"
	if not ResourceLoader.exists(bonus_tex_path):
		push_error("icon_bonus.png introuvable!")
		return

	var bonus_tex: Texture2D = load(bonus_tex_path)

	# Sprite du bonus
	bonus_sprite = Sprite2D.new()
	bonus_sprite.texture = bonus_tex
	bonus_sprite.position = bonus_pos
	bonus_sprite.z_index = 12
	# Adapter la taille (~50px en jeu)
	var max_dim := float(maxi(bonus_tex.get_width(), bonus_tex.get_height()))
	var bonus_scale := 50.0 / max_dim
	bonus_sprite.scale = Vector2(bonus_scale, bonus_scale)
	add_child(bonus_sprite)

	# Petite animation de flottement
	var float_tween := create_tween().set_loops()
	float_tween.tween_property(bonus_sprite, "position:y", bonus_pos.y - 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(bonus_sprite, "position:y", bonus_pos.y + 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)

	# Area2D pour detecter quand la voiture passe dessus
	bonus_area = Area2D.new()
	bonus_area.collision_layer = 4
	bonus_area.collision_mask = 2
	bonus_area.position = bonus_pos
	var bonus_shape := CircleShape2D.new()
	bonus_shape.radius = 40.0
	var bonus_col := CollisionShape2D.new()
	bonus_col.shape = bonus_shape
	bonus_area.add_child(bonus_col)
	add_child(bonus_area)
	bonus_area.body_entered.connect(_on_bonus_collected)


func _on_bonus_collected(body: Node2D) -> void:
	if body != car or bonus_collected:
		return
	if phase != Phase.RACING and phase != Phase.DARK_RACING:
		return
	bonus_collected = true

	# Si en mode sombre, augmenter la lumiere
	if phase == Phase.DARK_RACING and car_light:
		var light_tween := create_tween()
		light_tween.tween_property(car_light, "texture_scale", DARK_LIGHT_RADIUS_BONUS, 0.5).set_ease(Tween.EASE_OUT)
		light_tween.tween_property(car_light, "energy", 1.8, 0.5).set_ease(Tween.EASE_OUT)

	# Disparition du bonus avec animation
	if bonus_sprite:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bonus_sprite, "scale", Vector2(2.0, 2.0), 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(bonus_sprite, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(func():
			bonus_sprite.queue_free()
			bonus_sprite = null
		)

	# Desactiver l'area
	if bonus_area:
		bonus_area.set_deferred("monitoring", false)

	print("Bonus collecte!")


func _update_npc_animation(delta: float) -> void:
	if not npc_sprite:
		return
	npc_anim_timer += delta
	if npc_anim_timer >= NPC_ANIM_SPEED:
		npc_anim_timer -= NPC_ANIM_SPEED
		npc_anim_frame = 1 - npc_anim_frame
		npc_sprite.region_rect = Rect2(npc_anim_frame * npc_frame_w, 0, npc_frame_w, npc_frame_h)


# =============================================================
#  CAMERA
# =============================================================
func _setup_camera() -> void:
	camera = $Camera
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2(1.0, 1.0)
	camera.position = car_start_pos


func _update_camera() -> void:
	if phase == Phase.MEMORIZE:
		# Vue d'ensemble de la map uniquement pendant la memorisation
		var vp_size := get_viewport().get_visible_rect().size
		var zoom_x := vp_size.x / float(map_px_w)
		var zoom_y := vp_size.y / float(map_px_h)
		var target_zoom := minf(zoom_x, zoom_y) * 0.92
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), 0.08)
		camera.position = camera.position.lerp(Vector2(map_px_w / 2.0, map_px_h / 2.0), 0.08)
	elif phase == Phase.TRANSITION or phase == Phase.RACE_COUNTDOWN or phase == Phase.DARK_COUNTDOWN:
		# Zoom vers la voiture
		camera.zoom = camera.zoom.lerp(Vector2(1.0, 1.0), 0.06)
		if car:
			camera.position = camera.position.lerp(car.position, 0.06)
	elif phase == Phase.PRE_COUNTDOWN:
		# Rester sur la voiture pendant le pre-countdown
		if car:
			camera.position = car.position
	else:
		if car:
			camera.position = car.position


func _update_decor_reveal() -> void:
	## Met a jour la position du trou transparent dans le decor autour de la voiture.
	if decor_sprite and decor_sprite.material and car:
		decor_sprite.material.set_shader_parameter("car_pos", car.position)


func _create_circle_texture(radius: int, fill_color: Color) -> ImageTexture:
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(radius, radius)
	for x in d:
		for y in d:
			if Vector2(x, y).distance_to(c) <= radius:
				img.set_pixel(x, y, fill_color)
	return ImageTexture.create_from_image(img)


# =============================================================
#  MINIMAP TEXTURES
# =============================================================
func _generate_minimap_textures() -> void:
	var px_per_cell := 6
	var mw := grid_w * px_per_cell
	var mh := grid_h * px_per_cell

	minimap_image = Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	minimap_image.fill(Color(0, 0, 0, 0))

	var road_c := Color(0.35, 0.35, 0.4, 1)
	var sw_c := Color(0.55, 0.52, 0.48, 1)
	var build_c := Color(0.15, 0.15, 0.2, 1)
	var line_c := Color(0.75, 0.65, 0.2, 0.8)   # lignes centrales
	var curb_c := Color(0.62, 0.60, 0.55, 1)     # bordures

	var cell_block := Image.create(px_per_cell, px_per_cell, false, Image.FORMAT_RGBA8)

	for y in grid_h:
		for x in grid_w:
			var c: Color
			match grid[y][x]:
				C_ROAD: c = road_c
				C_SIDEWALK: c = sw_c
				_: c = build_c
			cell_block.fill(c)
			minimap_image.blit_rect(cell_block, Rect2i(0, 0, px_per_cell, px_per_cell), Vector2i(x * px_per_cell, y * px_per_cell))

	# Dessiner les bordures trottoir-route sur la minimap
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_SIDEWALK:
				continue
			var bx := x * px_per_cell
			var by := y * px_per_cell
			# Bord droit (route a droite)
			if x < grid_w - 1 and grid[y][x + 1] == C_ROAD:
				for py in px_per_cell:
					minimap_image.set_pixel(bx + px_per_cell - 1, by + py, curb_c)
			# Bord gauche
			if x > 0 and grid[y][x - 1] == C_ROAD:
				for py in px_per_cell:
					minimap_image.set_pixel(bx, by + py, curb_c)
			# Bord bas
			if y < grid_h - 1 and grid[y + 1][x] == C_ROAD:
				for px in px_per_cell:
					minimap_image.set_pixel(bx + px, by + px_per_cell - 1, curb_c)
			# Bord haut
			if y > 0 and grid[y - 1][x] == C_ROAD:
				for px in px_per_cell:
					minimap_image.set_pixel(bx + px, by, curb_c)

	# Dessiner les lignes centrales sur la minimap
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] != C_ROAD:
				continue
			var is_v := col_types[x] == C_ROAD
			var is_h := row_types[y] == C_ROAD
			if is_v and is_h:
				continue  # intersection
			var bx := x * px_per_cell
			var by := y * px_per_cell
			var mid := px_per_cell / 2
			# Tiret 1 sur 2
			if y % 2 == 0 and is_v and not is_h:
				# Ligne verticale centre
				for py in range(1, px_per_cell - 1):
					minimap_image.set_pixel(bx + mid, by + py, line_c)
			if x % 2 == 0 and is_h and not is_v:
				# Ligne horizontale centre
				for px in range(1, px_per_cell - 1):
					minimap_image.set_pixel(bx + px, by + mid, line_c)

	minimap_texture = ImageTexture.create_from_image(minimap_image)

	# Version grande pour la memorisation (taille adaptee)
	var memo_ppc := memo_cell_size
	var memo_w := grid_w * memo_ppc
	var memo_h := grid_h * memo_ppc
	var memo_img := Image.create(memo_w, memo_h, false, Image.FORMAT_RGBA8)
	var memo_cell := Image.create(memo_ppc, memo_ppc, false, Image.FORMAT_RGBA8)

	for y in grid_h:
		for x in grid_w:
			var c: Color
			match grid[y][x]:
				C_ROAD: c = road_c
				C_SIDEWALK: c = sw_c
				_: c = build_c
			memo_cell.fill(c)
			memo_img.blit_rect(memo_cell, Rect2i(0, 0, memo_ppc, memo_ppc), Vector2i(x * memo_ppc, y * memo_ppc))

	# Bordures et lignes sur la carte memo aussi
	for y in grid_h:
		for x in grid_w:
			if grid[y][x] == C_SIDEWALK:
				var bx := x * memo_ppc
				var by := y * memo_ppc
				if x < grid_w - 1 and grid[y][x + 1] == C_ROAD:
					for py in memo_ppc:
						memo_img.set_pixel(bx + memo_ppc - 1, by + py, curb_c)
				if x > 0 and grid[y][x - 1] == C_ROAD:
					for py in memo_ppc:
						memo_img.set_pixel(bx, by + py, curb_c)
				if y < grid_h - 1 and grid[y + 1][x] == C_ROAD:
					for px in memo_ppc:
						memo_img.set_pixel(bx + px, by + memo_ppc - 1, curb_c)
				if y > 0 and grid[y - 1][x] == C_ROAD:
					for px in memo_ppc:
						memo_img.set_pixel(bx + px, by, curb_c)
			elif grid[y][x] == C_ROAD:
				var is_v := col_types[x] == C_ROAD
				var is_h := row_types[y] == C_ROAD
				if is_v and is_h:
					continue
				var bx := x * memo_ppc
				var by := y * memo_ppc
				var mid := memo_ppc / 2
				if y % 2 == 0 and is_v and not is_h:
					for py in range(2, memo_ppc - 2):
						memo_img.set_pixel(bx + mid, by + py, line_c)
				if x % 2 == 0 and is_h and not is_v:
					for px in range(2, memo_ppc - 2):
						memo_img.set_pixel(bx + px, by + mid, line_c)

	memo_texture = ImageTexture.create_from_image(memo_img)


# =============================================================
#  HUD
# =============================================================
func _create_hud() -> void:
	hud_layer = $HUD

	# Timer en haut a gauche
	timer_label = Label.new()
	timer_label.add_theme_font_override("font", font)
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.position = Vector2(20, 15)
	timer_label.text = "00:00.0"
	timer_label.visible = false
	hud_layer.add_child(timer_label)

	# Penalites sous le timer
	penalty_label = Label.new()
	penalty_label.add_theme_font_override("font", font)
	penalty_label.add_theme_font_size_override("font_size", 18)
	penalty_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.1))
	penalty_label.position = Vector2(20, 55)
	penalty_label.text = "TROTTOIRS: 0  MURS: 0"
	penalty_label.visible = false
	hud_layer.add_child(penalty_label)

	# Countdown au centre
	countdown_label = Label.new()
	countdown_label.add_theme_font_override("font", font)
	countdown_label.add_theme_font_size_override("font_size", 120)
	countdown_label.add_theme_color_override("font_color", Color.WHITE)
	countdown_label.add_theme_color_override("font_shadow_color", Color(0.9, 0.15, 0.05, 0.7))
	countdown_label.add_theme_constant_override("shadow_offset_x", 4)
	countdown_label.add_theme_constant_override("shadow_offset_y", 4)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.anchors_preset = Control.PRESET_FULL_RECT
	countdown_label.text = "5"
	hud_layer.add_child(countdown_label)

	# Minimap ronde (haut droit) — la map collision bouge dedans, centree sur la voiture
	var mm_diameter := MINIMAP_RADIUS * 2
	var mm_size := Vector2(mm_diameter, mm_diameter)
	var vp_size := get_viewport().get_visible_rect().size

	# Container principal (fixe en haut a droite)
	minimap_container = Control.new()
	minimap_container.position = Vector2(vp_size.x - mm_diameter - 15, 12)
	minimap_container.custom_minimum_size = mm_size
	minimap_container.size = mm_size
	minimap_container.visible = false
	minimap_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(minimap_container)

	# Fond circulaire noir
	var mm_bg := _create_circle_texture(MINIMAP_RADIUS, Color(0.05, 0.05, 0.08, 0.9))
	var mm_bg_rect := TextureRect.new()
	mm_bg_rect.texture = mm_bg
	mm_bg_rect.custom_minimum_size = mm_size
	mm_bg_rect.size = mm_size
	mm_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_container.add_child(mm_bg_rect)

	# Zone clippee : la map scrolle dedans, clippe au rectangle du Control
	minimap_clip = Control.new()
	minimap_clip.position = Vector2.ZERO
	minimap_clip.custom_minimum_size = mm_size
	minimap_clip.size = mm_size
	minimap_clip.clip_contents = true
	minimap_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_container.add_child(minimap_clip)

	# Masque circulaire (carre transparent avec cercle opaque blanc)
	var mask_img := Image.create(mm_diameter, mm_diameter, false, Image.FORMAT_RGBA8)
	mask_img.fill(Color(0, 0, 0, 0))
	var center_v := Vector2(MINIMAP_RADIUS, MINIMAP_RADIUS)
	for mx in mm_diameter:
		for my in mm_diameter:
			if Vector2(mx, my).distance_to(center_v) <= MINIMAP_RADIUS:
				mask_img.set_pixel(mx, my, Color(1, 1, 1, 1))
	var mask_tex := ImageTexture.create_from_image(mask_img)
	var mask_rect := TextureRect.new()
	mask_rect.texture = mask_tex
	mask_rect.size = mm_size
	mask_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Image de la map collision
	minimap_tex_rect = TextureRect.new()
	minimap_tex_rect.texture = minimap_texture
	minimap_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	minimap_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Taille : la map entiere en pixels minimap
	var px_per_cell := 6
	minimap_tex_rect.custom_minimum_size = Vector2.ZERO
	minimap_tex_rect.size = Vector2(grid_w * px_per_cell, grid_h * px_per_cell)
	minimap_clip.add_child(minimap_tex_rect)

	# Masque circulaire par dessus (anneau transparent au centre, noir opaque autour)
	var ring_img := Image.create(mm_diameter, mm_diameter, false, Image.FORMAT_RGBA8)
	ring_img.fill(Color(0, 0, 0, 0))
	for rx in mm_diameter:
		for ry in mm_diameter:
			if Vector2(rx, ry).distance_to(center_v) > MINIMAP_RADIUS - 1:
				ring_img.set_pixel(rx, ry, Color(0.05, 0.05, 0.08, 1.0))
	var ring_tex := ImageTexture.create_from_image(ring_img)
	var ring_rect := TextureRect.new()
	ring_rect.texture = ring_tex
	ring_rect.size = mm_size
	ring_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_container.add_child(ring_rect)

	# Bordure circulaire
	var border_img := Image.create(mm_diameter, mm_diameter, false, Image.FORMAT_RGBA8)
	border_img.fill(Color(0, 0, 0, 0))
	for bx in mm_diameter:
		for by in mm_diameter:
			var dist_b := Vector2(bx, by).distance_to(center_v)
			if dist_b >= MINIMAP_RADIUS - 3 and dist_b <= MINIMAP_RADIUS:
				border_img.set_pixel(bx, by, Color(0.9, 0.25, 0.1, 0.7))
	var border_tex := ImageTexture.create_from_image(border_img)
	var border_rect := TextureRect.new()
	border_rect.texture = border_tex
	border_rect.size = mm_size
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_container.add_child(border_rect)

	# Point voiture (toujours au centre du cercle)
	minimap_car_dot = ColorRect.new()
	minimap_car_dot.color = Color(0.2, 0.6, 1.0)
	minimap_car_dot.size = Vector2(6, 6)
	minimap_car_dot.position = Vector2(MINIMAP_RADIUS - 3, MINIMAP_RADIUS - 3)
	minimap_container.add_child(minimap_car_dot)

	# Point objectif/NPC (jaune)
	minimap_npc_dot = ColorRect.new()
	minimap_npc_dot.color = Color(1.0, 0.85, 0.15)
	minimap_npc_dot.size = Vector2(6, 6)
	minimap_npc_dot.visible = false
	minimap_container.add_child(minimap_npc_dot)

	# Point objectif (vert)
	minimap_obj_dot = ColorRect.new()
	minimap_obj_dot.color = Color(0.2, 1.0, 0.3)
	minimap_obj_dot.size = Vector2(8, 8)
	minimap_obj_dot.visible = false
	minimap_container.add_child(minimap_obj_dot)


func _update_hud() -> void:
	if phase == Phase.RACING:
		var mins := int(race_time) / 60
		var secs := int(race_time) % 60
		var tenths := int(fmod(race_time, 1.0) * 10)
		timer_label.text = "%02d:%02d.%d" % [mins, secs, tenths]
		penalty_label.text = "TROTTOIR: %.1fs  MURS: %d" % [penalties_sw, penalties_wall]
	elif phase == Phase.DARK_RACING:
		var time_left := maxf(dark_time_limit - dark_race_time, 0.0)
		var mins := int(time_left) / 60
		var secs := int(time_left) % 60
		var tenths := int(fmod(time_left, 1.0) * 10)
		timer_label.text = "%02d:%02d.%d" % [mins, secs, tenths]
		# Colorer en rouge si peu de temps
		if time_left < 10.0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1))
		elif time_left < 20.0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		else:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		penalty_label.text = "TOUR BONUS  -  TROTTOIR: %.1fs  MURS: %d" % [penalties_sw, penalties_wall]


func _update_minimap_dots() -> void:
	if not minimap_container.visible or not car:
		return

	var px_per_cell := 6
	var map_tex_w := float(grid_w * px_per_cell)
	var map_tex_h := float(grid_h * px_per_cell)

	# Position voiture en coordonnees minimap-texture
	var car_mx := car.position.x / float(map_px_w) * map_tex_w
	var car_my := car.position.y / float(map_px_h) * map_tex_h

	# Centrer la texture sur la voiture : la voiture est toujours au centre du cercle
	minimap_tex_rect.position = Vector2(MINIMAP_RADIUS - car_mx, MINIMAP_RADIUS - car_my)

	# Point voiture reste au centre (deja positionne a la creation)

	# Point NPC visible seulement si proche
	var dist := car.position.distance_to(npc_pos)
	if dist < NPC_VISIBLE_DISTANCE:
		var npc_mx := npc_pos.x / float(map_px_w) * map_tex_w
		var npc_my := npc_pos.y / float(map_px_h) * map_tex_h
		# Position relative au centre du cercle
		var npc_offset := Vector2(npc_mx - car_mx, npc_my - car_my)
		if npc_offset.length() < MINIMAP_RADIUS - 5:
			minimap_npc_dot.visible = true
			minimap_npc_dot.position = Vector2(MINIMAP_RADIUS + npc_offset.x - 3, MINIMAP_RADIUS + npc_offset.y - 3)
		else:
			minimap_npc_dot.visible = false
	else:
		minimap_npc_dot.visible = false

	# Point objectif
	var obj_mx := objective_pos.x / float(map_px_w) * map_tex_w
	var obj_my := objective_pos.y / float(map_px_h) * map_tex_h
	var obj_offset := Vector2(obj_mx - car_mx, obj_my - car_my)
	if obj_offset.length() < MINIMAP_RADIUS - 5:
		minimap_obj_dot.visible = true
		minimap_obj_dot.position = Vector2(MINIMAP_RADIUS + obj_offset.x - 4, MINIMAP_RADIUS + obj_offset.y - 4)
	else:
		minimap_obj_dot.visible = false


# =============================================================
#  OVERLAY (memorisation / transition)
# =============================================================
func _create_overlay() -> void:
	overlay_layer = $Overlay

	gray_overlay = ColorRect.new()
	gray_overlay.color = Color(0, 0, 0, 0.7)
	gray_overlay.anchors_preset = Control.PRESET_FULL_RECT
	gray_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(gray_overlay)

	memo_container = CenterContainer.new()
	memo_container.anchors_preset = Control.PRESET_FULL_RECT
	memo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	memo_container.visible = false
	overlay_layer.add_child(memo_container)

	var memo_vbox := VBoxContainer.new()
	memo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	memo_vbox.add_theme_constant_override("separation", 12)
	memo_container.add_child(memo_vbox)

	# Titre memorisation
	var memo_title := Label.new()
	memo_title.add_theme_font_override("font", font)
	memo_title.add_theme_font_size_override("font_size", 28)
	memo_title.add_theme_color_override("font_color", Color.WHITE)
	memo_title.text = "MEMORISEZ LA CARTE"
	memo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memo_vbox.add_child(memo_title)

	# Timer memorisation
	memo_timer_label = Label.new()
	memo_timer_label.add_theme_font_override("font", font)
	memo_timer_label.add_theme_font_size_override("font_size", 36)
	memo_timer_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.1))
	memo_timer_label.text = "15"
	memo_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memo_vbox.add_child(memo_timer_label)

	# Carte de memorisation
	var memo_map_margin := MarginContainer.new()
	memo_vbox.add_child(memo_map_margin)

	var mcs := float(memo_cell_size)
	var memo_map_panel := Control.new()
	memo_map_panel.custom_minimum_size = Vector2(grid_w * mcs, grid_h * mcs)
	memo_map_margin.add_child(memo_map_panel)

	memo_tex_rect = TextureRect.new()
	memo_tex_rect.texture = memo_texture
	memo_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	memo_tex_rect.size = Vector2(grid_w * mcs, grid_h * mcs)
	memo_map_panel.add_child(memo_tex_rect)

	# Points voiture et PNJ sur la carte memo
	memo_car_dot = ColorRect.new()
	memo_car_dot.color = Color(0.2, 0.6, 1.0)
	memo_car_dot.size = Vector2(14, 14)
	var car_rx := car_start_pos.x / float(map_px_w)
	var car_ry := car_start_pos.y / float(map_px_h)
	memo_car_dot.position = Vector2(car_rx * grid_w * mcs - 7, car_ry * grid_h * mcs - 7)
	memo_map_panel.add_child(memo_car_dot)

	# === NPC : TRES voyant, impossible a rater ===
	var npc_rx := objective_pos.x / float(map_px_w)
	var npc_ry := objective_pos.y / float(map_px_h)
	var npc_dot_center := Vector2(npc_rx * grid_w * mcs, npc_ry * grid_h * mcs)

	# Halo ENORME pulsant (80px, jaune/orange radial)
	var halo_size := 80
	var halo_img := Image.create(halo_size, halo_size, false, Image.FORMAT_RGBA8)
	var halo_center := float(halo_size) / 2.0
	for hx in halo_size:
		for hy in halo_size:
			var dist := Vector2(hx - halo_center, hy - halo_center).length()
			if dist < halo_center:
				var t := 1.0 - dist / halo_center
				var alpha := t * t * 0.8
				halo_img.set_pixel(hx, hy, Color(1.0, 0.6, 0.0, alpha))
	var halo_spr := Sprite2D.new()
	halo_spr.texture = ImageTexture.create_from_image(halo_img)
	halo_spr.position = npc_dot_center
	memo_map_panel.add_child(halo_spr)

	# Deuxieme halo encore plus grand, plus transparent
	var halo2_size := 120
	var halo2_img := Image.create(halo2_size, halo2_size, false, Image.FORMAT_RGBA8)
	var halo2_center := float(halo2_size) / 2.0
	for hx in halo2_size:
		for hy in halo2_size:
			var dist := Vector2(hx - halo2_center, hy - halo2_center).length()
			if dist < halo2_center:
				var t := 1.0 - dist / halo2_center
				var alpha := t * t * 0.35
				halo2_img.set_pixel(hx, hy, Color(1.0, 0.3, 0.0, alpha))
	var halo2_spr := Sprite2D.new()
	halo2_spr.texture = ImageTexture.create_from_image(halo2_img)
	halo2_spr.position = npc_dot_center
	memo_map_panel.add_child(halo2_spr)

	# Pulsation des deux halos (decales pour un effet vivant)
	var ht1 := create_tween().set_loops()
	ht1.tween_property(halo_spr, "scale", Vector2(2.0, 2.0), 0.5).set_ease(Tween.EASE_IN_OUT)
	ht1.tween_property(halo_spr, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT)
	var ht2 := create_tween().set_loops()
	ht2.tween_property(halo2_spr, "scale", Vector2(1.6, 1.6), 0.7).set_ease(Tween.EASE_IN_OUT)
	ht2.tween_property(halo2_spr, "scale", Vector2(0.8, 0.8), 0.7).set_ease(Tween.EASE_IN_OUT)

	# Fleche "V" pointant vers le bas au-dessus du point
	var arrow := Label.new()
	arrow.add_theme_font_override("font", font)
	arrow.add_theme_font_size_override("font_size", 32)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	arrow.text = "▼"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.position = Vector2(npc_dot_center.x - 14, npc_dot_center.y - 50)
	memo_map_panel.add_child(arrow)
	# Animation de rebond vertical
	var arrow_tween := create_tween().set_loops()
	arrow_tween.tween_property(arrow, "position:y", npc_dot_center.y - 38, 0.35).set_ease(Tween.EASE_IN_OUT)
	arrow_tween.tween_property(arrow, "position:y", npc_dot_center.y - 50, 0.35).set_ease(Tween.EASE_IN_OUT)

	# Point central NPC : gros carre rouge vif
	memo_npc_dot = ColorRect.new()
	memo_npc_dot.color = Color(1.0, 0.0, 0.0)
	memo_npc_dot.size = Vector2(26, 26)
	memo_npc_dot.position = Vector2(npc_dot_center.x - 13, npc_dot_center.y - 13)
	memo_map_panel.add_child(memo_npc_dot)

	# Label "OBJECTIF" juste en dessous
	var obj_label := Label.new()
	obj_label.add_theme_font_override("font", font)
	obj_label.add_theme_font_size_override("font_size", 14)
	obj_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	obj_label.text = "OBJECTIF"
	obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_label.position = Vector2(npc_dot_center.x - 35, npc_dot_center.y + 18)
	memo_map_panel.add_child(obj_label)

	# Legende
	var legend := Label.new()
	legend.add_theme_font_override("font", font)
	legend.add_theme_font_size_override("font_size", 16)
	legend.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	legend.text = "BLEU = VOUS    JAUNE = OBJECTIF"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memo_vbox.add_child(legend)


# =============================================================
#  END SCREEN
# =============================================================
func _create_end_screen() -> void:
	end_screen = Control.new()
	end_screen.anchors_preset = Control.PRESET_FULL_RECT
	end_screen.visible = false
	end_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(end_screen)

	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.03, 0.03, 0.06, 0.88)
	end_overlay.anchors_preset = Control.PRESET_FULL_RECT
	end_screen.add_child(end_overlay)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	end_screen.add_child(center)

	# Panel avec fond et bordure
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	panel_style.border_color = Color(0.9, 0.25, 0.1, 0.8)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 50
	panel_style.content_margin_right = 50
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	end_vbox = VBoxContainer.new()
	end_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	end_vbox.add_theme_constant_override("separation", 14)
	panel.add_child(end_vbox)


# =============================================================
#  LUMIERE VOITURE (tour sombre)
# =============================================================
func _setup_car_light() -> void:
	if car_light != null:
		return
	# Creer une texture de lumiere radiale (cercle blanc qui s'estompe)
	var light_size := 512
	var light_img := Image.create(light_size, light_size, false, Image.FORMAT_RGBA8)
	var center_f := float(light_size) / 2.0
	for lx in light_size:
		for ly in light_size:
			var dist := Vector2(lx - center_f, ly - center_f).length()
			var ratio := dist / center_f
			if ratio < 1.0:
				# Plus lumineux au centre, s'estompe vers les bords
				var alpha := (1.0 - ratio * ratio) * 1.0
				light_img.set_pixel(lx, ly, Color(1.0, 1.0, 1.0, alpha))
			else:
				light_img.set_pixel(lx, ly, Color(0, 0, 0, 0))

	var light_tex := ImageTexture.create_from_image(light_img)

	car_light = PointLight2D.new()
	car_light.texture = light_tex
	car_light.texture_scale = DARK_LIGHT_RADIUS
	car_light.energy = 1.5
	car_light.blend_mode = PointLight2D.BLEND_MODE_ADD
	car_light.shadow_enabled = false
	car_light.range_layer_min = -10
	car_light.range_layer_max = 20
	car.add_child(car_light)


func _remove_car_light() -> void:
	if car_light != null:
		car_light.queue_free()
		car_light = null
	# Remettre la lumiere normale
	if canvas_modulate:
		canvas_modulate.color = Color.WHITE


func _show_end_screen() -> void:
	# Calculer le score
	# Temps final = temps reel + penalite trottoir (en secondes) + murs * 10s
	var wall_time := float(penalties_wall * WALL_TIME_PENALTY)
	var total_penalties := penalties_sw + wall_time
	var final_time := race_time + total_penalties
	var base_score := maxi(0, SCORE_MAX - int(final_time) * SCORE_TIME_MULT)

	# Si le tour bonus a ete reussi, doubler le score
	var final_score := base_score
	if dark_round_success:
		final_score = base_score * 2

	# Verifier si nouveau record
	var is_record := _check_and_save_score(final_score)

	# Remplir le end screen
	for child in end_vbox.get_children():
		child.queue_free()

	_add_end_label("LIVRAISON TERMINEE", 42, Color.WHITE)

	if is_record:
		_add_end_label("NOUVEAU RECORD !", 28, Color(1.0, 0.85, 0.15))

	_add_end_label("", 10, Color.TRANSPARENT)  # spacer

	# Temps reel
	var mins := int(race_time) / 60
	var secs := int(race_time) % 60
	_add_end_label("TEMPS REEL: %02d:%02d" % [mins, secs], 22, Color(0.8, 0.8, 0.85))
	_add_end_label("", 6, Color.TRANSPARENT)

	# Penalites
	_add_end_label("TROTTOIR: +%.1fs" % penalties_sw, 18, Color(0.9, 0.5, 0.3))
	_add_end_label("MURS (%d x %ds): +%ds" % [penalties_wall, WALL_TIME_PENALTY, int(wall_time)], 18, Color(0.9, 0.3, 0.2))
	_add_end_label("PENALITES TOTALES: +%ds" % int(total_penalties), 18, Color(0.9, 0.4, 0.25))
	_add_end_label("", 6, Color.TRANSPARENT)

	# Temps final
	var f_mins := int(final_time) / 60
	var f_secs := int(final_time) % 60
	_add_end_label("TEMPS FINAL: %02d:%02d" % [f_mins, f_secs], 22, Color(1.0, 0.6, 0.2))
	_add_end_label("%d - (%d x %d) = %d" % [SCORE_MAX, int(final_time), SCORE_TIME_MULT, base_score], 16, Color(0.6, 0.6, 0.65))

	_add_end_label("", 6, Color.TRANSPARENT)

	# Affichage du resultat du tour bonus
	if dark_round_success:
		_add_end_label("TOUR BONUS REUSSI !", 26, Color(0.2, 1.0, 0.3))
		_add_end_label("SCORE x2 !", 22, Color(1.0, 0.85, 0.15))
		_add_end_label("%d x 2 = %d" % [base_score, final_score], 16, Color(0.6, 0.6, 0.65))
	elif phase == Phase.DARK_FINISHED:
		_add_end_label("TOUR BONUS ECHOUE", 26, Color(0.9, 0.3, 0.2))
		_add_end_label("PAS DE MULTIPLICATEUR", 18, Color(0.6, 0.6, 0.65))

	_add_end_label("", 6, Color.TRANSPARENT)
	_add_end_label("SCORE FINAL: %d PTS" % final_score, 36, Color(0.9, 0.25, 0.1))

	_add_end_label("", 14, Color.TRANSPARENT)

	# Bouton retour
	var btn := Button.new()
	btn.text = "RETOUR AU MENU"
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(280, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	)
	end_vbox.add_child(btn)

	end_screen.visible = true
	end_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(end_screen, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)


func _add_end_label(text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_vbox.add_child(lbl)


func _check_and_save_score(score: int) -> bool:
	var scores: Array[int] = []
	var path := "user://scores.save"

	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				for s in json.data:
					scores.append(int(s))
			file.close()

	var is_record: bool = scores.size() < 3 or score > scores.min()

	scores.append(score)
	scores.sort()
	scores.reverse()
	if scores.size() > 3:
		scores.resize(3)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scores))
		file.close()

	return is_record


# =============================================================
#  MENU PAUSE
# =============================================================
func _create_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(pause_menu)

	pause_overlay = ColorRect.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.02, 0.02, 0.05, 0.8)
	pause_menu.add_child(pause_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	panel_style.border_color = Color(0.9, 0.25, 0.1, 0.8)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 50
	panel_style.content_margin_right = 50
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	# Titre
	var title_lbl := Label.new()
	title_lbl.text = "PAUSE"
	title_lbl.add_theme_font_override("font", font)
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Bouton Reprendre
	var btn_resume := Button.new()
	btn_resume.text = "REPRENDRE"
	btn_resume.add_theme_font_override("font", font)
	btn_resume.add_theme_font_size_override("font_size", 22)
	btn_resume.custom_minimum_size = Vector2(250, 50)
	btn_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_resume.pressed.connect(_toggle_pause)
	vbox.add_child(btn_resume)

	# Bouton Quitter
	var btn_quit := Button.new()
	btn_quit.text = "QUITTER LA PARTIE"
	btn_quit.add_theme_font_override("font", font)
	btn_quit.add_theme_font_size_override("font_size", 22)
	btn_quit.custom_minimum_size = Vector2(250, 50)
	btn_quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_quit.pressed.connect(func():
		_toggle_pause()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	)
	vbox.add_child(btn_quit)


func _toggle_pause() -> void:
	game_paused = not game_paused
	pause_menu.visible = game_paused
	if car:
		car.active = not game_paused and phase == Phase.RACING


# =============================================================
#  GESTION DES PHASES
# =============================================================
func _start_phase(p: int) -> void:
	phase = p
	phase_timer = 0.0

	match p:
		Phase.PRE_COUNTDOWN:
			# Vue carte en gros plan (camera gere le zoom)
			gray_overlay.visible = true
			gray_overlay.color = Color(0, 0, 0, 0.35)
			memo_container.visible = false
			countdown_label.visible = true
			countdown_label.add_theme_font_size_override("font_size", 72)
			countdown_label.text = "PREPAREZ-VOUS"
			timer_label.visible = false
			penalty_label.visible = false
			minimap_container.visible = false
			car.active = false
			if menu_music and menu_music.stream:
				menu_music.play()

		Phase.MEMORIZE:
			countdown_label.visible = true
			countdown_label.add_theme_font_size_override("font_size", 52)
			countdown_label.text = "MEMORISEZ LA CARTE"
			gray_overlay.color = Color(0, 0, 0, 0.25)
			memo_container.visible = false

		Phase.TRANSITION:
			memo_container.visible = false
			countdown_label.visible = false

		Phase.RACE_COUNTDOWN:
			gray_overlay.visible = false
			countdown_label.visible = true
			countdown_label.add_theme_font_size_override("font_size", 120)
			countdown_label.text = "3"
			countdown_num = 3
			if countdown_sound:
				countdown_sound.play()
			# Fade out musique menu
			if menu_music and menu_music.playing:
				var mt := create_tween()
				mt.tween_property(menu_music, "volume_db", -40.0, 0.5)
				mt.tween_callback(func(): menu_music.stop(); menu_music.volume_db = -5.0)

		Phase.RACING:
			countdown_label.visible = false
			timer_label.visible = true
			penalty_label.visible = true
			minimap_container.visible = true
			car.active = true
			race_time = 0.0
			# Musique de course aleatoire
			if race_music:
				var tracks := [
					load("res://sounds/Initial-D-Running-in-The-90s.mp3"),
					load("res://sounds/Initial-D-Deja-Vu.mp3"),
				]
				var chosen = tracks[randi() % 2]
				if chosen:
					chosen.loop = true
					race_music.stream = chosen
					race_music.play()

		Phase.FINISHED:
			car.active = false
			if race_music and race_music.playing:
				race_music.stop()
			_show_end_screen()

		Phase.RETURN_TRANSITION:
			# Retour au point de depart + mise en place du noir
			car.active = false
			timer_label.visible = false
			penalty_label.visible = false
			minimap_container.visible = false
			countdown_label.visible = true
			countdown_label.add_theme_font_size_override("font_size", 52)
			countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
			countdown_label.text = "TOUR BONUS !"
			# Teleporter la voiture au depart
			car.reset_to(car_start_pos, custom_car_heading)
			last_safe_car_pos = car_start_pos
			# Activer la lumiere sur la voiture
			_setup_car_light()
			# Le noir va s'installer pendant la transition

		Phase.DARK_COUNTDOWN:
			# Affichage du compte a rebours dans le noir
			countdown_label.visible = true
			countdown_label.add_theme_font_size_override("font_size", 120)
			countdown_label.add_theme_color_override("font_color", Color.WHITE)
			var limit_str := "%02d:%02d" % [int(dark_time_limit) / 60, int(dark_time_limit) % 60]
			# Afficher le temps disponible
			countdown_label.text = "3"
			# HUD temps limite
			timer_label.visible = true
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
			timer_label.text = "LIMITE: " + limit_str
			penalty_label.visible = true
			penalty_label.text = "TEMPS BONUS: premier tour + %ds" % int(DARK_BONUS_TIME)
			if countdown_sound:
				countdown_sound.play()

		Phase.DARK_RACING:
			countdown_label.visible = false
			timer_label.visible = true
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
			penalty_label.visible = true
			minimap_container.visible = true  # minimap aussi dans le tour bonus
			car.active = true
			dark_race_time = 0.0
			# Si le bonus a deja ete collecte au 1er tour, appliquer directement le rayon bonus
			if bonus_collected and car_light:
				car_light.texture_scale = DARK_LIGHT_RADIUS_BONUS
				car_light.energy = 1.8

		Phase.DARK_FINISHED:
			car.active = false
			_remove_car_light()
			if race_music and race_music.playing:
				race_music.stop()
			_show_end_screen()


func _update_phase(delta: float) -> void:
	phase_timer += delta

	match phase:
		Phase.PRE_COUNTDOWN:
			var remaining := ceili(PRE_COUNTDOWN_TIME - phase_timer)
			remaining = clampi(remaining, 1, int(PRE_COUNTDOWN_TIME))
			countdown_label.text = "PREPAREZ-VOUS  %d" % remaining
			if phase_timer >= PRE_COUNTDOWN_TIME:
				_start_phase(Phase.MEMORIZE)

		Phase.MEMORIZE:
			var remaining := ceili(MEMORIZE_TIME - phase_timer)
			remaining = maxi(remaining, 0)
			countdown_label.text = "MEMORISEZ LA CARTE  %d" % remaining
			if phase_timer >= MEMORIZE_TIME:
				_start_phase(Phase.TRANSITION)

		Phase.TRANSITION:
			# Fade out de l'overlay gris
			var t := phase_timer / TRANSITION_TIME
			t = clampf(t, 0.0, 1.0)
			gray_overlay.color = Color(0, 0, 0, 0.35 * (1.0 - t))
			if phase_timer >= TRANSITION_TIME:
				gray_overlay.visible = false
				_start_phase(Phase.RACE_COUNTDOWN)

		Phase.RACE_COUNTDOWN:
			var elapsed := phase_timer
			# RACE_COUNTDOWN_TIME = N seconds: (N-1) seconds pour le decompte, 0.8s pour GO!
			var count_seconds := int(RACE_COUNTDOWN_TIME) - 1  # ex: 4 => 3 secondes de decompte
			var go_start := float(count_seconds)
			var go_end := go_start + 0.8
			if elapsed < go_start:
				var remaining := count_seconds - int(elapsed)
				countdown_label.text = str(remaining)
			elif elapsed < go_end:
				countdown_label.text = "GO!"
				countdown_label.add_theme_font_size_override("font_size", 160)
				countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			else:
				countdown_label.add_theme_color_override("font_color", Color.WHITE)
				_start_phase(Phase.RACING)

		Phase.RACING:
			race_time += delta

		Phase.RETURN_TRANSITION:
			# 2 secondes d'affichage "TOUR BONUS !" puis le noir s'installe
			if phase_timer < 2.0:
				# Transition vers le noir progressif via CanvasModulate
				var t := phase_timer / 2.0
				var dark := lerpf(1.0, 0.03, t)
				canvas_modulate.color = Color(dark, dark, dark)
			else:
				canvas_modulate.color = Color(0.03, 0.03, 0.03)
				_start_phase(Phase.DARK_COUNTDOWN)

		Phase.DARK_COUNTDOWN:
			var elapsed := phase_timer
			# Meme systeme que RACE_COUNTDOWN mais avec RACE_COUNTDOWN_TIME
			var count_seconds := int(RACE_COUNTDOWN_TIME) - 1
			var go_start := float(count_seconds)
			var go_end := go_start + 0.8
			if elapsed < go_start:
				var remaining := count_seconds - int(elapsed)
				countdown_label.text = str(remaining)
			elif elapsed < go_end:
				countdown_label.text = "GO!"
				countdown_label.add_theme_font_size_override("font_size", 160)
				countdown_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			else:
				countdown_label.add_theme_color_override("font_color", Color.WHITE)
				_start_phase(Phase.DARK_RACING)

		Phase.DARK_RACING:
			dark_race_time += delta
			var time_left := dark_time_limit - dark_race_time
			if time_left <= 0.0:
				# Temps ecoule => echec du tour bonus
				dark_round_success = false
				_start_phase(Phase.DARK_FINISHED)


# =============================================================
#  PENALITES
# =============================================================
func _check_sidewalk_penalty() -> void:
	if phase != Phase.RACING or not car:
		return

	var cell_x := clampi(int(car.position.x / CELL), 0, grid_w - 1)
	var cell_y := clampi(int(car.position.y / CELL), 0, grid_h - 1)
	var on_sidewalk: bool = grid[cell_y][cell_x] == C_SIDEWALK

	if on_sidewalk:
		penalties_sw += get_process_delta_time()
	was_on_sidewalk = on_sidewalk


func _on_car_hit_wall() -> void:
	if phase != Phase.RACING:
		return
	if wall_cooldown > 0.0:
		return
	penalties_wall += 1
	wall_cooldown = 0.4

	# Screen shake
	var shake_tween := create_tween()
	var original := camera.offset
	shake_tween.tween_property(camera, "offset", original + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
	shake_tween.tween_property(camera, "offset", original + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)
	shake_tween.tween_property(camera, "offset", original, 0.1)


func _update_wall_cooldown(delta: float) -> void:
	if wall_cooldown > 0.0:
		wall_cooldown -= delta


func _keep_car_on_road() -> void:
	## Empeche la voiture de rester sur une cellule batiment (sinon elle disparait sous le decor).
	if not car or (phase != Phase.RACING and phase != Phase.DARK_RACING):
		return

	var cell_x := clampi(int(car.position.x / CELL), 0, grid_w - 1)
	var cell_y := clampi(int(car.position.y / CELL), 0, grid_h - 1)

	if grid[cell_y][cell_x] != C_BUILDING:
		# Position valide => sauvegarder
		last_safe_car_pos = car.position
	else:
		# Sur un batiment => ramener a la derniere position safe
		if last_safe_car_pos != Vector2.ZERO:
			car.position = last_safe_car_pos
			car.velocity = Vector2.ZERO


# =============================================================
#  OBJECTIF ATTEINT
# =============================================================
func _on_objective_reached(body: Node2D) -> void:
	if body == car and phase == Phase.RACING:
		# Premier tour termine => passer au tour sombre
		first_round_time = race_time
		dark_time_limit = first_round_time + DARK_BONUS_TIME
		_start_phase(Phase.RETURN_TRANSITION)
	elif body == car and phase == Phase.DARK_RACING:
		# Tour sombre reussi !
		dark_round_success = true
		_start_phase(Phase.DARK_FINISHED)
