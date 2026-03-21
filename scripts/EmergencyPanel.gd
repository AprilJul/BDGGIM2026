extends Node2D

@onready var panel_ui = %PanelUI
@onready var area = $Area2D

@onready var btn_eccs = %BtnECCS
@onready var btn_event = %BtnEVent

@onready var charge_labels = [%Charge1, %Charge2, %Charge3]
@onready var eccs_cooldown_label = %ECCSCooldownLabel
@onready var event_cooldown_label = %EVentCooldownLabel

var is_open: bool = false

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	print("=== EmergencyPanel _ready() START ===")

	# Group dan connect DULU — tidak boleh di-skip
	area.add_to_group("interaction_panel")

	%PanelUI.visible = false

	btn_eccs.pressed.connect(_on_eccs_pressed)
	btn_event.pressed.connect(_on_event_pressed)

	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)

# ============================================================
# OPEN / CLOSE
# ============================================================
func open_panel() -> void:
	print("EmergencyPanel open_panel() called!")
	is_open = true
	GameManager.is_in_panel_mode = true
	panel_ui.visible = true
	var viewport_size = get_viewport().get_visible_rect().size
	%PanelContainer.position = (viewport_size - %PanelContainer.size) / 2.0
	_zoom_in()

func close_panel() -> void:
	is_open = false
	GameManager.is_in_panel_mode = false
	panel_ui.visible = false
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

	_update_eccs_ui()
	_update_event_ui()

	# Flick mouse ke bawah = tutup panel
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_eccs_ui() -> void:
	for i in range(3):
		if i < GameManager.eccs_charges:
			charge_labels[i].modulate = Color("#3B9E7A")
		else:
			charge_labels[i].modulate = Color("#444441")

	if GameManager.eccs_active:
		# Tampilkan progress cooling
		var progress = GameManager.eccs_cooling_timer / GameManager.ECCS_COOLING_DURATION
		var temp_drop_so_far = (1.0 - progress) * \
			(GameManager.ECCS_COOLING_RATE * GameManager.ECCS_COOLING_DURATION)
		eccs_cooldown_label.text = "COOLING... %.0fs  (-%.0f°C)" % [
			GameManager.eccs_cooling_timer,
			temp_drop_so_far
		]
		eccs_cooldown_label.modulate = Color("#3B9E7A")
		btn_eccs.disabled = true
		btn_eccs.text = "ECCS ACTIVE"
	elif GameManager.eccs_cooldown > 0.0:
		eccs_cooldown_label.text = "CD: %.0fs" % GameManager.eccs_cooldown
		eccs_cooldown_label.modulate = Color("#888780")
		btn_eccs.disabled = true
		btn_eccs.text = "ECCS — ACTIVATE"
	else:
		eccs_cooldown_label.text = ""
		btn_eccs.disabled = GameManager.eccs_charges <= 0
		btn_eccs.text = "ECCS — ACTIVATE"

func _update_event_ui() -> void:
	if GameManager.emergency_vent_active:
		# Tampilkan progress venting
		var progress = GameManager.emergency_vent_timer / GameManager.EMERGENCY_VENT_DURATION
		var psi_drop_so_far = (1.0 - progress) * \
			(GameManager.EMERGENCY_VENT_RATE * GameManager.EMERGENCY_VENT_DURATION)
		event_cooldown_label.text = "VENTING... %.0fs  (-%.0f PSI)" % [
			GameManager.emergency_vent_timer,
			psi_drop_so_far
		]
		event_cooldown_label.modulate = Color("#3B8BD4")
		btn_event.disabled = true
		btn_event.text = "VENTING..."
	elif GameManager.emergency_vent_cooldown > 0.0:
		event_cooldown_label.text = "CD: %.0fs" % GameManager.emergency_vent_cooldown
		event_cooldown_label.modulate = Color("#888780")
		btn_event.disabled = true
		btn_event.text = "EMERGENCY VENT"
	else:
		event_cooldown_label.text = "READY"
		event_cooldown_label.modulate = Color("#3B9E7A")
		btn_event.disabled = false
		btn_event.text = "EMERGENCY VENT"

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_eccs_pressed() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.use_eccs()

func _on_event_pressed() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.use_emergency_vent()

func _on_mcs_state_changed(is_active: bool) -> void:
	btn_eccs.disabled = is_active
	btn_event.disabled = is_active
	# MCS button tetap disabled saat active — sudah ditangani _update_mcs_ui
