extends Control

# Pastikan nama Node di Scene Tree sama dengan variabel @onready ini
@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var description_label = $CenterContainer/VBoxContainer/DescriptionLabel

func _ready() -> void:
	# Munculkan kursor mouse agar bisa klik tombol
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_game_over_screen()

func _setup_game_over_screen() -> void:
	# Mengambil alasan dari GameManager yang baru saja kita set
	var reason = GameManager.game_over_reason
	
	match reason:
		"win":
			title_label.text = "MISSION SUCCESS"
			title_label.modulate = Color("#3B9E7A") # Hijau
			description_label.text = "Electricity quota met. The district is safe!"
		"meltdown":
			title_label.text = "REACTOR MELTDOWN"
			title_label.modulate = Color("#E8593C") # Merah
			description_label.text = "Extreme heat and pressure destroyed the facility."
		"blackhole":
			title_label.text = "BLACKHOLE EVENT"
			title_label.modulate = Color("#3B8BD4") # Biru
			description_label.text = "The core collapsed into a localized singularity."
		"death":
			title_label.text = "OPERATOR DOWN"
			title_label.modulate = Color("#EF9F27") # Oranye
			description_label.text = "Armor breached. Your body succumbed to radiation."
		_:
			title_label.text = "CRITICAL FAILURE"
			description_label.text = "The system has shut down unexpectedly."

func _on_restart_button_pressed() -> void:
	_reset_game_stats()
	# Ganti ke scene world kamu (sesuaikan path-nya)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_main_menu_button_pressed() -> void:
	_reset_game_stats()
	# Ganti ke scene main menu (jika sudah ada)
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _reset_game_stats() -> void:
	# Reset semua variabel utama agar saat restart tidak langsung mati lagi
	GameManager.game_over = false
	GameManager.player_hp = 100.0
	GameManager.armor_hp = 100.0
	GameManager.reactor_temp = 180.0
	GameManager.reactor_pressure = 800.0
	GameManager.electricity_quota = 0.0
	GameManager.reactor_shutdown = false
