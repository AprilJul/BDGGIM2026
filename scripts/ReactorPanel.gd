extends Node2D

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var panel_ui = $PanelUI
@onready var area = $Area2D

@onready var laser_bar = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/LaserRow/ProgressBar
@onready var extract_bar = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/ExtractRow/ProgressBar
@onready var stress_bar = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/StressRow/StressBar
@onready var btn_laser_up = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/LaserRow/BtnLaserUp
@onready var btn_laser_down = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/LaserRow/BtnLaserDown
@onready var btn_extract_up = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/ExtractRow/BtnExtractUp
@onready var btn_extract_down = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/ExtractRow/BtnExtractDown
@onready var btn_vent = $PanelUI/PanelContainer/MarginContainer/VBoxContainer/BottomRow/BtnVent
@onready var charge_labels = [
	$PanelUI/PanelContainer/MarginContainer/VBoxContainer/BottomRow/ECCSRow/Charge1,
	$PanelUI/PanelContainer/MarginContainer/VBoxContainer/BottomRow/ECCSRow/Charge2,
	$PanelUI/PanelContainer/MarginContainer/VBoxContainer/BottomRow/ECCSRow/Charge3
]

var is_open: bool = false
const LASER_STEP: float = 10.0
const EXTRACT_STEP: float = 10.0

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	panel_ui.visible = false
	area.add_to_group("interaction_panel")
	print("ReactorPanel ready, area group: ", area.get_groups())

	# Hubungkan tombol
	btn_laser_up.pressed.connect(_on_laser_up)
	btn_laser_down.pressed.connect(_on_laser_down)
	btn_extract_up.pressed.connect(_on_extract_up)
	btn_extract_down.pressed.connect(_on_extract_down)
	btn_vent.toggled.connect(_on_vent_toggled)

	# Hubungkan sinyal GameManager
	GameManager.reactor_state_changed.connect(_on_reactor_state_changed)

# ============================================================
# PANEL OPEN / CLOSE
# ============================================================
func open_panel() -> void:
	print("open_panel() dipanggil!")
	is_open = true
	GameManager.is_in_panel_mode = true
	panel_ui.visible = true
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
# UPDATE VISUAL TIAP FRAME
# ============================================================
func _process(_delta: float) -> void:
	if not is_open:
		return

	# Update bar sesuai nilai GameManager
	laser_bar.value = GameManager.laser_intensity
	extract_bar.value = GameManager.extraction_level
	stress_bar.value = GameManager.extraction_stress

	# Update warna stress bar
	if GameManager.extraction_stress > 75.0:
		stress_bar.modulate = Color("#E8593C")
	elif GameManager.extraction_stress > 50.0:
		stress_bar.modulate = Color("#EF9F27")
	else:
		stress_bar.modulate = Color.WHITE

	# Update ECCS charge indicator
	for i in range(3):
		if i < GameManager.eccs_charges:
			charge_labels[i].modulate = Color("#3B9E7A")  # hijau = ada charge
		else:
			charge_labels[i].modulate = Color("#444441")  # abu = habis

	# Disable tombol extract kalau extractor rusak
	btn_extract_up.disabled = GameManager.extractor_broken
	btn_extract_down.disabled = GameManager.extractor_broken

	# Flick mouse ke bawah = tutup panel
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

# ============================================================
# BUTTON HANDLERS — pakai input delay dari CPU temp!
# ============================================================
func _on_laser_up() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_laser(GameManager.laser_intensity + LASER_STEP)

func _on_laser_down() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_laser(GameManager.laser_intensity - LASER_STEP)

func _on_extract_up() -> void:
	if GameManager.extractor_broken:
		return
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_extraction(GameManager.extraction_level + EXTRACT_STEP)

func _on_extract_down() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_extraction(GameManager.extraction_level - EXTRACT_STEP)

func _on_vent_toggled(pressed: bool) -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.toggle_vent(pressed)

# ============================================================
# REACTOR STATE — ubah warna panel saat bahaya
# ============================================================
func _on_reactor_state_changed(new_state: int) -> void:
	var panel_container = $PanelUI/PanelContainer
	match new_state:
		-1, 1:
			panel_container.modulate = Color.WHITE
		2:
			panel_container.modulate = Color("#FFF3CD")  # kuning muda
		3:
			panel_container.modulate = Color("#FFD0C0")  # oranye muda
		4:
			panel_container.modulate = Color("#FFB0B0")  # merah muda
