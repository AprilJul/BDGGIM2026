extends Node2D

@export var dialogue_resource: DialogueResource
@export var dialogue_start_node: String = "start"
# Link custom dialogue balloon
@export var custom_balloon_scene: PackedScene = preload("res://dialogue/balloon.tscn")


@onready var player = $Player

func _process(_delta):
	if Input.is_action_just_pressed("test_dialogue"):
		# Start the initial tutorial
		start_my_dialogue("start")

func start_my_dialogue(node_name: String):
	if dialogue_resource and custom_balloon_scene:
		# 1. Freeze the player and reset their physics immediately
		player.can_move = false
		player.velocity = Vector2.ZERO 
		
		var balloon = custom_balloon_scene.instantiate()
		get_tree().current_scene.add_child(balloon)
		balloon.start(dialogue_resource, node_name)
		
		# 2. Wait for the balloon to be closed/deleted to unfreeze
		balloon.tree_exited.connect(_on_balloon_closed)
		
		if node_name == "start":
			player.waiting_for_tutorial_move = true

func _on_balloon_closed():
	# If we are waiting for the tutorial move, we MUST unfreeze the player 
	# so they can actually press WASD!
	if player.waiting_for_tutorial_move:
		player.can_move = true
	else:
		# For all other dialogues (like 'after_movement'), 
		# we unfreeze normally when the box closes.
		player.can_move = true
