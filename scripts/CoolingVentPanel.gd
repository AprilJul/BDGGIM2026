extends Node2D

@onready var area = $Area2D
var is_open: bool = false

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")

	# Coolant buttons
	%BtnToggle.pressed.connect(_on_coolant_toggle)
	%BtnLow.pressed.connect(_on_rpm_low)
	%BtnMed.pressed.connect(_on_rpm_med)
	%BtnHigh.pressed.connect(_on_rpm_high)
	%BtnRefillECCS.pressed.connect(_on_refill_eccs)

	# Vent buttons
	%BtnVent1.pressed.connect(func(): _on_vent_toggle(0))
	%BtnVent2.pressed.connect(func(): _on_vent_toggle(1))
	%BtnVent3.pressed.connect(func(): _on_vent_toggle(2))
	%BtnVent4.pressed.connect(func(): _on_vent_toggle(3))

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
	_update_coolant_ui()
	_update_vent_ui()

	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_coolant_ui() -> void:
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

	# Toggle button
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

	# RPM buttons
	var locked = not GameManager.coolant_active or GameManager.coolant_pump_broken
	%BtnLow.disabled = locked
	%BtnMed.disabled = locked
	%BtnHigh.disabled = locked
	%BtnLow.modulate = Color("#3B9E7A") if GameManager.coolant_rpm == 1 else Color.WHITE
	%BtnMed.modulate = Color("#EF9F27") if GameManager.coolant_rpm == 2 else Color.WHITE
	%BtnHigh.modulate = Color("#E8593C") if GameManager.coolant_rpm == 3 else Color.WHITE

	# Pump status
	if GameManager.coolant_pump_broken:
		%PumpStatusLabel.text = "⚠ BROKEN"
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
	if GameManager.eccs_charges >= 3:
		%RefillCostLabel.text = "ECCS full (3/3)"
		%RefillCostLabel.modulate = Color("#888780")
	elif GameManager.coolant_storage < 30.0:
		%RefillCostLabel.text = "Need 30 storage"
		%RefillCostLabel.modulate = Color("#E8593C")
	else:
		%RefillCostLabel.text = "costs 30  |  ECCS: %d/3" % GameManager.eccs_charges
		%RefillCostLabel.modulate = Color("#3B9E7A")

func _update_vent_ui() -> void:
	# Efektivitas vent berdasarkan pressure
	var pressure = GameManager.reactor_pressure
	var effectiveness_text: String
	var effectiveness_color: Color

	if pressure <= GameManager.VENT_EFFECTIVE_THRESHOLD:
		effectiveness_text = "● HIGHLY EFFECTIVE (pressure low)"
		effectiveness_color = Color("#3B9E7A")
	elif pressure >= GameManager.VENT_INEFFECTIVE_THRESHOLD:
		effectiveness_text = "⚠ INEFFECTIVE (pressure too high)"
		effectiveness_color = Color("#E8593C")
	else:
		var ratio = (pressure - GameManager.VENT_EFFECTIVE_THRESHOLD) / \
			(GameManager.VENT_INEFFECTIVE_THRESHOLD - GameManager.VENT_EFFECTIVE_THRESHOLD)
		var pct = int((1.0 - ratio) * 100)
		effectiveness_text = "▶ EFFECTIVENESS: %d%%" % pct
		effectiveness_color = Color("#EF9F27")

	%VentStatusLabel.text = effectiveness_text
	%VentStatusLabel.modulate = effectiveness_color

	# Active vent count
	var active = GameManager.get_active_vent_count()
	if active > 0:
		%VentStatusLabel.text += "  [%d/4 active]" % active

	# Tiap vent button
	var vent_buttons = [%BtnVent1, %BtnVent2, %BtnVent3, %BtnVent4]
	var vent_statuses = [%Vent1Status, %Vent2Status, %Vent3Status, %Vent4Status]

	for i in range(4):
		var is_active = GameManager.vent_states[i]
		vent_buttons[i].text = "VENT %d %s" % [i + 1, "●" if is_active else "○"]
		if is_active:
			vent_buttons[i].modulate = Color("#3B9E7A")
			vent_statuses[i].text = "OPEN"
			vent_statuses[i].modulate = Color("#3B9E7A")
		else:
			vent_buttons[i].modulate = Color.WHITE
			vent_statuses[i].text = "CLOSED"
			vent_statuses[i].modulate = Color("#888780")

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_coolant_toggle() -> void:
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

func _on_vent_toggle(index: int) -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.toggle_vent(index)

func _on_pump_damaged() -> void:
	%WarningLabel.text = "⚠ PUMP DAMAGED — repair at Lab!"
	%WarningLabel.modulate = Color("#E8593C")

func _on_mcs_state_changed(is_active: bool) -> void:
	%BtnToggle.disabled = is_active
	%BtnRefillECCS.disabled = is_active
	for btn in [%BtnVent1, %BtnVent2, %BtnVent3, %BtnVent4]:
		btn.disabled = is_active
