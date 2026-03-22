extends CanvasLayer

# ============================================================
# PLAYER HUD
# ============================================================
@onready var hp_bar = %HPBar/ProgressBar
@onready var armor_bar = %ArmorBar/ProgressBar
@onready var armor_label = %ArmorBar/Label
@onready var radiation_warning = %RadiationWarning
@onready var cpu_warning_label = %CPUWarningLabel

# ============================================================
# REACTOR MONITOR
# ============================================================
@onready var reactor_monitor = %ReactorMonitor
@onready var temp_bar = %TempRow/ProgressBar
@onready var temp_value = %TempRow/ValueLabel
@onready var status_label = %TempRow/StatusLabel
@onready var pressure_bar = %PressureRow/ProgressBar
@onready var pressure_value = %PressureRow/ValueLabel
@onready var electricity_bar = %ElectricityRow/ProgressBar
@onready var electricity_value = %ElectricityRow/ValueLabel
@onready var flux_label = %FluxLabel
@onready var shield_bar = %ShieldRow/ProgressBar
@onready var shield_status = %ShieldRow/ShieldStatusLabel
@onready var ctrl_rad_label = %CtrlRadLabel
@onready var night_label = %NightLabel
@onready var timer_label = %TimerLabel

# ============================================================
# OVERLAYS
# ============================================================
@onready var night_overlay = $NightOverlay
@onready var blackout_overlay = $BlackoutOverlay
@onready var blackout_label = $BlackoutOverlay/BlackoutLabel

# Untuk hitung temperature fluctuation
var _last_temp: float = 0.0
var _temp_fluctuation: float = 0.0

func _ready() -> void:
	# Setup bar ranges
	hp_bar.max_value = 100.0
	armor_bar.max_value = 100.0
	temp_bar.max_value = GameManager.TEMP_MAX   
	pressure_bar.max_value = GameManager.PRESSURE_MAX 
	electricity_bar.max_value = GameManager.ELECTRICITY_TARGET
	shield_bar.max_value = 100.0

	# Sembunyikan monitor di awal
	reactor_monitor.visible = false
	night_overlay.color.a = 0.0
	blackout_overlay.color.a = 0.0
	blackout_label.text = ""
	cpu_warning_label.text = ""
	radiation_warning.text = ""

	# Koneksi sinyal
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.night_toggled.connect(_on_night_toggled)
	GameManager.night_warning.connect(_on_night_warning)
	GameManager.mcs_triggered.connect(_on_mcs_triggered)
	GameManager.mcs_blackout_started.connect(_on_blackout_started)
	GameManager.mcs_blackout_ended.connect(_on_blackout_ended)
	GameManager.mcs_stabilization_complete.connect(_on_mcs_complete)
	GameManager.mcs_damage_applied.connect(_on_mcs_damage)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)
	GameManager.startup_state_changed.connect(_on_startup_state_changed)
	GameManager.monitor_toggled.connect(_on_monitor_toggled)
	GameManager.crafting_completed.connect(_on_crafting_completed)
	GameManager.crafting_started.connect(_on_crafting_started)
	GameManager.room_changed.connect(_on_room_changed)
	GameManager.sysadmin_triggered.connect(_on_sysadmin_triggered)

func _process(delta: float) -> void:
	if GameManager.mcs_blackout_active:
		reactor_monitor.visible = false
		return

	_update_player_hud()

	# Monitor hanya visible di control room + monitor nyala
	var show_monitor = GameManager.current_room == "control_room" \
		and GameManager.monitor_on \
		and GameManager.startup_state == GameManager.StartupState.RUNNING
	reactor_monitor.visible = show_monitor

	if show_monitor:
		_update_reactor_monitor(delta)

# ============================================================
# PLAYER HUD UPDATE
# ============================================================
func _on_sysadmin_triggered() -> void:
	# Lock semua panel interaction
	GameManager.is_in_panel_mode = false
	# Tampilkan pesan di HUD
	status_label.text = "SYSTEM//ADMIN ACTIVE"
	status_label.modulate = Color("#E8593C")

