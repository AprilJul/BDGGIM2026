extends CharacterBody2D

# ============================================================
# KONSTANTA GERAK
# ============================================================
const SPEED = 180.0
const ACCELERATION = 600.0
const FRICTION = 800.0

# ============================================================
# REFERENSI NODE
# ============================================================
@onready var sprite = $Sprite2D
@onready var interaction_detector = $InteractionDetector

# Panel yang sedang dalam jangkauan (kalau ada)
var nearby_panel: Node = null

# ============================================================
# GERAK UTAMA
# ============================================================
func _physics_process(delta: float) -> void:
	# Kalau lagi di panel mode, player tidak bisa gerak
	if GameManager.is_in_panel_mode:
		velocity = Vector2.ZERO
		return

	_handle_movement(delta)
	_handle_interaction()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	# Baca input WASD / arrow keys
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if direction != Vector2.ZERO:
		# Percepat menuju kecepatan maksimal
		velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)

		# Flip sprite sesuai arah horizontal
		if direction.x != 0:
			if direction.x < 0:
				sprite.scale.x = -1
			else:
				sprite.scale.x = 1
	else:
		# Perlambat saat tidak ada input (friction)
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _handle_interaction() -> void:
	# Tekan E saat dekat panel → masuk panel mode
	if Input.is_action_just_pressed("ui_accept") and nearby_panel != null:
		nearby_panel.open_panel()

# ============================================================
# DETEKSI PANEL DI SEKITAR
# ============================================================
func _ready() -> void:
	interaction_detector.area_entered.connect(_on_near_panel)
	interaction_detector.area_exited.connect(_on_left_panel)

func _on_near_panel(area: Area2D) -> void:
	print("Area detected: ", area.name, " groups: ", area.get_groups())
	if area.is_in_group("interaction_panel"):
		nearby_panel = area.get_parent()
		print("nearby_panel set to: ", nearby_panel.name)

func _on_left_panel(area: Area2D) -> void:
	if area.get_parent() == nearby_panel:
		nearby_panel = null
