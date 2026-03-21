extends Node2D

@onready var area = $Area2D
var is_open: bool = false

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")
	%BtnReplaceCPU.pressed.connect(_on_replace_cpu)
	GameManager.cpu_module_replaced.connect(_on_cpu_replaced)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)
	%CPUTempBar.max_value = 100.0

# ============================================================
# OPEN / CLOSE
# ============================================================
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

# ============================================================
# UPDATE
# ============================================================
func _process(_delta: float) -> void:
	if not is_open:
		return
	_update_ui()

	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_ui() -> void:
	var cpu_temp = GameManager.cpu_temp
	var input_delay = GameManager.input_delay

	# CPU temp bar
	%CPUTempBar.value = cpu_temp
	%CPUTempLabel.text = "%.0f°C" % cpu_temp
	if cpu_temp > 80.0:
		%CPUTempBar.modulate = Color("#E8593C")
		%CPUTempLabel.modulate = Color("#E8593C")
	elif cpu_temp > 65.0:
		%CPUTempBar.modulate = Color("#EF9F27")
		%CPUTempLabel.modulate = Color("#EF9F27")
	else:
		%CPUTempBar.modulate = Color.WHITE
		%CPUTempLabel.modulate = Color.WHITE

	# Input delay label
	if input_delay > 0.0:
		%DelayLabel.text = "%.1fs ⚡" % input_delay
		%DelayLabel.modulate = Color("#E8593C") \
			if input_delay > 1.5 else Color("#EF9F27")
	else:
		%DelayLabel.text = "None"
		%DelayLabel.modulate = Color("#3B9E7A")

	# CPU status
	if GameManager.cpu_broken:
		%CPUStatusLabel.text = "⚠ MODULE FAILED"
		%CPUStatusLabel.modulate = Color("#E8593C")
	elif cpu_temp > 80.0:
		%CPUStatusLabel.text = "⚠ OVERHEATING"
		%CPUStatusLabel.modulate = Color("#E8593C")
	elif cpu_temp > 65.0:
		%CPUStatusLabel.text = "▶ THROTTLING"
		%CPUStatusLabel.modulate = Color("#EF9F27")
	else:
		%CPUStatusLabel.text = "● NOMINAL"
		%CPUStatusLabel.modulate = Color("#3B9E7A")

	# Module stock + button
	%ModuleStockLabel.text = "CPU Modules: %d" % GameManager.inv_cpu_module
	%ModuleStockLabel.modulate = Color("#3B9E7A") \
		if GameManager.inv_cpu_module > 0 else Color("#888780")

	var can_replace = GameManager.inv_cpu_module > 0 and cpu_temp > 40.0
	%BtnReplaceCPU.disabled = not can_replace

	if GameManager.inv_cpu_module <= 0:
		%CooldownLabel.text = "No modules — craft at Lab"
		%CooldownLabel.modulate = Color("#888780")
	elif cpu_temp <= 40.0:
		%CooldownLabel.text = "CPU too cold to replace"
		%CooldownLabel.modulate = Color("#888780")
	else:
		%CooldownLabel.text = "Replace to reset temp & delay"
		%CooldownLabel.modulate = Color("#3B9E7A")

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_replace_cpu() -> void:
	# CPU replacement tidak kena input delay
	# (karena kamu lagi di CPU room, bukan control room)
	GameManager.replace_cpu_module()

func _on_cpu_replaced() -> void:
	%CPUStatusLabel.text = "● MODULE REPLACED"
	%CPUStatusLabel.modulate = Color("#3B9E7A")
	# Flash
	var tween = create_tween()
	tween.tween_property(%CPUStatusLabel, "modulate:a", 0.2, 0.2)
	tween.tween_property(%CPUStatusLabel, "modulate:a", 1.0, 0.2)

func _on_mcs_state_changed(is_active: bool) -> void:
	%BtnReplaceCPU.disabled = is_active
