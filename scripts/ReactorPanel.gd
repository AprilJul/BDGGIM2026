extends Node2D

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var panel_ui = $PanelUI
@onready var area = $Area2D

@onready var extract_bar = %ExtractBar
@onready var stress_bar = %StressBar
@onready var btn_extract_up = %BtnExtractUp
@onready var btn_extract_down = %BtnExtractDown
@onready var btn_restart = %BtnRestart

@onready var btn_lights = %BtnLights
@onready var btn_monitor = %BtnMonitor
@onready var btn_extractor_online = %BtnExtractorOnline
@onready var lights_status = %LightsStatus
@onready var monitor_status = %MonitorStatus
@onready var extractor_online_status = %ExtractorOnlineStatus
@onready var check_coolant = %CheckCoolant
@onready var check_cpu = %CheckCPU
@onready var check_extractor = %CheckExtractor
@onready var btn_start_reactor = %BtnStartReactor
@onready var startup_status_label = %StartupStatusLabel

var is_open: bool = false
const EXTRACT_STEP: float = 10.0

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	panel_ui.visible = false
	area.add_to_group("interaction_panel")
	print("ReactorPanel ready, area group: ", area.get_groups())

	# Hubungkan tombol
	btn_extract_up.pressed.connect(_on_extract_up)
	btn_extract_down.pressed.connect(_on_extract_down)
	btn_lights.pressed.connect(_on_lights)
	btn_monitor.pressed.connect(_on_monitor)
	btn_extractor_online.pressed.connect(_on_extractor_online)
	btn_start_reactor.pressed.connect(_on_start_reactor)
	btn_restart.pressed.connect(_on_start_reactor)

	# Hubungkan sinyal GameManager
	GameManager.reactor_state_changed.connect(_on_reactor_state_changed)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_restart.visible = false
	GameManager.startup_state_changed.connect(_on_startup_state_changed)
	GameManager.startup_check_result.connect(_on_startup_check_result)
	GameManager.lights_toggled.connect(_on_lights_toggled)
	GameManager.monitor_toggled.connect(_on_monitor_toggled)
	GameManager.startup_phase_changed.connect(_on_startup_phase_changed)
	GameManager.startup_check_step_updated.connect(_on_check_step_updated)

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
	_update_startup_ui()
	btn_restart.visible = GameManager.reactor_shutdown
	var is_running = GameManager.startup_state == GameManager.StartupState.RUNNING

	# Disable semua kontrol saat shutdown
	var locked = not is_running or GameManager.mcs_active or GameManager.reactor_shutdown
	btn_extract_up.disabled = locked or GameManager.extractor_broken
	btn_extract_down.disabled = locked
	
		# Flick mouse ke bawah = tutup panel
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()
	
	if not is_running:
		return

	# Update bar sesuai nilai GameManager
	extract_bar.value = GameManager.extraction_level
	stress_bar.value = GameManager.extraction_stress

	# Update warna stress bar
	if GameManager.extraction_stress > 75.0:
		stress_bar.modulate = Color("#E8593C")
	elif GameManager.extraction_stress > 50.0:
		stress_bar.modulate = Color("#EF9F27")
	else:
		stress_bar.modulate = Color.WHITE

	# Disable tombol extract kalau extractor rusak
	btn_extract_up.disabled = GameManager.extractor_broken
	btn_extract_down.disabled = GameManager.extractor_broken

# ============================================================
# BUTTON HANDLERS — pakai input delay dari CPU temp!
# ============================================================

func _on_startup_phase_changed(phase: int, has_warning: bool) -> void:
	# Update status label sesuai phase
	match phase:
		GameManager.StartupPhase.SYSTEM_ONLINE:
			startup_status_label.text = "System. Online."
			startup_status_label.modulate = Color("#3B9E7A")
		GameManager.StartupPhase.INITIATING:
			startup_status_label.text = "Initiating startup sequences..."
			startup_status_label.modulate = Color("#EF9F27")
		GameManager.StartupPhase.CHECK_COOLANT:
			if has_warning:
				startup_status_label.text = "Coolant check... ⚠ WARNING"
				startup_status_label.modulate = Color("#E8593C")
			else:
				startup_status_label.text = "Coolant 1. Check. 2. Check. 3. Check."
				startup_status_label.modulate = Color("#3B9E7A")
		GameManager.StartupPhase.CHECK_LASER:
			startup_status_label.text = "Laser 1. Check. 2. Check. 3. Check."
			startup_status_label.modulate = Color("#3B9E7A")
		GameManager.StartupPhase.CHECK_EXTRACTOR:
			if has_warning:
				startup_status_label.text = "Extractor system... ⚠ OFFLINE"
				startup_status_label.modulate = Color("#E8593C")
			else:
				startup_status_label.text = "Extractor system. Online."
				startup_status_label.modulate = Color("#3B9E7A")
		GameManager.StartupPhase.CONNECTING:
			startup_status_label.text = "Connecting Control Room to Reactor Vessel..."
			startup_status_label.modulate = Color("#EF9F27")
		GameManager.StartupPhase.WARNING_EVACUATE:
			startup_status_label.text = "⚠ WARNING. All personnel evacuate Reactor Room."
			startup_status_label.modulate = Color("#E8593C")
			# Flash effect
			_flash_label(startup_status_label)
		GameManager.StartupPhase.ENGAGING:
			startup_status_label.text = "Now engaging Reactor startup..."
			startup_status_label.modulate = Color("#EF9F27")
		GameManager.StartupPhase.COUNTDOWN:
			# Countdown ditangani _update_startup_ui
			startup_status_label.modulate = Color("#EF9F27")
		GameManager.StartupPhase.GLITCH:
			startup_status_label.text = "S̷Y̷S̷T̷E̷M̷ G̷L̷I̷T̷C̷H̷..."
			startup_status_label.modulate = Color("#E8593C")
			_flash_label(startup_status_label)
		GameManager.StartupPhase.COMPLETE:
			startup_status_label.text = "● REACTOR ONLINE"
			startup_status_label.modulate = Color("#3B9E7A")

