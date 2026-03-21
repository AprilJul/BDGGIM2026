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

# ============================================================
# REFERENSI NODE
# ============================================================
@onready var sprite = $AnimatedSprite2D
@onready var interaction_detector = $InteractionDetector
@onready var world = get_parent()    # [cite: 5]
@onready var balloon = $"../ExampleBalloon" # sesuaikan path

# Panel yang sedang dalam jangkauan (kalau ada)
var nearby_panel: Node = null
var current_expression: String = "default"


# ============================================================
# GERAK UTAMA
# ============================================================
func _physics_process(delta: float) -> void:
	# Combined freeze check:
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
		last_direction = direction # Save the direction for idle reference
		
		velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
		
		if waiting_for_tutorial_move:
			waiting_for_tutorial_move = false
			trigger_delayed_dialogue()
	else:
		player_state = "idle"
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	play_animation(direction)

func _handle_interaction() -> void:
	# Interaction logic from original Player.gd [cite: 8]
	if Input.is_action_just_pressed("ui_accept") and nearby_panel != null:
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
	
	# Determine which direction to use (current move dir, or last dir if idle)
	var check_dir = dir if player_state == "walking" else last_direction
	
	if player_state == "walking":
		if abs(check_dir.x) > abs(check_dir.y):
			anim_sprite.play("walk_right" if check_dir.x > 0 else "walk_left")
		else:
			anim_sprite.play("walk_front" if check_dir.y > 0 else "walk_back")
	else:
		# Idle logic using the specific names from your .tscn file
		if abs(check_dir.x) > abs(check_dir.y):
			anim_sprite.play("idle_right" if check_dir.x > 0 else "idle_left")
		else:
			anim_sprite.play("idle_front" if check_dir.y > 0 else "idle_back")

# ============================================================
# DETEKSI PANEL (Original Player.gd logic)
# ============================================================
func _ready() -> void:
	interaction_detector.area_entered.connect(_on_near_panel)
	interaction_detector.area_exited.connect(_on_left_panel)

func _on_near_panel(area: Area2D) -> void:
	print("Area entered: ", area.name, " | groups: ", area.get_groups())
	if area.is_in_group("interaction_panel"):
		nearby_panel = area.get_parent()
		print("Panel ditemukan: ", nearby_panel.name)

func _on_left_panel(area: Area2D) -> void:
	print("Area exited: ", area.name)
	if area.get_parent() == nearby_panel:
		nearby_panel = null


func _on_area_2d_area_entered(area: Area2D) -> void:
	if world.has_method("start_my_dialogue"):
		world.start_my_dialogue("exhausted")
