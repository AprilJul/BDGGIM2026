extends Node2D

@onready var area = $Area2D
var is_open: bool = false

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")

	%BtnHazmat.pressed.connect(_on_hazmat_toggle)
	%BtnRepair.pressed.connect(_on_repair)

	GameManager.armor_repair_completed.connect(_on_repair_completed)
	GameManager.hazmat_toggled.connect(_on_hazmat_toggled)
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
	_update_ui()

	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_ui() -> void:
	_update_hazmat_ui()
	_update_armor_ui()
	_update_repair_ui()

func _update_hazmat_ui() -> void:
	if GameManager.hazmat_equipped:
		%BtnHazmat.text = "UNEQUIP HAZMAT"
		%BtnHazmat.modulate = Color("#3B9E7A")
		%HazmatStatus.text = "● EQUIPPED — 60% rad. resist."
		%HazmatStatus.modulate = Color("#3B9E7A")
	else:
		%BtnHazmat.text = "EQUIP HAZMAT"
		%BtnHazmat.modulate = Color.WHITE
		%HazmatStatus.text = "○ UNEQUIPPED"
		%HazmatStatus.modulate = Color("#888780")

func _update_armor_ui() -> void:
	%ArmorBar.value = GameManager.armor_hp
	%ArmorValueLabel.text = "%.0f%%" % GameManager.armor_hp

	if GameManager.armor_hp <= 0.0:
		%ArmorBar.modulate = Color("#E8593C")
		if GameManager.grace_period_active:
			%ArmorValueLabel.text = "GRACE: %.0fs" % GameManager.grace_timer
			%ArmorValueLabel.modulate = Color("#E8593C")
	elif GameManager.armor_hp < 30.0:
		%ArmorBar.modulate = Color("#E8593C")
		%ArmorValueLabel.modulate = Color("#E8593C")
	elif GameManager.armor_hp < 60.0:
		%ArmorBar.modulate = Color("#EF9F27")
		%ArmorValueLabel.modulate = Color("#EF9F27")
	else:
		%ArmorBar.modulate = Color.WHITE
		%ArmorValueLabel.modulate = Color.WHITE

func _update_repair_ui() -> void:
	%StockLabel.text = "Armor Patch Kit: %d" % GameManager.inv_armor_patch
	%StockLabel.modulate = Color("#3B9E7A") \
		if GameManager.inv_armor_patch > 0 else Color("#888780")

	# Tidak bisa repair kalau hazmat belum equipped
	if not GameManager.hazmat_equipped:
		%RepairBar.value = 0.0
		%RepairLabel.text = "EQUIP HAZMAT FIRST"
		%RepairLabel.modulate = Color("#888780")
		%BtnRepair.disabled = true
		return

	if GameManager.armor_repairing:
		# Tampilkan progress repair
		var progress = 1.0 - (GameManager.armor_repair_timer / GameManager.ARMOR_REPAIR_DURATION)
		%RepairBar.value = progress
		%RepairLabel.text = "REPAIRING... %.0fs" % GameManager.armor_repair_timer
		%RepairLabel.modulate = Color("#EF9F27")
		%BtnRepair.disabled = true
	elif GameManager.armor_hp >= 100.0:
		%RepairBar.value = 1.0
		%RepairLabel.text = "ARMOR FULL"
		%RepairLabel.modulate = Color("#3B9E7A")
		%BtnRepair.disabled = true
	elif GameManager.inv_armor_patch <= 0:
		%RepairBar.value = 0.0
		%RepairLabel.text = "NO PATCH KIT — craft at Lab"
		%RepairLabel.modulate = Color("#888780")
		%BtnRepair.disabled = true
	else:
		%RepairBar.value = 0.0
		%RepairLabel.text = "READY TO REPAIR"
		%RepairLabel.modulate = Color("#3B9E7A")
		%BtnRepair.disabled = false

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_hazmat_toggle() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.toggle_hazmat()

func _on_repair() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.start_armor_repair()

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_repair_completed() -> void:
	%RepairLabel.text = "✓ ARMOR RESTORED"
	%RepairLabel.modulate = Color("#3B9E7A")

func _on_hazmat_toggled(equipped: bool) -> void:
	print("Hazmat toggled: ", equipped)

func _on_mcs_state_changed(is_active: bool) -> void:
	%BtnRepair.disabled = is_active
	%BtnHazmat.disabled = is_active
