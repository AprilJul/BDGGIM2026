extends Node2D

@onready var panel_ui = %PanelUI
@onready var area = $Area2D

@onready var btn_eccs = %BtnECCS
@onready var btn_event = %BtnEVent
@onready var btn_mcs = %BtnMCS

@onready var charge_labels = [%Charge1, %Charge2, %Charge3]
@onready var eccs_cooldown_label = %ECCSCooldownLabel
@onready var event_cooldown_label = %EVentCooldownLabel
@onready var mcs_status_label = %MCSStatusLabel
@onready var mcs_warning_label = %MCSWarningLabel

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
	btn_mcs.pressed.connect(_on_mcs_pressed)

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
	_update_mcs_ui()

	# Flick mouse ke bawah = tutup panel
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_eccs_ui() -> void:
	# Update charge indicators
	for i in range(3):
		if i < GameManager.eccs_charges:
			charge_labels[i].modulate = Color("#3B9E7A")
		else:
			charge_labels[i].modulate = Color("#444441")

	# Cooldown label
	if GameManager.eccs_cooldown > 0.0:
		eccs_cooldown_label.text = "CD: %.0fs" % GameManager.eccs_cooldown
		btn_eccs.disabled = true
	else:
		eccs_cooldown_label.text = ""
		btn_eccs.disabled = GameManager.eccs_charges <= 0

func _update_event_ui() -> void:
	if GameManager.emergency_vent_cooldown > 0.0:
		event_cooldown_label.text = "CD: %.0fs" % GameManager.emergency_vent_cooldown
		btn_event.disabled = true
	else:
		event_cooldown_label.text = "READY"
		event_cooldown_label.modulate = Color("#3B9E7A")
		btn_event.disabled = false

func _update_mcs_ui() -> void:
	if GameManager.mcs_broken:
		btn_mcs.disabled = true
		mcs_status_label.text = "⚠ CPU MODULE DAMAGED"
		mcs_status_label.modulate = Color("#E8593C")
		mcs_warning_label.text = "Repair required at Reactor Room"
	elif GameManager.mcs_active:
		btn_mcs.disabled = true
		mcs_status_label.text = "● SHUTDOWN IN PROGRESS"
		mcs_status_label.modulate = Color("#3B9E7A")
	elif GameManager.mcs_used_count >= 1:
		btn_mcs.disabled = false
		mcs_status_label.text = "⚠ NEXT USE: 50% FAILURE"
		mcs_status_label.modulate = Color("#EF9F27")
		mcs_warning_label.modulate = Color("#E8593C")
	else:
		btn_mcs.disabled = false
		mcs_status_label.text = "STANDBY"
		mcs_status_label.modulate = Color("#888780")

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_eccs_pressed() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.use_eccs()

func _on_event_pressed() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.use_emergency_vent()

func _on_mcs_pressed() -> void:
	# MCS terlalu berbahaya untuk kena input delay — langsung eksekusi
	GameManager.use_mcs()

func _on_mcs_state_changed(is_active: bool) -> void:
	btn_eccs.disabled = is_active
	btn_event.disabled = is_active
	# MCS button tetap disabled saat active — sudah ditangani _update_mcs_ui