func _update_player_hud() -> void:
	hp_bar.value = GameManager.player_hp
	armor_bar.value = GameManager.armor_hp

	# Armor label
	armor_label.text = "ARMOR 🛡" if GameManager.hazmat_equipped else "ARMOR"

	# Radiation warning
	if GameManager.grace_period_active:
		radiation_warning.text = "☢ ARMOR GONE — %.0fs" % GameManager.grace_timer
		radiation_warning.modulate = Color("#E8593C")
	elif not GameManager.hazmat_equipped \
		and GameManager.current_room == "reactor_room":
		radiation_warning.text = "⚠ NO HAZMAT — direct damage!"
		radiation_warning.modulate = Color("#E8593C")
	elif GameManager.hazmat_equipped and GameManager.armor_hp <= 20.0:
		radiation_warning.text = "⚠ ARMOR CRITICAL"
		radiation_warning.modulate = Color("#E8593C")
	else:
		radiation_warning.text = ""

	# CPU warning — pakai avg temp dari GameManager.cpu_temp
	var active_cpus = 0
	for broken in GameManager.cpu_broken_states:
		if not broken:
			active_cpus += 1
	
	if GameManager.input_delay > 0.0:
		cpu_warning_label.text = "⚡ CPU %.0f°C  [%d/4]  delay %.1fs" % [
			GameManager.cpu_temp,
			active_cpus,
			GameManager.input_delay
		]
		cpu_warning_label.modulate = Color("#E8593C") \
			if GameManager.input_delay > 1.5 else Color("#EF9F27")
	elif active_cpus < 4:
		cpu_warning_label.text = "⚠ CPU DEGRADED [%d/4 online]" % active_cpus
		cpu_warning_label.modulate = Color("#EF9F27")
	else:
		cpu_warning_label.text = ""

func _on_room_changed(new_room: String) -> void:
	_update_monitor_visibility()
	
	# Feedback ruangan di HUD sementara (bisa dihapus nanti)
	print("HUD: player now in ", new_room)

# ============================================================
# REACTOR MONITOR UPDATE
# ============================================================
func _update_reactor_monitor(delta: float) -> void:
	# Temperature
	temp_bar.value = GameManager.reactor_temp
	temp_value.text = "%.0f°C" % GameManager.reactor_temp

	# Temperature fluctuation
	_temp_fluctuation = (GameManager.reactor_temp - _last_temp) / delta
	_last_temp = GameManager.reactor_temp
	var flux_sign = "+" if _temp_fluctuation >= 0 else ""
	flux_label.text = "%s%.1f°C/s" % [flux_sign, _temp_fluctuation]
	flux_label.modulate = Color("#E8593C") if _temp_fluctuation > 2.0 \
		else Color("#3B9E7A") if _temp_fluctuation < -2.0 \
		else Color.WHITE

	# Pressure
	pressure_bar.value = GameManager.reactor_pressure
	pressure_value.text = "%.0f PSI" % GameManager.reactor_pressure

	# Electricity
	electricity_bar.value = GameManager.electricity_quota
	electricity_value.text = "%.0f / %.0f MW/h" % [
		GameManager.electricity_quota,
		GameManager.ELECTRICITY_TARGET
	]

	# Shield
	shield_bar.value = GameManager.control_room_shield
	if GameManager.control_room_shield < 40.0:
		shield_bar.modulate = Color("#E8593C")
		shield_status.text = "⚠ BREACH"
		shield_status.modulate = Color("#E8593C")
	elif GameManager.control_room_shield < 70.0:
		shield_bar.modulate = Color("#EF9F27")
		shield_status.text = "DEGRADED"
		shield_status.modulate = Color("#EF9F27")
	else:
		shield_bar.modulate = Color.WHITE
		shield_status.text = "NOMINAL"
		shield_status.modulate = Color("#3B9E7A")

	# Control room radiation
	var ctrl_radiation = 0.0
	if GameManager.control_room_shield < 40.0:
		var breach = (40.0 - GameManager.control_room_shield) / 40.0
		ctrl_radiation = GameManager.RADIATION_CONTROL * breach \
			* (GameManager.reactor_temp / GameManager.TEMP_MAX)
	ctrl_rad_label.text = "%.1f mSv/s" % ctrl_radiation
	ctrl_rad_label.modulate = Color("#E8593C") if ctrl_radiation > 1.0 \
		else Color("#EF9F27") if ctrl_radiation > 0.3 \
		else Color("#3B9E7A")

	# Night timer
	_update_timer()

	# Reactor status
	_update_status()

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
	var cycle_pos = fmod(GameManager.time_elapsed, GameManager.day_duration * 2)
	var time_to_next: float
	if cycle_pos < GameManager.day_duration:
		time_to_next = GameManager.day_duration - cycle_pos
		timer_label.text = "🌑 %.0fs" % time_to_next
		timer_label.modulate = Color("#888780")
	else:
		time_to_next = (GameManager.day_duration * 2) - cycle_pos
		timer_label.text = "☀ %.0fs" % time_to_next
		timer_label.modulate = Color("#EF9F27")

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_startup_state_changed(_state) -> void:
	_update_monitor_visibility()

