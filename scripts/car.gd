extends CharacterBody2D

signal hit_wall

# -- Physique --
const MAX_SPEED := 450.0
const ACCELERATION := 250.0
const BRAKE_FORCE := 350.0
const DRAG := 0.985
const STEER_SPEED := 2.8
const GRIP_NORMAL := 0.12
const GRIP_DRIFT := 0.92
const DRIFT_STEER_BOOST := 1.8
const DRIFT_SPEED_KEEP := 0.97
const MIN_SPEED_TO_STEER := 25.0

# -- Spritesheet --
const FRAME_SIZE := 100
const FRAMES_COUNT := 48
const COLS := 7
const FRAME_OFFSET := 0

# -- State --
var heading: float = -PI / 2.0
var visual_heading: float = -PI / 2.0
var speed: float = 0.0
var active: bool = false
var drifting: bool = false
var start_pos: Vector2 = Vector2.ZERO
var start_heading: float = -PI / 2.0
var prev_frame_idx: int = -1
var last_valid_pos: Vector2 = Vector2.ZERO
var map_bounds: Rect2 = Rect2()
var drift_tween: Tween = null
var honk_player: AudioStreamPlayer = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var drift_particles: CPUParticles2D = $DriftParticles


func _ready() -> void:
	sprite.region_rect = Rect2(0, 0, FRAME_SIZE, FRAME_SIZE)
	_update_frame()
	honk_player = AudioStreamPlayer.new()
	var honk_stream = load("res://sounds/klaxon.mp3")
	if honk_stream:
		honk_player.stream = honk_stream
		add_child(honk_player)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("car_honk") and honk_player:
		if honk_player.playing:
			honk_player.stop()
		honk_player.play()

	if not active:
		velocity = Vector2.ZERO
		return

	if Input.is_action_just_pressed("car_reset"):
		reset_to(start_pos, start_heading)
		return

	# -- Entrees --
	var accel_input := 0.0
	var steer_input := 0.0

	if Input.is_action_pressed("car_forward"):
		accel_input += 1.0
	if Input.is_action_pressed("car_backward"):
		accel_input -= 1.0
	if Input.is_action_pressed("car_right"):
		steer_input += 1.0
	if Input.is_action_pressed("car_left"):
		steer_input -= 1.0

	drifting = Input.is_action_pressed("car_drift")

	# -- Acceleration / freinage --
	if accel_input > 0.0:
		speed += ACCELERATION * delta
	elif accel_input < 0.0:
		speed -= BRAKE_FORCE * delta
	else:
		speed *= DRAG

	speed = clampf(speed, -MAX_SPEED * 0.35, MAX_SPEED)

	if absf(speed) < 3.0:
		speed = 0.0

	# -- Direction --
	if absf(speed) > MIN_SPEED_TO_STEER:
		var steer_factor := 1.0 - (absf(speed) / MAX_SPEED) * 0.45
		var steer_mult := DRIFT_STEER_BOOST if drifting else 1.0
		heading += steer_input * STEER_SPEED * steer_factor * steer_mult * signf(speed) * delta

	# -- Velocity avec grip --
	var heading_dir := Vector2(cos(heading), sin(heading))
	var target_vel := heading_dir * speed
	var grip := GRIP_DRIFT if drifting else GRIP_NORMAL
	velocity = velocity.lerp(target_vel, 1.0 - grip)

	# -- Drift: conserver la vitesse et reduire le freinage naturel --
	if drifting and absf(speed) > MIN_SPEED_TO_STEER:
		speed *= DRIFT_SPEED_KEEP

	var pos_before := position

	move_and_slide()

	# -- Detection collision murs --
	if get_slide_collision_count() > 0:
		hit_wall.emit()
		speed *= 0.3
		if velocity.length() > MIN_SPEED_TO_STEER:
			heading = velocity.angle()
			visual_heading = heading

	# -- Securite: verifier que la voiture n'a pas disparu --
	if not position.is_finite():
		position = last_valid_pos if last_valid_pos != Vector2.ZERO else start_pos
		speed = 0.0
		velocity = Vector2.ZERO
	elif map_bounds.size != Vector2.ZERO:
		# Clamp dans les limites de la map
		var margin := 20.0
		position.x = clampf(position.x, map_bounds.position.x + margin, map_bounds.end.x - margin)
		position.y = clampf(position.y, map_bounds.position.y + margin, map_bounds.end.y - margin)

	if position.is_finite():
		last_valid_pos = position

	_update_frame()
	_update_drift_visuals(delta)


func _update_drift_visuals(_delta: float) -> void:
	var is_drifting_fast := drifting and absf(speed) > MIN_SPEED_TO_STEER * 2.0

	drift_particles.emitting = is_drifting_fast
	if is_drifting_fast:
		drift_particles.direction = Vector2(cos(heading + PI), sin(heading + PI))

	# Skew du sprite
	var target_skew := 0.0
	if is_drifting_fast:
		var steer_input := 0.0
		if Input.is_action_pressed("car_right"):
			steer_input += 1.0
		if Input.is_action_pressed("car_left"):
			steer_input -= 1.0
		target_skew = steer_input * 0.25
	sprite.skew = lerpf(sprite.skew, target_skew, 0.15)

	# Scale pulse
	if is_drifting_fast and sprite.scale.x <= 1.301:
		if drift_tween:
			drift_tween.kill()
		drift_tween = create_tween()
		drift_tween.tween_property(sprite, "scale", Vector2(1.4, 1.2), 0.1).set_ease(Tween.EASE_OUT)
		drift_tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_IN_OUT)
	elif not is_drifting_fast and (sprite.scale.x > 1.301 or sprite.scale.y < 1.299):
		if drift_tween:
			drift_tween.kill()
		drift_tween = create_tween()
		drift_tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)


func _update_frame() -> void:
	var diff := fposmod(heading - visual_heading + PI, TAU) - PI
	var lerp_speed := 0.35 if drifting else 0.5
	if absf(speed) < MIN_SPEED_TO_STEER:
		lerp_speed = 0.8
	visual_heading += diff * lerp_speed
	visual_heading = fposmod(visual_heading, TAU)

	var angle := visual_heading
	var idx := (int(round(angle / TAU * float(FRAMES_COUNT))) + FRAME_OFFSET) % FRAMES_COUNT

	if prev_frame_idx >= 0:
		var frame_diff := absi(idx - prev_frame_idx)
		@warning_ignore("integer_division")
		if frame_diff > FRAMES_COUNT / 2:
			frame_diff = FRAMES_COUNT - frame_diff
		if frame_diff <= 0:
			return

	prev_frame_idx = idx
	var col := idx % COLS
	@warning_ignore("integer_division")
	var row := idx / COLS
	sprite.region_rect = Rect2(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)


func reset_to(pos: Vector2, dir: float) -> void:
	position = pos
	heading = dir
	visual_heading = dir
	speed = 0.0
	velocity = Vector2.ZERO
	start_pos = pos
	start_heading = dir
	last_valid_pos = pos
	prev_frame_idx = -1
	drifting = false
	sprite.skew = 0.0
	sprite.scale = Vector2(1.3, 1.3)
	drift_particles.emitting = false
	_update_frame()
