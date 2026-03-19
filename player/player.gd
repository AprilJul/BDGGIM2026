extends CharacterBody2D

var speed = 100
var player_state
var can_move := true

@onready var shape_cast = $ShapeCast2D
@onready var map_system = get_node_or_null("/root/MainHouse/MapCanvas/MapSystem")


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
