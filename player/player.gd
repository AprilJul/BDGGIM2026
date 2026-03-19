extends CharacterBody2D

var speed = 100
var player_state
var can_move := true

@export var inv: Inv
@onready var shape_cast = $ShapeCast2D
@onready var map_system = get_node_or_null("/root/MainHouse/MapCanvas/MapSystem")

const INSTRUCTION_POPUP = preload("res://instruction/InstructionPopup.tscn")

# Load resource inventory yang sama dengan yang dipakai UI
@onready var inventory: Inv = preload("res://player/inventory/player_inventory.tres")

func collect(item: InvItem):
	inventory.insert(item) # Memanggil fungsi insert yang kita buat di Step 1
	
func spawn_instruction():
	# 1. Buat instansi dari scene
	var popup = INSTRUCTION_POPUP.instantiate()
	
	# 2. Isi data antrian (queue) teks dan gambar
	# Pastikan path gambar 'res://...' sudah benar sesuai folder kamu
	popup.queue = [
		{
			"text": "Press WASD to move around", 
			"image": preload("res://art/UI/wasd.png")
		}
	]
	
	# 3. Tentukan posisi munculnya (di atas kepala player)
	# Kita gunakan global_position agar posisinya akurat di map
	popup.position = Vector2(0, -30)
	
	# 4. Tambahkan ke scene utama (Parent dari player)
	# Alasan: Agar jika player berbalik (flip), teksnya tidak ikut terbalik
	add_child(popup)
	

func _physics_process(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if not can_move:
		velocity = Vector2.ZERO
		#print("Player can't move now.")
		return
		
	if direction == Vector2.ZERO:
		player_state = "idle"
		velocity = Vector2.ZERO
	else:
		player_state = "walking"
		
		if _can_move_to(direction):
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
	
	move_and_slide()
	play_animation(direction)

	var map = get_tree().get_first_node_in_group("Map")
	
	if map and map.visible:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if GameManager.is_dialog_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

func _can_move_to(dir: Vector2) -> bool:
	shape_cast.target_position = dir * 4
	shape_cast.force_shapecast_update()
	
	if shape_cast.is_colliding():
		return true 
	
	print("No floor detected at: ", global_position + (dir * 4))
	return false

func play_animation(dir):
	if player_state == "idle":
		$AnimatedSprite2D.play("idle")
	elif player_state == "walking":
		if abs(dir.x) > abs(dir.y):
			$AnimatedSprite2D.play("walk_right" if dir.x > 0 else "walk_left")
		else:
			$AnimatedSprite2D.play("walk_front" if dir.y > 0 else "walk_back")

# -------------------------------
# ✨ ADD THESE HELPER FUNCTIONS
# -------------------------------

# Called by CutsceneController to lock/unlock movement
func set_can_move(value: bool) -> void:
	can_move = value

# Optional: quick reset to spawn marker (used in cutscenes)
func respawn_at_marker(marker: Node2D) -> void:
	global_position = marker.global_position