func _on_check_step_updated(is_laser: bool, step: int) -> void:
	# Build teks progressif
	var prefix = "Laser" if is_laser else "Coolant"
	var text = prefix
	
	for i in range(1, step + 1):
		if i < step:
			# Step sebelumnya sudah complete
			text += " %d. Check." % i
		else:
			# Step terakhir yang baru muncul — flash efek
			text += " %d. Check." % i
	
	startup_status_label.text = text
	startup_status_label.modulate = Color("#3B9E7A")
	
	# Flash singkat tiap check baru muncul
	var tween = create_tween()
	tween.tween_property(startup_status_label, "modulate:a", 0.2, 0.05)
	tween.tween_property(startup_status_label, "modulate:a", 1.0, 0.1)

func _flash_label(label: Label) -> void:
	var tween = create_tween()
	tween.set_loops(4)
	tween.tween_property(label, "modulate:a", 0.1, 0.15)
	tween.tween_property(label, "modulate:a", 1.0, 0.15)

func _update_startup_ui() -> void:
	var is_running = GameManager.startup_state == GameManager.StartupState.RUNNING
	var is_starting = GameManager.startup_state == GameManager.StartupState.STARTING
	var phase = GameManager.startup_phase
	var state = GameManager.startup_state
	var is_shutdown = GameManager.reactor_shutdown

	btn_extractor_online.disabled = is_running or is_starting
	btn_start_reactor.visible = not is_shutdown and not is_running
	%BtnRestart.visible = is_shutdown and not is_running and not is_starting

	# Tombol startup di-disable saat reactor sudah running
	var reactor_running = GameManager.startup_state == GameManager.StartupState.RUNNING
	btn_lights.disabled = reactor_running or is_starting
	btn_monitor.disabled = reactor_running or is_starting or not GameManager.lights_on
	btn_extractor_online.disabled = reactor_running or is_starting
	btn_start_reactor.disabled = reactor_running or \
		not GameManager.lights_on or \
		not GameManager.monitor_on or \
		is_starting

	# Sembunyikan tombol restart kalau belum shutdown
	%BtnRestart.visible = GameManager.reactor_shutdown

	# Lights
	if GameManager.lights_on:
		btn_lights.text = "LIGHTS ON"
		btn_lights.modulate = Color("#EF9F27")
		lights_status.text = "● ON"
		lights_status.modulate = Color("#EF9F27")
	else:
		btn_lights.text = "LIGHTS OFF"
		btn_lights.modulate = Color.WHITE
		lights_status.text = "○ OFF"
		lights_status.modulate = Color("#888780")

	# Monitor
	btn_monitor.disabled = not GameManager.lights_on
	if GameManager.monitor_on:
		btn_monitor.text = "MONITOR ON"
		btn_monitor.modulate = Color("#3B9E7A")
		monitor_status.text = "● ON"
		monitor_status.modulate = Color("#3B9E7A")
	else:
		btn_monitor.text = "MONITOR OFF"
		btn_monitor.modulate = Color.WHITE
		monitor_status.text = "○ OFF"
		monitor_status.modulate = Color("#888780")

	# Extractor online toggle
	if GameManager.extractor_online:
		btn_extractor_online.text = "EXTRACTOR ONLINE"
		btn_extractor_online.modulate = Color("#3B9E7A")
		extractor_online_status.text = "● ONLINE"
		extractor_online_status.modulate = Color("#3B9E7A")
	else:
		btn_extractor_online.text = "EXTRACTOR OFFLINE"
		btn_extractor_online.modulate = Color.WHITE
		extractor_online_status.text = "○ OFFLINE"
		extractor_online_status.modulate = Color("#888780")

	# Start button
	var can_start = GameManager.lights_on and \
		GameManager.monitor_on and \
		not is_starting and \
		not is_running
	btn_start_reactor.disabled = not can_start
	%BtnRestart.disabled = not can_start

	# Status label — HANYA countdown yang di-update tiap frame
	# Phase lain dihandle signal _on_startup_phase_changed
	if phase == GameManager.StartupPhase.COUNTDOWN:
		var seconds_left = ceil(GameManager.startup_phase_timer)
		startup_status_label.text = "Reactor engaging in %d..." % seconds_left
	elif state == GameManager.StartupState.OFFLINE:
		startup_status_label.text = "REACTOR OFFLINE"
		startup_status_label.modulate = Color("#888780")

	# Progress bar
	if is_starting:
		%StartupProgressBar.visible = true
		%StartupProgressBar.value = GameManager.startup_total_elapsed / GameManager.STARTUP_TOTAL_DURATION
	elif is_running:
		%StartupProgressBar.visible = true
		%StartupProgressBar.value = 1.0
	else:
		%StartupProgressBar.visible = false

	# Check results — muncul bertahap sesuai phase
	if phase > GameManager.StartupPhase.CHECK_COOLANT or is_running:
		check_coolant.text = "COOLANT: %s" % ("OK ✓" if GameManager.startup_coolant_ok else "WARN ⚠")
		check_coolant.modulate = Color("#3B9E7A") if GameManager.startup_coolant_ok else Color("#E8593C")
	else:
		check_coolant.text = "COOLANT: —"
		check_coolant.modulate = Color("#888780")

	if phase > GameManager.StartupPhase.CHECK_LASER or is_running:
		check_cpu.text = "LASER: OK ✓"
		check_cpu.modulate = Color("#3B9E7A")
	else:
		check_cpu.text = "LASER: —"
		check_cpu.modulate = Color("#888780")

	if phase > GameManager.StartupPhase.CHECK_EXTRACTOR or is_running:
		check_extractor.text = "EXTRACTOR: %s" % ("OK ✓" if GameManager.startup_extractor_ok else "WARN ⚠")
		check_extractor.modulate = Color("#3B9E7A") if GameManager.startup_extractor_ok else Color("#E8593C")
	else:
		check_extractor.text = "EXTRACTOR: —"
		check_extractor.modulate = Color("#888780")

