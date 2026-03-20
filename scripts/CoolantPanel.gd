extends Node2D

@onready var panel_ui = $PanelUI
@onready var area = $Area2D

var is_open: bool = false

func _ready() -> void:
	panel_ui.visible = false
	# Daftarkan Area2D ke group biar Player bisa deteksi
	area.add_to_group("interaction_panel")

func open_panel() -> void:
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
	# Ambil kamera dari player
	var camera = get_tree().get_first_node_in_group("player_camera")
	if camera == null:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Zoom in ke 2.5x dan geser kamera ke posisi panel
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
	# Zoom out balik ke normal dan kamera kembali ikut player
	tween.parallel().tween_property(camera, "zoom", Vector2(1.0, 1.0), 0.4)
	tween.parallel().tween_property(camera, "global_position", player.global_position, 0.4)

func _process(_delta: float) -> void:
	if not is_open:
		return
	# Deteksi flick mouse ke bawah layar (dalam 50px dari batas bawah)
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()
