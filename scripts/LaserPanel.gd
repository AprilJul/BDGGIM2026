extends Node2D

@onready var area = $Area2D
var is_open: bool = false
const LASER_STEP: float = 10.0

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")

	# Laser 1
	%BtnL1Up.pressed.connect(func(): _on_laser_adjust(0, LASER_STEP))
	%BtnL1Down.pressed.connect(func(): _on_laser_adjust(0, -LASER_STEP))
	# Laser 2
	%BtnL2Up.pressed.connect(func(): _on_laser_adjust(1, LASER_STEP))
	%BtnL2Down.pressed.connect(func(): _on_laser_adjust(1, -LASER_STEP))
	# Laser 3
	%BtnL3Up.pressed.connect(func(): _on_laser_adjust(2, LASER_STEP))
	%BtnL3Down.pressed.connect(func(): _on_laser_adjust(2, -LASER_STEP))

	GameManager.laser_broken.connect(_on_laser_broken)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)

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
	_update_all_lasers()

	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_all_lasers() -> void:
	var int_bars = [%L1IntBar, %L2IntBar, %L3IntBar]
	var stress_bars = [%L1StressBar, %L2StressBar, %L3StressBar]
	var status_labels = [%L1StatusLabel, %L2StatusLabel, %L3StatusLabel]
	var btn_ups = [%BtnL1Up, %BtnL2Up, %BtnL3Up]
	var btn_downs = [%BtnL1Down, %BtnL2Down, %BtnL3Down]

	for i in range(3):
		var broken = GameManager.laser_broken_states[i]
		var intensity = GameManager.laser_intensities[i]
		var stress = GameManager.laser_stresses[i]
		var durability = GameManager.laser_durabilities[i]

		# Intensity bar
		int_bars[i].value = intensity
		int_bars[i].modulate = Color("#888780") if broken else Color.WHITE

		# Stress bar
		stress_bars[i].value = stress
		if stress > 75.0:
			stress_bars[i].modulate = Color("#E8593C")
		elif stress > 50.0:
			stress_bars[i].modulate = Color("#EF9F27")
		else:
			stress_bars[i].modulate = Color.WHITE

		# Status label
		if broken:
			status_labels[i].text = "⚠ BROKEN"
			status_labels[i].modulate = Color("#E8593C")
		elif durability < 60.0:
			status_labels[i].text = "DEGRADED %.0f%%" % durability
			status_labels[i].modulate = Color("#EF9F27")
		elif stress > 75.0:
			status_labels[i].text = "HIGH STRESS"
			status_labels[i].modulate = Color("#E8593C")
		else:
			status_labels[i].text = "● NOMINAL"
			status_labels[i].modulate = Color("#3B9E7A")

		# Disable buttons kalau broken
		btn_ups[i].disabled = broken
		btn_downs[i].disabled = broken

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_laser_adjust(index: int, amount: float) -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_laser(index,
		GameManager.laser_intensities[index] + amount)

func _on_laser_broken(index: int) -> void:
	# Flash status label saat laser rusak
	var status_labels = [%L1StatusLabel, %L2StatusLabel, %L3StatusLabel]
	var tween = create_tween()
	tween.set_loops(4)
	tween.tween_property(status_labels[index], "modulate:a", 0.1, 0.15)
	tween.tween_property(status_labels[index], "modulate:a", 1.0, 0.15)

func _on_mcs_state_changed(is_active: bool) -> void:
	for btn in [%BtnL1Up, %BtnL1Down, %BtnL2Up, %BtnL2Down, %BtnL3Up, %BtnL3Down]:
		btn.disabled = is_active
