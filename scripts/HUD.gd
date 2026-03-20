extends CanvasLayer

@onready var temp_bar = $MarginContainer/VBoxContainer/ReactorBar/ProgressBar
@onready var pressure_bar = $MarginContainer/VBoxContainer/PressureBar/ProgressBar
@onready var electricity_bar = $MarginContainer/VBoxContainer/ElectricityBar/ProgressBar
@onready var hp_bar = $MarginContainer/VBoxContainer/PlayerBars/HPBar/ProgressBar
@onready var armor_bar = $MarginContainer/VBoxContainer/PlayerBars/ArmorBar/ProgressBar
@onready var status_label = $MarginContainer/VBoxContainer/ReactorBar/StatusLabel
@onready var shield_bar = $MarginContainer/VBoxContainer/ShieldRow/ProgressBar
@onready var shield_status = $MarginContainer/VBoxContainer/ShieldRow/ShieldStatusLabel
@onready var radiation_warning = $MarginContainer/VBoxContainer/RadiationWarning
@onready var craft_notify = $MarginContainer/VBoxContainer/CraftNotify

# Label nilai — kita tambah ini biar bisa tulis "245°C" dll
@onready var temp_label = $MarginContainer/VBoxContainer/ReactorBar/ValueLabel
@onready var pressure_label = $MarginContainer/VBoxContainer/PressureBar/ValueLabel
@onready var electricity_label = $MarginContainer/VBoxContainer/ElectricityBar/ValueLabel

@onready var night_overlay = $NightOverlay
@onready var night_label = $MarginContainer/HBoxContainer/NightLabel
@onready var timer_label = $MarginContainer/HBoxContainer/TimerLabel

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
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)
	GameManager.night_warning.connect(_on_night_warning)
	night_overlay.color.a = 0.0
	GameManager.grace_period_started.connect(_on_grace_period_started)
	GameManager.control_room_breached.connect(_on_control_room_breached)
	shield_bar.max_value = 100.0
	radiation_warning.text = ""

	GameManager.crafting_completed.connect(_on_crafting_completed)
	GameManager.crafting_started.connect(_on_crafting_started)

func _process(_delta: float) -> void:
	_update_bars()
	_update_status()
	_update_timer()

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

	shield_bar.value = GameManager.control_room_shield

	# Warna shield bar berdasarkan kondisi
	if GameManager.control_room_shield < 40.0:
		shield_bar.modulate = Color("#E8593C")   # merah — shield breach
		shield_status.text = "⚠ BREACH"
		shield_status.modulate = Color("#E8593C")
	elif GameManager.control_room_shield < 70.0:
		shield_bar.modulate = Color("#EF9F27")   # kuning — warning
		shield_status.text = "DEGRADED"
		shield_status.modulate = Color("#EF9F27")
	else:
		shield_bar.modulate = Color.WHITE
		shield_status.text = "NOMINAL"
		shield_status.modulate = Color("#3B9E7A")
	
	# Hazmat indicator di armor label
	var armor_label = $MarginContainer/VBoxContainer/PlayerBars/ArmorBar/Label
	if GameManager.hazmat_equipped:
		armor_label.text = "ARMOR 🛡"
	else:
		armor_label.text = "ARMOR"
	
	# Grace period countdown
	if GameManager.grace_period_active:
		radiation_warning.text = "☢ ARMOR GONE — %.0fs" % GameManager.grace_timer
		radiation_warning.modulate = Color("#E8593C")
	elif not GameManager.hazmat_equipped and GameManager.current_room == "reactor_room":
		radiation_warning.text = "⚠ NO HAZMAT — taking direct damage!"
		radiation_warning.modulate = Color("#E8593C")
	elif GameManager.hazmat_equipped and GameManager.armor_hp <= 20.0:
		# Hanya warning armor critical kalau hazmat equipped DAN di zona berbahaya
		radiation_warning.text = "⚠ ARMOR CRITICAL"
		radiation_warning.modulate = Color("#E8593C")
	else:
		radiation_warning.text = ""
	
	# Warning kalau di reactor room tanpa hazmat
	if GameManager.current_room == "reactor_room" and not GameManager.hazmat_equipped:
		radiation_warning.text = "⚠ NO HAZMAT — taking direct damage!"
		radiation_warning.modulate = Color("#E8593C")

func _update_status() -> void:
	if GameManager.reactor_shutdown:
		status_label.text = "■ COLD SHUTDOWN"
		status_label.modulate = Color("#888780")
		return

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
			

func _update_timer() -> void:
	# Hitung sisa waktu ke transisi berikutnya
	var cycle_pos = fmod(GameManager.time_elapsed, GameManager.day_duration * 2)
	var time_to_next: float
	
	if cycle_pos < GameManager.day_duration:
		# Sedang siang, hitung ke malam
		time_to_next = GameManager.day_duration - cycle_pos
		timer_label.text = "🌑 %.0fs" % time_to_next
		timer_label.modulate = Color("#888780")
	else:
		# Sedang malam, hitung ke siang
		time_to_next = (GameManager.day_duration * 2) - cycle_pos
		timer_label.text = "☀ %.0fs" % time_to_next
		timer_label.modulate = Color("#EF9F27")

func _on_crafting_started(item: String, duration: float) -> void:
	craft_notify.text = "🔬 Crafting %s... (%.0fs)" % [item, duration]
	craft_notify.modulate = Color("#EF9F27")

func _on_crafting_completed(item: String) -> void:
	craft_notify.text = "✓ %s ready!" % item
	craft_notify.modulate = Color("#3B9E7A")
	# Auto clear setelah 3 detik
	await get_tree().create_timer(3.0).timeout
	craft_notify.text = ""

func _on_grace_period_started() -> void:
	# Flash peringatan
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(radiation_warning, "modulate:a", 0.1, 0.3)
	tween.tween_property(radiation_warning, "modulate:a", 1.0, 0.3)

func _on_control_room_breached(_shield: float) -> void:
	radiation_warning.text = "☢ CONTROL ROOM BREACHED"
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(radiation_warning, "modulate:a", 0.1, 0.4)
	tween.tween_property(radiation_warning, "modulate:a", 1.0, 0.4)

func _on_mcs_state_changed(is_active: bool) -> void:
	if is_active:
		status_label.text = "⬇ MCS SHUTDOWN ACTIVE"
		status_label.modulate = Color("#3B8BD4")

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

func _on_night_toggled(is_night: bool) -> void:
	# Update label waktu
	if is_night:
		night_label.text = "🌑 MALAM"
		night_label.modulate = Color("#3B8BD4")
		status_label.text = "🌑 NIGHT — INVERSION ACTIVE"
		status_label.modulate = Color("#3B8BD4")
	else:
		night_label.text = "☀ SIANG"
		night_label.modulate = Color("#EF9F27")
		status_label.text = "☀ DAY — COOLING ACTIVE"
		status_label.modulate = Color("#EF9F27")
	
	# Tween overlay — ini satu-satunya tween, tidak ada await
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	if is_night:
		tween.tween_property(night_overlay, "color", Color(0.04, 0.09, 0.16, 0.65), 3.0)
	else:
		tween.tween_property(night_overlay, "color", Color(0.04, 0.09, 0.16, 0.0), 3.0)

func _on_night_warning() -> void:
	# Flash status label merah sebagai peringatan
	status_label.text = "⚠ NIGHT IN 10s — PREPARE LASER"
	status_label.modulate = Color("#E8593C")
	
	# Flash efek — berkedip 3x
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(status_label, "modulate:a", 0.2, 0.3)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.3)
