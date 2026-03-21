extends Area2D

# Set nama ruangan ini di Inspector
@export var room_name: String = "control_room"

# Warna debug — beda tiap ruangan biar gampang dibedain di editor
@export var debug_color: Color = Color(0.2, 0.8, 0.4, 0.3)

func _ready() -> void:
	# Collision setup
	collision_layer = 0
	collision_mask = 1    # deteksi player (layer 1)
	
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)
	
	# Debug visual di editor
	if Engine.is_editor_hint():
		return

func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.set_room(room_name)
		print("Player entered: ", room_name)

func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player"):
		# Kalau keluar dari ruangan ini, set ke "corridor" atau ruangan default
		# Nanti bisa dioverride kalau ada ruangan yang saling overlap
		if GameManager.current_room == room_name:
			GameManager.set_room("corridor")
			print("Player left: ", room_name)

func _draw() -> void:
	# Hanya di editor — tampilkan warna zone
	if not Engine.is_editor_hint():
		return
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		draw_rect(Rect2(-shape.size/2, shape.size), debug_color)
		draw_rect(Rect2(-shape.size/2, shape.size), 
			Color(debug_color.r, debug_color.g, debug_color.b, 1.0), false, 2.0)
