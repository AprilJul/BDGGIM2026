extends CanvasLayer

@onready var temp_bar = $MarginContainer/VBoxContainer/ReactorBar/ProgressBar
@onready var pressure_bar = $MarginContainer/VBoxContainer/PressureBar/ProgressBar
@onready var electricity_bar = $MarginContainer/VBoxContainer/ElectricityBar/ProgressBar
@onready var hp_bar = $MarginContainer/VBoxContainer/PlayerBars/HPBar/ProgressBar
@onready var armor_bar = $MarginContainer/VBoxContainer/PlayerBars/ArmorBar/ProgressBar
@onready var status_label = $MarginContainer/VBoxContainer/ReactorBar/StatusLabel

# Label nilai — kita tambah ini biar bisa tulis "245°C" dll
@onready var temp_label = $MarginContainer/VBoxContainer/ReactorBar/ValueLabel
@onready var pressure_label = $MarginContainer/VBoxContainer/PressureBar/ValueLabel
@onready var electricity_label = $MarginContainer/VBoxContainer/ElectricityBar/ValueLabel

func _ready() -> void:
	# Set max value ProgressBar sesuai unit realistis
	temp_bar.max_value = 350.0
	pressure_bar.max_value = 2200.0
	electricity_bar.max_value = 1000.0
	hp_bar.max_value = 100.0
	armor_bar.max_value = 100.0

	# Matikan show percentage bawaan — kita tulis sendiri
	temp_bar.show_percentage = false
	pressure_bar.show_percentage = false
	electricity_bar.show_percentage = false

	GameManager.game_ended.connect(_on_game_ended)
	GameManager.night_toggled.connect(_on_night_toggled)

func _process(_delta: float) -> void:
	_update_bars()
	_update_status()

func _update_bars() -> void:
	# Update nilai bar
	temp_bar.value = GameManager.reactor_temp
	pressure_bar.value = GameManager.reactor_pressure
	electricity_bar.value = GameManager.electricity_quota
	hp_bar.value = GameManager.player_hp
	armor_bar.value = GameManager.armor_hp

	# Update label nilai dengan unit
	temp_label.text = "%.0f°C" % GameManager.reactor_temp
	pressure_label.text = "%.0f PSI" % GameManager.reactor_pressure
	electricity_label.text = "%.1f / 1000 MW/h" % GameManager.electricity_quota

func _update_status() -> void:
	match GameManager.reactor_state:
		-1:
			status_label.text = "⚠ SUB-ZERO"
			status_label.modulate = Color("#3B8BD4")
		1:
			status_label.text = "● NORMAL"
			status_label.modulate = Color("#3B9E7A")
		2:
			status_label.text = "⚠ WARNING"
			status_label.modulate = Color("#EF9F27")
		3:
			status_label.text = "‼ CRITICAL"
			status_label.modulate = Color("#E8593C")
		4:
			status_label.text = "☢ MELTDOWN"
			status_label.modulate = Color("#E8593C")

func _on_game_ended(reason: String) -> void:
	match reason:
		"win":
			status_label.text = "✓ DISTRESS SIGNAL ACTIVE"
			status_label.modulate = Color("#3B9E7A")
		"meltdown":
			status_label.text = "☢ REACTOR MELTDOWN"
			status_label.modulate = Color("#E8593C")
		"blackhole":
			status_label.text = "◉ BLACKHOLE EVENT"
			status_label.modulate = Color("#3B8BD4")
		"death":
			status_label.text = "✕ OPERATOR DOWN"
			status_label.modulate = Color("#888780")

func _on_night_toggled(night: bool) -> void:
	if night:
		print("Malam tiba!")
