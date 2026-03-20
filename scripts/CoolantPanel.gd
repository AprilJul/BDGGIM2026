extends Node2D

@onready var area = $Area2D
var is_open: bool = false

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")

	%BtnToggle.pressed.connect(_on_toggle)
	%BtnLow.pressed.connect(_on_rpm_low)
	%BtnMed.pressed.connect(_on_rpm_med)
	%BtnHigh.pressed.connect(_on_rpm_high)
	%BtnRefillECCS.pressed.connect(_on_refill_eccs)

	GameManager.coolant_pump_damaged.connect(_on_pump_damaged)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)

	%StorageBar.max_value = GameManager.COOLANT_STORAGE_MAX

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
	# Storage bar
	%StorageBar.value = GameManager.coolant_storage
	%StorageLabel.text = "%.0f / %.0f" % [
		GameManager.coolant_storage,
		GameManager.COOLANT_STORAGE_MAX
	]
	if GameManager.coolant_storage < 50.0:
		%StorageBar.modulate = Color("#E8593C")
	elif GameManager.coolant_storage < 150.0:
		%StorageBar.modulate = Color("#EF9F27")
	else:
		%StorageBar.modulate = Color.WHITE

	# Toggle button + status
	if GameManager.coolant_pump_broken:
		%BtnToggle.text = "PUMP BROKEN"
		%BtnToggle.disabled = true
		%StatusLabel.text = "⚠ DAMAGED"
		%StatusLabel.modulate = Color("#E8593C")
	elif GameManager.coolant_active:
		%BtnToggle.text = "TURN OFF"
		%BtnToggle.modulate = Color("#E8593C")
		%StatusLabel.text = "● PUMPING"
		%StatusLabel.modulate = Color("#3B9E7A")
	else:
		%BtnToggle.text = "TURN ON"
		%BtnToggle.modulate = Color.WHITE
		%StatusLabel.text = "○ OFFLINE"
		%StatusLabel.modulate = Color("#888780")

	# RPM buttons — highlight yang aktif
	var locked = not GameManager.coolant_active or GameManager.coolant_pump_broken
	%BtnLow.disabled = locked
	%BtnMed.disabled = locked
	%BtnHigh.disabled = locked

	# Highlight RPM aktif
	%BtnLow.modulate = Color("#3B9E7A") if GameManager.coolant_rpm == 1 else Color.WHITE
	%BtnMed.modulate = Color("#EF9F27") if GameManager.coolant_rpm == 2 else Color.WHITE
	%BtnHigh.modulate = Color("#E8593C") if GameManager.coolant_rpm == 3 else Color.WHITE

	# Pump health
	if GameManager.coolant_pump_broken:
		%PumpStatusLabel.text = "⚠ BROKEN — repair at Lab"
		%PumpStatusLabel.modulate = Color("#E8593C")
	elif GameManager.coolant_rpm == 3:
		%PumpStatusLabel.text = "⚠ HIGH STRESS"
		%PumpStatusLabel.modulate = Color("#EF9F27")
	else:
		%PumpStatusLabel.text = "NOMINAL"
		%PumpStatusLabel.modulate = Color("#3B9E7A")

	# ECCS refill
	var can_refill = GameManager.coolant_storage >= 30.0 \
		and GameManager.eccs_charges < 3
	%BtnRefillECCS.disabled = not can_refill
	%RefillCostLabel.text = "costs 30 storage  |  ECCS: %d/3" % GameManager.eccs_charges

	# Warning storage habis
	if GameManager.coolant_storage <= 0.0:
		%WarningLabel.text = "⚠ COOLANT DEPLETED"
		%WarningLabel.modulate = Color("#E8593C")
	elif GameManager.coolant_active and GameManager.coolant_storage < 50.0:
		%WarningLabel.text = "⚠ LOW COOLANT"
		%WarningLabel.modulate = Color("#EF9F27")
	else:
		%WarningLabel.text = ""

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_toggle() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_coolant_active(not GameManager.coolant_active)

func _on_rpm_low() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_coolant_rpm(1)

func _on_rpm_med() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_coolant_rpm(2)

func _on_rpm_high() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_coolant_rpm(3)

func _on_refill_eccs() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.refill_eccs_from_coolant()

func _on_pump_damaged() -> void:
	%WarningLabel.text = "⚠ PUMP DAMAGED — go to Lab!"
	%WarningLabel.modulate = Color("#E8593C")

func _on_mcs_state_changed(is_active: bool) -> void:
	%BtnToggle.disabled = is_active
	%BtnRefillECCS.disabled = is_active
