extends Node2D

@onready var area = $Area2D
var is_open: bool = false

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")
	%BtnHeal.pressed.connect(_on_heal)
	GameManager.medbay_used.connect(_on_healed)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)
	%HPBar.max_value = 100.0

func open_panel() -> void:
	is_open = true
	GameManager.is_in_panel_mode = true
	%PanelUI.visible = true
	var viewport_size = get_viewport().get_visible_rect().size
	%PanelContainer.position = (viewport_size - %PanelContainer.size) / 2.0
	_zoom_in()

func close_panel() -> void:
	is_open = false
	GameManager.is_in_panel_mode = false
	%PanelUI.visible = false
	_zoom_out()

func _zoom_in() -> void:
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(camera, "zoom", Vector2(2.5, 2.5), 0.5)
	tween.parallel().tween_property(camera, "global_position", global_position, 0.5)

func _zoom_out() -> void:
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.4)
	tween.parallel().tween_property(camera, "global_position", player.global_position, 0.4)

func _process(_delta: float) -> void:
	if not is_open:
		return
	_update_ui()
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_ui() -> void:
	# HP bar
	%HPBar.value = GameManager.player_hp
	%HPValueLabel.text = "%.0f%%" % GameManager.player_hp
	if GameManager.player_hp < 30.0:
		%HPBar.modulate = Color("#E8593C")
		%HPValueLabel.modulate = Color("#E8593C")
	elif GameManager.player_hp < 60.0:
		%HPBar.modulate = Color("#EF9F27")
		%HPValueLabel.modulate = Color("#EF9F27")
	else:
		%HPBar.modulate = Color.WHITE
		%HPValueLabel.modulate = Color.WHITE

	# Cooldown + button
	if GameManager.medbay_cooldown > 0.0:
		%BtnHeal.disabled = true
		%BtnHeal.text = "RESTORE HP"
		%CooldownLabel.text = "Available in %.0fs" % GameManager.medbay_cooldown
		%CooldownLabel.modulate = Color("#888780")
	elif GameManager.player_hp >= 100.0:
		%BtnHeal.disabled = true
		%CooldownLabel.text = "HP already full"
		%CooldownLabel.modulate = Color("#3B9E7A")
	else:
		%BtnHeal.disabled = false
		%CooldownLabel.text = "READY"
		%CooldownLabel.modulate = Color("#3B9E7A")

func _on_heal() -> void:
	GameManager.use_medbay()

func _on_healed() -> void:
	%StatusLabel.text = "✓ HP RESTORED"
	%StatusLabel.modulate = Color("#3B9E7A")
	var tween = create_tween()
	tween.tween_property(%StatusLabel, "modulate:a", 0.0, 2.0)

func _on_mcs_state_changed(is_active: bool) -> void:
	%BtnHeal.disabled = is_active