func _on_monitor_toggled(_is_on: bool) -> void:
	_update_monitor_visibility()

func _update_monitor_visibility() -> void:
	var show = GameManager.current_room == "control_room" \
		and GameManager.monitor_on \
		and GameManager.startup_state == GameManager.StartupState.RUNNING
	reactor_monitor.visible = show
	if not show and GameManager.monitor_on:
		status_label.text = "MONITOR OFFLINE"
		status_label.modulate = Color("#888780")

func _on_night_toggled(is_night: bool) -> void:
	if is_night:
		night_label.text = "🌑 MALAM"
		night_label.modulate = Color("#3B8BD4")
	else:
		night_label.text = "☀ SIANG"
		night_label.modulate = Color("#EF9F27")
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	if is_night:
		tween.tween_property(night_overlay, "color",
			Color(0.04, 0.09, 0.16, 0.65), 3.0)
	else:
		tween.tween_property(night_overlay, "color",
			Color(0.04, 0.09, 0.16, 0.0), 3.0)

func _on_night_warning() -> void:
	if status_label:
		status_label.text = "⚠ NIGHT IN 10s — PREPARE LASER"
		status_label.modulate = Color("#3B8BD4")
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(status_label, "modulate:a", 0.2, 0.3)
		tween.tween_property(status_label, "modulate:a", 1.0, 0.3)

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
		"sysadmin": 
			status_label.text = "🏚 FACILITY COLLAPSED"
			status_label.modulate = Color("#E8593C")

func _on_mcs_triggered() -> void:
	blackout_label.text = "⚠ MCS ACTIVATED\nEMERGENCY SHUTDOWN INITIATED"
	blackout_label.modulate = Color("#E8593C")

func _on_blackout_started() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(blackout_overlay, "color:a", 1.0, 0.5)

func _on_blackout_ended() -> void:
	blackout_label.text = "SYSTEM REBOOTING...\nRESTORING CONNECTIVITY"
	blackout_label.modulate = Color("#EF9F27")
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(blackout_overlay, "color:a", 0.7, 2.0)
	tween.tween_property(blackout_overlay, "color:a", 0.0, 1.5)

func _on_mcs_complete() -> void:
	blackout_label.text = ""
	blackout_overlay.color.a = 0.0
	status_label.text = "■ COLD SHUTDOWN — MCS COMPLETE"
	status_label.modulate = Color("#888780")

func _on_mcs_damage(systems: Array) -> void:
	var damage_text = "⚠ DAMAGE REPORT:\n"
	for sys in systems:
		damage_text += "• %s\n" % sys
	blackout_label.text = damage_text
	blackout_label.modulate = Color("#E8593C")
	# Ganti await dengan timer yang tidak block
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func():
		blackout_label.text = ""
		blackout_overlay.color.a = 0.0
	)

func _on_mcs_state_changed(_is_active: bool) -> void:
	pass

func _on_crafting_started(item: String, duration: float) -> void:
	cpu_warning_label.text = "🔬 Crafting %s (%.0fs)" % [item, duration]
	cpu_warning_label.modulate = Color("#EF9F27")

func _on_crafting_completed(item: String) -> void:
	cpu_warning_label.text = "✓ %s ready!" % item
	cpu_warning_label.modulate = Color("#3B9E7A")
	await get_tree().create_timer(3.0).timeout
	cpu_warning_label.text = ""
