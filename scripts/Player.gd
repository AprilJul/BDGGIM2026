extends CharacterBody2D

# ============================================================
# KONSTANTA GERAK (From Player.gd)
# ============================================================
const SPEED = 180.0
const ACCELERATION = 600.0
const FRICTION = 800.0

# ============================================================
# STATE VARIABLES (Merged from player.gd)
# ============================================================
var player_state = "idle"             # [cite: 5]
var can_move = true                  # [cite: 5]
var waiting_for_tutorial_move = false # [cite: 5]
var last_direction = Vector2.DOWN
var current_location = "lobby_control" # Default location

# ============================================================
# REFERENSI NODE
# ============================================================
@onready var sprite = $AnimatedSprite2D
@onready var interaction_detector = $InteractionDetector
@onready var world = get_parent()    # [cite: 5]
@onready var walk_sound = $WalkSound

# Panel yang sedang dalam jangkauan (kalau ada)
var nearby_panel: Node = null


# ============================================================
# GERAK UTAMA
# ============================================================
func _physics_process(delta: float) -> void:
	if GameManager.game_over:
		velocity = Vector2.ZERO
		return
	
	if GameManager.sysadmin_active:
		velocity = Vector2.ZERO
		_handle_movement(delta)
		move_and_slide()
		return
	# Checks GameManager (Panel Mode) and the dialogue 'can_move' state [cite: 5, 7]
	if GameManager.is_in_panel_mode or not can_move:
		velocity = Vector2.ZERO
		player_state = "idle"         # [cite: 5]
		play_animation(Vector2.ZERO)  # [cite: 5]
		return

	_handle_movement(delta)
	_handle_interaction()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		player_state = "walking"
		last_direction = direction
		
		velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
		
		# START SOUND: Play only if it isn't already playing 
		if not walk_sound.playing:
			# Add a slight random pitch variation (between 0.9 and 1.1)
			walk_sound.pitch_scale = randf_range(0.9, 1.1) 
			walk_sound.play()
		
		if waiting_for_tutorial_move:
			waiting_for_tutorial_move = false
			trigger_delayed_dialogue()
	else:
		player_state = "idle"
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		
		# STOP SOUND: Stop playing when the player is idle 
		walk_sound.stop()
	
	play_animation(direction)

func _handle_interaction() -> void:
	if Input.is_action_just_pressed("ui_accept") and nearby_panel != null:
		# ReactorPanel SELALU bisa dibuka — berisi tombol start
		# Yang dikunci hanya panel operasional
		var panel_name = nearby_panel.name.to_lower()
		var reactor_only_panels = [
			"laserpanel",           # laser control
			"coolingventpanel",     # coolant + vent
			"emergencypanel"        # ECCS, E-Vent
			# ReactorPanel TIDAK ada di sini
		]
		
		var is_reactor_panel = false
		for p in reactor_only_panels:
			if panel_name.contains(p.to_lower()):
				is_reactor_panel = true
				break
		
		if is_reactor_panel and not GameManager.is_reactor_running():
			print("Reactor harus online dulu!")
			return
		
		nearby_panel.open_panel()

# ============================================================
# LOGIKA DIALOG & TUTORIAL (Merged from player.gd)
# ============================================================
func trigger_delayed_dialogue():
	# Wait for 1.5 seconds before starting the next dialogue [cite: 6]
	await get_tree().create_timer(1.5).timeout
	
	
	if world.has_method("start_my_dialogue"):
		# Pass [self] so the balloon can access 'current_expression'
		world.start_my_dialogue("after_movement") 

func play_animation(dir: Vector2):
	if not has_node("AnimatedSprite2D"):
		return
		
	var anim_sprite = $AnimatedSprite2D
	var check_dir = dir if player_state == "walking" else last_direction
	
	# Determine direction suffix
	var dir_suffix = ""
	if abs(check_dir.x) > abs(check_dir.y):
		dir_suffix = "right" if check_dir.x > 0 else "left"
	else:
		dir_suffix = "front" if check_dir.y > 0 else "back"

	# Construct animation name based on state and location
	var anim_name = ""
	if player_state == "walking":
		# Format: walk1_location_direction (e.g., walk1_cpu_left) [cite: 15]
		anim_name = "walk1_" + current_location + "_" + dir_suffix
	else:
		# Format: idle_location_direction (e.g., idle_lobby_control_front) 
		anim_name = "idle_" + current_location + "_" + dir_suffix

	# Fallback check: If the specific animation doesn't exist, use lobby_control
	if not anim_sprite.sprite_frames.has_animation(anim_name):
		var fallback_state = "walk1_" if player_state == "walking" else "idle_"
		anim_name = fallback_state + "lobby_control_" + dir_suffix
	
	anim_sprite.play(anim_name)

# ============================================================
# DETEKSI PANEL (Original Player.gd logic)
# ============================================================
func _ready() -> void:
	interaction_detector.area_entered.connect(_on_near_panel)
	interaction_detector.area_exited.connect(_on_left_panel)
	GameManager.mcs_warning_shake.connect(_on_mcs_warning)

func _on_near_panel(area: Area2D) -> void:
	print("Area entered: ", area.name, " | groups: ", area.get_groups())
	if area.is_in_group("interaction_panel"):
		nearby_panel = area.get_parent()
		print("Panel ditemukan: ", nearby_panel.name)

func _on_left_panel(area: Area2D) -> void:
	print("Area exited: ", area.name)
	if area.get_parent() == nearby_panel:
		nearby_panel = null

# Just for testing, will be deleted soon
func _on_area_2d_area_entered(area: Area2D) -> void:
	if world.has_method("start_my_dialogue"):
		world.start_my_dialogue("exhausted")


func _on_area_2d_area_hallway_entered(area: Area2D) -> void:
	current_location = "hallway"

func _on_area_2d_area_cpu_entered(area: Area2D) -> void:
	current_location = "cpu"

func _on_area_2d_area_reactor_entered(area: Area2D) -> void:
	current_location = "reactor"

func start_screenshake(duration: float, intensity: float) -> void:
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		return
	var tween = create_tween()
	var elapsed = 0.0
	while elapsed < duration:
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "offset", offset, 0.05)
		elapsed += 0.05
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.1)

func _on_mcs_warning() -> void:
	# Screenshake violent selama 3 detik
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		return
	var tween = create_tween()
	tween.set_loops(60)   # 60 loop × 0.05s = 3 detik
	tween.tween_property(camera, "offset",
		Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.0)
