extends CharacterBody2D

@onready var world = get_parent()

var speed = 100
var player_state = "idle"
var waiting_for_tutorial_move = false
var can_move = true

func _physics_process(_delta):
	# This part effectively "freezes" the keys 
	if not can_move:
		velocity = Vector2.ZERO
		player_state = "idle"         # Force state to idle
		play_animation(Vector2.ZERO)  # Trigger the idle animation
		return

	# 1. Get Input Direction
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 2. Set Velocity and State
	if direction == Vector2.ZERO:
		player_state = "idle"
		velocity = Vector2.ZERO
	else:
		player_state = "walking"
		velocity = direction * speed
	
	# 3. Move and Animate
	move_and_slide()
	play_animation(direction)
	
	# For continue the dialogue after admin said the movement button
	if direction != Vector2.ZERO and waiting_for_tutorial_move:
		waiting_for_tutorial_move = false
		trigger_delayed_dialogue() # Call a new helper function

# Triggering the after_movement dialogue
func trigger_delayed_dialogue():
	# Wait for 1.5 seconds (adjust this number to your liking)
	await get_tree().create_timer(1.5).timeout
	
	# Now tell the world to start the next part
	if world.has_method("start_my_dialogue"):
		world.start_my_dialogue("after_movement")

func play_animation(dir):
	if player_state == "idle":
		$AnimatedSprite2D.play("idle")
	elif player_state == "walking":
		# Choose horizontal vs vertical animation based on strongest input
		if abs(dir.x) > abs(dir.y):
			$AnimatedSprite2D.play("walk_right" if dir.x > 0 else "walk_left")
		else:
			$AnimatedSprite2D.play("walk_front" if dir.y > 0 else "walk_back")