func _get_remaining_startup_time() -> float:
	# Hitung sisa waktu dari phase sekarang ke akhir
	var remaining = GameManager.startup_phase_timer
	var phase_int = GameManager.startup_phase
	# Tambah semua phase setelah phase sekarang
	for i in range(phase_int + 1, GameManager.StartupPhase.COMPLETE + 1):
		remaining += GameManager.PHASE_DURATIONS.get(i, 0.0)
	return remaining

# Button handlers baru
func _on_lights() -> void:
	GameManager.toggle_lights()

func _on_monitor() -> void:
	GameManager.toggle_monitor()

func _on_extractor_online() -> void:
	GameManager.toggle_extractor_online()

func _on_start_reactor() -> void:
	if GameManager.reactor_shutdown:
		# Post-MCS restart — reset shutdown state
		GameManager.reactor_shutdown = false
		GameManager.mcs_active = false
	GameManager.start_reactor()

func _on_startup_state_changed(new_state) -> void:
	if new_state == GameManager.StartupState.RUNNING:
		startup_status_label.text = "● REACTOR ONLINE"
		startup_status_label.modulate = Color("#3B9E7A")

func _on_startup_check_result(coolant_ok: bool, cpu_ok: bool, extractor_ok: bool) -> void:
	if not coolant_ok:
		startup_status_label.text = "⚠ WARNING: Coolant not ready!"
		startup_status_label.modulate = Color("#E8593C")
	elif not extractor_ok:
		startup_status_label.text = "⚠ WARNING: Extractor offline!"
		startup_status_label.modulate = Color("#EF9F27")

func _on_lights_toggled(is_on: bool) -> void:
	print("Lights: ", is_on)

func _on_monitor_toggled(is_on: bool) -> void:
	print("Monitor: ", is_on)

func _on_extract_up() -> void:
	if GameManager.extractor_broken:
		return
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_extraction(GameManager.extraction_level + EXTRACT_STEP)

func _on_extract_down() -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.set_extraction(GameManager.extraction_level - EXTRACT_STEP)

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

func _on_mcs_state_changed(is_active: bool) -> void:
	btn_extract_up.disabled = is_active
	btn_extract_down.disabled = is_active

func _on_restart_pressed() -> void:
	GameManager.restart_reactor()
	btn_restart.visible = false
