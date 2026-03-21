extends Node

# ============================================================
# STARTUP SYSTEM
# ============================================================
enum StartupState {
	OFFLINE,        # reactor mati total
	PRE_STARTUP,    # player sedang persiapan
	STARTING,       # reactor sedang startup (animasi 5 detik)
	RUNNING,        # reactor berjalan normal
	SHUTDOWN        # post-MCS shutdown
}

enum StartupPhase {
	IDLE,
	SYSTEM_ONLINE,
	INITIATING,
	CHECK_COOLANT,
	CHECK_LASER,
	CHECK_EXTRACTOR,
	CONNECTING,
	WARNING_EVACUATE,
	ENGAGING,
	COUNTDOWN,
	GLITCH,
	COMPLETE
}

const PHASE_DURATIONS = {
	StartupPhase.SYSTEM_ONLINE:      2.0,
	StartupPhase.INITIATING:         2.0,
	StartupPhase.CHECK_COOLANT:      4.0,
	StartupPhase.CHECK_LASER:        4.0,
	StartupPhase.CHECK_EXTRACTOR:    2.0,
	StartupPhase.CONNECTING:         3.0,
	StartupPhase.WARNING_EVACUATE:   3.0,
	StartupPhase.ENGAGING:           2.0,
	StartupPhase.COUNTDOWN:          5.0,
	StartupPhase.GLITCH:             1.0,
	StartupPhase.COMPLETE:           0.0
}

var startup_total_elapsed: float = 0.0
const STARTUP_TOTAL_DURATION: float = 28.0  # total semua phase
var startup_state: StartupState = StartupState.OFFLINE
var startup_phase: StartupPhase = StartupPhase.IDLE
var startup_phase_timer: float = 0.0
var lights_on: bool = false
var monitor_on: bool = false
var extractor_online: bool = false  # berbeda dari extractor_broken
var startup_check_done: bool = false
var startup_check_step: int = 0      # 0, 1, 2, 3 (0=belum, 1-3=step check)
var startup_check_step_timer: float = 0.0
const STARTUP_CHECK_STEP_DELAY: float = 1.0   # delay antar check

# Startup check results
var startup_coolant_ok: bool = false
var startup_cpu_ok: bool = false
var startup_extractor_ok: bool = false

# Startup animation timer
var startup_timer: float = 0.0
const STARTUP_DURATION: float = 5.0

signal startup_state_changed(new_state: StartupState)
signal startup_phase_changed(phase: StartupPhase, has_warning: bool)
signal startup_check_step_updated(is_laser: bool, step: int)
signal startup_check_result(coolant_ok: bool, cpu_ok: bool, extractor_ok: bool)
signal lights_toggled(is_on: bool)
signal monitor_toggled(is_on: bool)

# ============================================================
# REACTOR VARIABLES — unit realistis
# ============================================================
var reactor_temp: float = 20.0        # dingin saat mati
var reactor_pressure: float = 100.0   # pressure rendah

# Batas bahaya
const TEMP_MAX: float = 350.0
const TEMP_MIN: float = 0.0
const TEMP_OPTIMAL_LOW: float = 150.0
const TEMP_OPTIMAL_HIGH: float = 250.0
const TEMP_WARNING: float = 245.0     # 70% dari 350
const TEMP_CRITICAL: float = 298.0    # 85% dari 350
const TEMP_MELTDOWN: float = 333.0    # 95% dari 350
const TEMP_SUBZERO: float = 35.0      # 10% dari 350

const PRESSURE_MAX: float = 2200.0
const PRESSURE_WARNING: float = 1760.0  # 80% dari 2200

# ============================================================
# ELECTRICITY — unit MW/h
# ============================================================
var electricity_output: float = 0.0
var electricity_quota: float = 0.0
var extraction_level: float = 0.0
var extraction_stress: float = 0.0

const ELECTRICITY_TARGET: float = 1000.0

# ============================================================
# PLAYER
# ============================================================
var player_hp: float = 100.0
var armor_hp: float = 0.0
var current_room: String = "control_room"

# ============================================================
# HAZMAT & ARMOR
# ============================================================
var hazmat_equipped: bool = false
var armor_repairing: bool = false
var armor_repair_timer: float = 0.0
const ARMOR_REPAIR_DURATION: float = 8.0   # detik

# Hazmat suit mengurangi radiation damage
const HAZMAT_RADIATION_REDUCTION: float = 0.6  # 60% damage reduction

signal armor_repair_completed
signal hazmat_toggled(equipped: bool)

# ============================================================
# SYSTEMS
# ============================================================
var extractor_durability: float = 100.0
var coolant_pump_durability: float = 100.0

var cpu_module_installed: bool = true   # false kalau module dicabut/rusak
var cpu_broken: bool = false

signal cpu_overheat_warning(temp: float, delay: float)
signal cpu_module_replaced

# ============================================================
# LASER SYSTEM — 3 laser independen
# ============================================================
var laser_intensities: Array = [0.0, 0.0, 0.0]   # intensitas tiap laser 0-100%
var laser_stresses: Array = [0.0, 0.0, 0.0]       # stress tiap laser 0-100%
var laser_broken_states: Array = [false, false, false]  # status rusak tiap laser
var laser_durabilities: Array = [100.0, 100.0, 100.0]  # durability tiap laser

const LASER_COUNT: int = 3

# ============================================================
# VENTILATION SYSTEM — 4 vent independen
# ============================================================
var vent_states: Array = [false, false, false, false]  # vent 1-4
const VENT_COUNT: int = 4

# Efektivitas vent berbanding terbalik dengan pressure
# Di bawah 1000 PSI → bisa nurunin pressure
# Di atas 1800 PSI → hanya memperlambat kenaikan
const VENT_EFFECTIVE_THRESHOLD: float = 800.0
const VENT_INEFFECTIVE_THRESHOLD: float = 1600.0
const VENT_BASE_REDUCTION: float = 12.0    # PSI/s per vent aktif
const VENT_PRESSURE_CONTRIBUTION: float = 25.0  # PSI/s dari laser ke pressure

var cpu_temp: float = 20.0
var input_delay: float = 0.0          # detik — Tweak 1

# ECCS
var eccs_charges: int = 3
var eccs_active: bool = false         # sedang mendinginkan
var eccs_cooldown: float = 0.0
const ECCS_COOLING_RATE: float = 30.0  # °C/s saat aktif
const ECCS_COOLING_DURATION: float = 8.0  # detik aktif mendinginkan
var eccs_cooling_timer: float = 0.0
const ECCS_COOLDOWN_TIME: float = 10.0

# Emergency Vent
var emergency_vent_active: bool = false
var emergency_vent_cooldown: float = 0.0
const EMERGENCY_VENT_COOLDOWN: float = 120.0
const EMERGENCY_VENT_RATE: float = 450.0   # PSI/s saat aktif
const EMERGENCY_VENT_DURATION: float = 8.0  # detik aktif
var emergency_vent_timer: float = 0.0

# MCS — fully automatic
var mcs_active: bool = false
var mcs_broken: bool = false
var mcs_used_count: int = 0
var mcs_blackout_timer: float = 0.0
const MCS_BLACKOUT_DURATION: float = 10.0
var mcs_blackout_active: bool = false
var mcs_stabilizing: bool = false    # fase stabilisasi setelah blackout

signal mcs_triggered
signal mcs_blackout_started
signal mcs_blackout_ended
signal mcs_stabilization_complete

# ============================================================
# COOLANT SYSTEM
# ============================================================
var coolant_active: bool = false
var coolant_storage: float = 800.0      # unit storage, bukan persen
const COOLANT_STORAGE_MAX: float = 800.0

# RPM: 0 = off, 1 = low, 2 = medium, 3 = high
var coolant_rpm: int = 0

# Placeholder values — bisa diatur saat balancing
const COOLANT_EFFECT_LOW: float = 8.0      # °C/s
const COOLANT_EFFECT_MED: float = 18.0     # °C/s
const COOLANT_EFFECT_HIGH: float = 32.0    # °C/s

const COOLANT_DRAIN_LOW: float = 3.0       # storage/s
const COOLANT_DRAIN_MED: float = 8.0       # storage/s
const COOLANT_DRAIN_HIGH: float = 18.0     # storage/s

# Pump health
var coolant_pump_hp: float = 100.0
const PUMP_DAMAGE_CHANCE_HIGH: float = 0.002  # per detik saat high RPM
var coolant_pump_broken: bool = false

# ============================================================
# RADIATION & ARMOR SYSTEM
# ============================================================
var control_room_shield: float = 100.0   # 0-100%, kalau < 40% radiasi tembus
var grace_period_active: bool = false
var grace_timer: float = 0.0
const GRACE_PERIOD_DURATION: float = 10.0

# Radiation level per ruangan (0-100%)
const RADIATION_REACTOR: float = 8.0    # per detik, dikali reactor_temp ratio
const RADIATION_CONTROL: float = 3.0    # per detik, hanya kalau shield < 40%

# ============================================================
# MEDBAY SYSTEM
# ============================================================
var medbay_cooldown: float = 0.0
const MEDBAY_COOLDOWN_TIME: float = 60.0  # 1 menit cooldown

signal medbay_used

func use_medbay() -> void:
	if medbay_cooldown > 0.0:
		print("Medbay masih cooldown!")
		return
	if player_hp >= 100.0:
		print("HP sudah penuh!")
		return
	player_hp = 100.0
	medbay_cooldown = MEDBAY_COOLDOWN_TIME
	emit_signal("medbay_used")
	print("Medbay used — HP restored!")

func _update_medbay(delta: float) -> void:
	if medbay_cooldown > 0.0:
		medbay_cooldown -= delta
		medbay_cooldown = clamp(medbay_cooldown, 0.0, MEDBAY_COOLDOWN_TIME)

# ============================================================
# CRAFTING SYSTEM
# ============================================================
# Inventory item yang sudah di-craft
var inv_extractor_part: int = 0
var inv_mcs_module: int = 0
var inv_coolant_kit: int = 0
var inv_cpu_module: int = 0
var inv_armor_patch: int = 0

# Crafting queue — hanya 1 item bisa di-craft sekaligus
var crafting_item: String = ""       # nama item yang sedang di-craft
var crafting_timer: float = 0.0
var crafting_duration: float = 0.0

# Durasi craft tiap item (detik) — bisa diatur saat balancing
const CRAFT_TIME_EXTRACTOR: float = 15.0
const CRAFT_TIME_MCS: float = 25.0
const CRAFT_TIME_COOLANT_KIT: float = 10.0
const CRAFT_TIME_CPU: float = 20.0
const CRAFT_TIME_ARMOR_PATCH: float = 12.0

signal crafting_started(item: String, duration: float)
signal crafting_completed(item: String)
signal crafting_cancelled(item: String)

# ============================================================
# TIME
# ============================================================
var is_night: bool = false
var time_elapsed: float = 0.0
var day_duration: float = 180       # 5 menit = siang
var _night_warning_sent: bool = false

# ============================================================
# STATE
# ============================================================
var reactor_state: int = 0            # -1, 0, 1, 2, 3, 4
var game_over: bool = false
var extractor_broken: bool = false
var is_in_panel_mode: bool = false
var reactor_shutdown: bool = false
var stat_time_survived: float = 0.0
var stat_max_temp: float = 0.0
var stat_max_pressure: float = 0.0
var stat_eccs_used: int = 0
var stat_mcs_used: int = 0
var stat_night_survived: int = 0 

# Sinyal untuk memberi tahu UI
signal reactor_state_changed(new_state: int)
signal game_ended(reason: String)
signal night_toggled(is_night: bool)
signal mcs_state_changed(is_active: bool)
signal night_warning
signal grace_period_started
signal control_room_breached(shield_level: float)
signal coolant_pump_damaged

# ============================================================
# SYSTEM//ADMIN SEQUENCE
# ============================================================
var sysadmin_active: bool = false
var sysadmin_timer: float = 0.0
const SYSADMIN_DURATION: float = 30.0
var sysadmin_phase: String = ""  # "takeover", "countdown", "collapse"

signal sysadmin_triggered
signal sysadmin_countdown_tick(seconds_left: float)
signal sysadmin_collapse  # player mati tertimpa fasilitas

# ============================================================
# GAME LOOP
# ============================================================
func _process(delta: float) -> void:
	if game_over:
		return
		
	_update_sysadmin(delta)	
	time_elapsed += delta
	stat_time_survived = time_elapsed
	if reactor_temp > stat_max_temp:
		stat_max_temp = reactor_temp
	if reactor_pressure > stat_max_pressure:
		stat_max_pressure = reactor_pressure
		time_elapsed += delta

	_update_startup(delta)    # selalu jalan

	# Semua sistem reaktor hanya jalan saat RUNNING
	if startup_state != StartupState.RUNNING:
		return

	time_elapsed += delta
	_update_day_night_cycle()
	_update_reactor(delta)
	_update_vent(delta)
	_update_eccs(delta)    
	_update_emergency_vent(delta)    
	_update_mcs(delta)
	_update_medbay(delta)
	_check_mcs_trigger()
	_update_cpu(delta)
	_update_sysadmin(delta)
	_update_coolant(delta)
	_update_crafting(delta)
	_update_armor_repair(delta) 
	_update_control_room_shield(delta)
	_update_armor(delta)
	_check_win_lose()

func _update_day_night_cycle() -> void:
	var was_night = is_night
	var cycle_pos = fmod(time_elapsed, day_duration * 2)
	is_night = cycle_pos >= day_duration
	
	# Warning 10 detik sebelum malam
	var time_to_night = day_duration - cycle_pos
	if not is_night and time_to_night <= 10.0 and not _night_warning_sent:
		_night_warning_sent = true
		emit_signal("night_warning")
	elif is_night:
		_night_warning_sent = false   # reset untuk siklus berikutnya
	
	if is_night != was_night:
		emit_signal("night_toggled", is_night)

func _update_reactor(delta: float) -> void:
	if reactor_shutdown:
		reactor_temp = move_toward(reactor_temp, 20.0, 3.0 * delta)
		reactor_pressure = move_toward(reactor_pressure, 100.0, 50.0 * delta)
		return

	if GameManager.mcs_stabilizing or GameManager.mcs_blackout_active:
		return

	var total_laser = get_total_laser_intensity()
	var ambient_modifier: float = -3.0 if not is_night else 12.0

	# Laser → suhu naik
	reactor_temp += total_laser * 0.5 * delta
	reactor_temp += ambient_modifier * delta

	# Laser → pressure naik
	reactor_pressure += (total_laser / 100.0) * VENT_PRESSURE_CONTRIBUTION * delta

	# Extraction → pressure naik
	var temp_ratio = (reactor_temp - 100.0) / TEMP_MAX
	var extract_pressure = (extraction_level / 100.0) * 35.0
	reactor_pressure += (temp_ratio * 55.0 + extract_pressure) * delta

	# Update tiap laser stress independen
	_update_laser_stresses(delta)

	# Extraction stress
	if not extractor_broken:
		var ext_durability_mult = 2.0 - (extractor_durability / 100.0)
		if extraction_level > 20.0:
			extraction_stress += extraction_level * 0.015 * ext_durability_mult * delta
		elif extraction_level <= 10.0:
			extraction_stress -= 2.0 * delta
		else:
			extraction_stress -= 0.8 * delta
		extraction_stress = clamp(extraction_stress, 0.0, 100.0)
		if extraction_stress >= 100.0:
			extractor_broken = true
			electricity_output = 0.0

	if not extractor_broken:
		electricity_output = extraction_level * 15.0
		electricity_quota += electricity_output * delta * 0.01

	reactor_temp = clamp(reactor_temp, 0.0, TEMP_MAX)
	reactor_pressure = clamp(reactor_pressure, 0.0, PRESSURE_MAX)
	electricity_quota = clamp(electricity_quota, 0.0, ELECTRICITY_TARGET)
	extraction_stress = clamp(extraction_stress, 0.0, 100.0)

	_update_reactor_state()

func _update_reactor_state() -> void:
	var old_state = reactor_state
	if reactor_temp < TEMP_SUBZERO:
		reactor_state = -1
	elif reactor_temp < TEMP_WARNING:
		reactor_state = 1
	elif reactor_temp < TEMP_CRITICAL:
		reactor_state = 2
	elif reactor_temp < TEMP_MELTDOWN:
		reactor_state = 3
	else:
		reactor_state = 4
		extraction_stress = 100.0

	if reactor_state != old_state:
		emit_signal("reactor_state_changed", reactor_state)

func restart_reactor() -> void:
	if not reactor_shutdown:
		return
	reactor_shutdown = false
	reactor_temp = 80.0       # startup dari cold
	reactor_pressure = 400.0
	reactor_state = 0         # kembali ke startup state
	print("Reactor manually restarted")
	emit_signal("reactor_state_changed", reactor_state)

func _update_laser_stresses(delta: float) -> void:
	for i in range(LASER_COUNT):
		if laser_broken_states[i]:
			# Rusak — stress turun sendiri perlahan
			laser_stresses[i] -= 0.5 * delta
			laser_stresses[i] = clamp(laser_stresses[i], 0.0, 100.0)
			if laser_stresses[i] <= 0.0:
				laser_broken_states[i] = false
			continue
		
		var intensity = laser_intensities[i]
		var durability_mult = 2.0 - (laser_durabilities[i] / 100.0)
		
		if intensity > 20.0:
			laser_stresses[i] += (intensity / 100.0) * 1.2 * durability_mult * delta
		elif intensity <= 10.0:
			laser_stresses[i] -= 1.5 * delta
		else:
			laser_stresses[i] -= 0.6 * delta
		
		laser_stresses[i] = clamp(laser_stresses[i], 0.0, 100.0)
		
		if laser_stresses[i] >= 100.0:
			laser_broken_states[i] = true
			laser_intensities[i] = 0.0
			emit_signal("laser_broken", i)

signal laser_broken(index: int)

func repair_laser(index: int) -> void:
	if index < 0 or index >= LASER_COUNT:
		return
	laser_broken_states[index] = false
	laser_stresses[index] = 0.0
	laser_durabilities[index] = 100.0
	print("Laser %d repaired!" % (index + 1))

func _update_control_room_shield(delta: float) -> void:
	var old_shield = control_room_shield
	var temp_ratio = reactor_temp / TEMP_MAX
	
	# Shield terkikis saat reaktor panas
	if reactor_state >= 3:
		# State critical/meltdown — shield terkikis lebih cepat
		control_room_shield -= temp_ratio * 2.8 * delta
	elif reactor_state == 2:
		# State warning — terkikis pelan
		control_room_shield -= temp_ratio * 1.0 * delta
	else:
		# Reaktor normal — shield recover pelan
		control_room_shield = min(control_room_shield + 1.0 * delta, 100.0)
	
	control_room_shield = clamp(control_room_shield, 0.0, 100.0)
	if old_shield >= 40.0 and control_room_shield < 40.0:
		emit_signal("control_room_breached", control_room_shield)

func _update_cpu(delta: float) -> void:
	if startup_state != StartupState.RUNNING:
		return
	
	# CPU memanas karena control room aktif dipakai
	# Makin lama game berjalan + makin dekat kuota, makin panas
	var time_pressure = time_elapsed / (day_duration * 2)  # 0-1 seiring waktu
	var quota_pressure = electricity_quota / ELECTRICITY_TARGET  # 0-1 seiring kuota
	
	# CPU mulai memanas signifikan setelah quota > 60%
	var heat_multiplier = 0.0
	if quota_pressure > 0.5:
		# Makin dekat 100%, makin cepat panas
		heat_multiplier = (quota_pressure - 0.5) / 0.5  # 0-1
	
	# Base heat dari pemakaian normal (sangat lambat)
	var base_heat = 0.5 * delta
	
	# Heat tambahan dari quota pressure
	var quota_heat = heat_multiplier * 4.0 * delta
	
	cpu_temp += base_heat + quota_heat
	cpu_temp = clamp(cpu_temp, 20.0, 100.0)
	
	# CPU mendingin sedikit kalau player tidak di control room
	if current_room != "control_room":
		cpu_temp -= 0.5 * delta
		cpu_temp = clamp(cpu_temp, 20.0, 100.0)
	
	# Input delay HANYA mulai terasa saat cpu_temp > 65
	# Di bawah 65 = tidak ada delay sama sekali
	if cpu_temp < 65.0:
		input_delay = 0.0
	else:
		# Delay naik dari 0 sampai max 2.5 detik
		var delay_ratio = (cpu_temp - 65.0) / 35.0  # 0-1
		input_delay = delay_ratio * 2.5
	
	# Update cpu_temp di HUD — emit signal kalau perlu
	if cpu_temp > 80.0 and input_delay > 0.5:
		emit_signal("cpu_overheat_warning", cpu_temp, input_delay)

func replace_cpu_module() -> void:
	if inv_cpu_module <= 0:
		print("Tidak ada CPU module!")
		return
	inv_cpu_module -= 1
	cpu_temp = 20.0
	input_delay = 0.0
	cpu_broken = false
	cpu_module_installed = true
	emit_signal("cpu_module_replaced")
	print("CPU module replaced!")

func _update_armor(delta: float) -> void:
	if not hazmat_equipped:
		if current_room == "reactor_room":
			var temp_ratio = reactor_temp / TEMP_MAX
			player_hp -= RADIATION_REACTOR * temp_ratio * 0.3 * delta
			player_hp = clamp(player_hp, 0.0, 100.0)
		return
	
	var radiation_damage = _get_radiation_damage()
	
	if radiation_damage <= 0.0:
		# HAPUS baris armor recover — armor tidak auto-recover
		grace_period_active = false
		grace_timer = 0.0
		return
	
	armor_hp -= radiation_damage * delta
	armor_hp = clamp(armor_hp, 0.0, 100.0)
	
	if armor_hp <= 0.0:
		_handle_no_armor(delta)

func _get_radiation_damage() -> float:
	var temp_ratio = reactor_temp / TEMP_MAX
	var reduction = HAZMAT_RADIATION_REDUCTION if hazmat_equipped else 1.0
	
	match current_room:
		"reactor_room":
			return RADIATION_REACTOR * temp_ratio * reduction
		"control_room":
			if control_room_shield < 40.0:
				var breach_ratio = (40.0 - control_room_shield) / 40.0
				return RADIATION_CONTROL * breach_ratio * temp_ratio * reduction
			return 0.0
		_:
			return 0.0

func _handle_no_armor(delta: float) -> void:
	if not grace_period_active:
		grace_period_active = true
		grace_timer = GRACE_PERIOD_DURATION
		emit_signal("grace_period_started")
		print("ARMOR GONE — grace period started!")
	
	# Hitung mundur grace period
	grace_timer -= delta
	
	if grace_timer > 0.0:
		grace_timer -= delta
		grace_timer = max(grace_timer, 0.0)   # ← clamp ke 0
		return   # ← selama masih ada grace, HP aman
	
	player_hp -= 15.0 * delta
	player_hp = clamp(player_hp, 0.0, 100.0)

func repair_armor() -> void:
	armor_hp = 100.0
	grace_period_active = false
	grace_timer = 0.0
	print("Armor repaired!")

func repair_control_room_shield() -> void:
	control_room_shield = 100.0
	print("Control room shield restored!")

func _check_win_lose() -> void:
	if electricity_quota >= ELECTRICITY_TARGET:
		_end_game("win")
	elif reactor_temp <= 5.0 and reactor_pressure <= 50.0:
		_end_game("blackhole")
	elif player_hp <= 0.0:
		_end_game("death")

func _end_game(reason: String) -> void:
	game_over = true
	emit_signal("game_ended", reason)

# ============================================================
# STARTUP ACTIONS
# ============================================================
func toggle_lights() -> void:
	if startup_state == StartupState.OFFLINE or \
	   startup_state == StartupState.PRE_STARTUP:
		lights_on = not lights_on
		emit_signal("lights_toggled", lights_on)
		print("Lights: ", lights_on)

func toggle_monitor() -> void:
	if not lights_on:
		print("Nyalain lampu dulu!")
		return
	monitor_on = not monitor_on
	emit_signal("monitor_toggled", monitor_on)
	print("Monitor: ", monitor_on)

func toggle_extractor_online() -> void:
	if startup_state == StartupState.RUNNING:
		# Kalau reactor sudah running dan extractor di-toggle
		# → extractor fail to startup
		print("WARNING: Extractor di-toggle saat reactor running!")
		extractor_broken = true
		extractor_online = false
		return
	extractor_online = not extractor_online
	print("Extractor online: ", extractor_online)

func run_startup_check() -> void:
	# Auto check semua sistem
	startup_coolant_ok = coolant_storage > 50.0
	startup_cpu_ok = cpu_temp < 60.0
	startup_extractor_ok = extractor_online and not extractor_broken
	startup_check_done = true
	emit_signal("startup_check_result",
		startup_coolant_ok,
		startup_cpu_ok,
		startup_extractor_ok)
	print("Startup check — Coolant: ", startup_coolant_ok,
		" CPU: ", startup_cpu_ok,
		" Extractor: ", startup_extractor_ok)

func start_reactor() -> void:
	if startup_state == StartupState.RUNNING:
		return
	if startup_state == StartupState.STARTING:
		return
	if not lights_on or not monitor_on:
		print("Nyalain lampu dan monitor dulu!")
		return
	
	# Reset state untuk fresh startup
	startup_check_done = false
	startup_coolant_ok = false
	startup_cpu_ok = false
	startup_extractor_ok = false
	startup_total_elapsed = 0.0
	startup_phase = StartupPhase.IDLE
	
	# Kalau post-MCS restart — reactor sudah cold shutdown
	if reactor_shutdown:
		reactor_shutdown = false
		mcs_active = false
		mcs_stabilizing = false
		# Suhu sudah rendah dari MCS, tidak perlu reset
	
	# Run check dulu
	run_startup_check()
	
	# Mulai sequence
	startup_state = StartupState.STARTING
	startup_phase = StartupPhase.SYSTEM_ONLINE
	startup_phase_timer = PHASE_DURATIONS[StartupPhase.SYSTEM_ONLINE]
	emit_signal("startup_state_changed", startup_state)
	emit_signal("startup_phase_changed", startup_phase, false)
	print("Startup sequence initiated")

func _update_startup(delta: float) -> void:
	if startup_state != StartupState.STARTING:
		return
	
	startup_phase_timer -= delta
	startup_total_elapsed += delta
	startup_total_elapsed = min(startup_total_elapsed, STARTUP_TOTAL_DURATION)
	
	# Update check step untuk coolant dan laser
	if startup_phase == StartupPhase.CHECK_COOLANT or \
	   startup_phase == StartupPhase.CHECK_LASER:
		startup_check_step_timer -= delta
		if startup_check_step_timer <= 0.0 and startup_check_step < 3:
			startup_check_step += 1
			startup_check_step_timer = STARTUP_CHECK_STEP_DELAY
			emit_signal("startup_check_step_updated",
				startup_phase == StartupPhase.CHECK_LASER,
				startup_check_step)
	
	if startup_phase_timer <= 0.0:
		_advance_startup_phase()

func _advance_startup_phase() -> void:
	match startup_phase:
		StartupPhase.SYSTEM_ONLINE:
			_go_to_phase(StartupPhase.INITIATING)
		
		StartupPhase.INITIATING:
			_go_to_phase(StartupPhase.CHECK_COOLANT)
		
		StartupPhase.CHECK_COOLANT:
			# Warning kalau coolant tidak siap
			var warn = not startup_coolant_ok
			_go_to_phase(StartupPhase.CHECK_LASER, warn)
		
		StartupPhase.CHECK_LASER:
			_go_to_phase(StartupPhase.CHECK_EXTRACTOR)
		
		StartupPhase.CHECK_EXTRACTOR:
			# Warning kalau extractor tidak online
			var warn = not startup_extractor_ok
			_go_to_phase(StartupPhase.CONNECTING, warn)
		
		StartupPhase.CONNECTING:
			_go_to_phase(StartupPhase.WARNING_EVACUATE)
		
		StartupPhase.WARNING_EVACUATE:
			_go_to_phase(StartupPhase.ENGAGING)
		
		StartupPhase.ENGAGING:
			_go_to_phase(StartupPhase.COUNTDOWN)
		
		StartupPhase.COUNTDOWN:
			_go_to_phase(StartupPhase.GLITCH)
		
		StartupPhase.GLITCH:
			_go_to_phase(StartupPhase.COMPLETE)
		
		StartupPhase.COMPLETE:
			_complete_startup()

func _go_to_phase(phase: StartupPhase, has_warning: bool = false) -> void:
	startup_phase = phase
	startup_phase_timer = PHASE_DURATIONS.get(phase, 1.0)
	
	# Reset check step saat masuk phase check
	if phase == StartupPhase.CHECK_COOLANT or phase == StartupPhase.CHECK_LASER:
		startup_check_step = 0
		startup_check_step_timer = STARTUP_CHECK_STEP_DELAY
	
	emit_signal("startup_phase_changed", phase, has_warning)

func _complete_startup() -> void:
	startup_state = StartupState.RUNNING
	startup_phase = StartupPhase.IDLE
	emit_signal("startup_state_changed", startup_state)
	
	# Consequences kalau ada yang tidak siap
	if not startup_coolant_ok:
		reactor_temp = 280.0
		print("STARTUP WARN — coolant offline, temp spike!")
	
	if not startup_extractor_ok:
		extractor_broken = true
		print("STARTUP WARN — extractor fail!")
	
	# Reactor mulai dari suhu rendah, naik perlahan
	reactor_temp = max(reactor_temp, 80.0)
	reactor_pressure = 400.0
	print("Reactor ONLINE!")

func get_total_laser_intensity() -> float:
	var total = 0.0
	for i in range(LASER_COUNT):
		if not laser_broken_states[i]:
			total += laser_intensities[i]
	return total / LASER_COUNT   # rata-rata, bukan total mentah

# ============================================================
# PLAYER ACTIONS (dipanggil dari tombol UI)
# ============================================================
func set_laser(index: int, value: float) -> void:
	if index < 0 or index >= LASER_COUNT:
		return
	if laser_broken_states[index]:
		return
	laser_intensities[index] = clamp(value, 0.0, 100.0)

func set_extraction(value: float) -> void:
	if not extractor_broken:
		extraction_level = clamp(value, 0.0, 100.0)

func get_active_vent_count() -> int:
	var count = 0
	for v in vent_states:
		if v:
			count += 1
	return count

# SEMENTARA — test trigger manual, hapus nanti
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:
			_trigger_sysadmin()
			print("SYSADMIN TEST TRIGGERED")

func toggle_vent(index: int) -> void:
	if index < 0 or index >= VENT_COUNT:
		return
	vent_states[index] = not vent_states[index]
	print("Vent %d: " % (index + 1), vent_states[index])

func _update_vent(delta: float) -> void:
	var active_count = get_active_vent_count()
	if active_count == 0:
		return
	
	# Hitung efektivitas berdasarkan pressure saat ini
	var effectiveness: float = 0.0
	if reactor_pressure <= VENT_EFFECTIVE_THRESHOLD:
		# Pressure rendah — vent sangat efektif, bisa nurunin pressure
		effectiveness = 1.0
	elif reactor_pressure >= VENT_INEFFECTIVE_THRESHOLD:
		# Pressure sangat tinggi — vent hampir tidak berguna
		effectiveness = 0.05
	else:
		# Interpolasi antara efektif dan tidak efektif
		var ratio = (reactor_pressure - VENT_EFFECTIVE_THRESHOLD) / \
			(VENT_INEFFECTIVE_THRESHOLD - VENT_EFFECTIVE_THRESHOLD)
		effectiveness = lerp(1.0, 0.05, ratio)
	
	# Total efek vent — makin banyak aktif makin kuat
	var total_effect = VENT_BASE_REDUCTION * active_count * effectiveness
	reactor_pressure -= total_effect * delta
	reactor_pressure = clamp(reactor_pressure, 0.0, PRESSURE_MAX)

signal room_changed(new_room: String)

func set_room(room: String) -> void:
	if current_room == room:
		return   # tidak perlu update kalau sama
	current_room = room
	emit_signal("room_changed", room)
	print("Current room: ", room)

func toggle_hazmat() -> void:
	hazmat_equipped = not hazmat_equipped
	if hazmat_equipped:
		armor_hp = 100.0    # langsung penuh saat equip
	else:
		armor_hp = 0.0      # langsung 0 saat unequip
		grace_period_active = false
		grace_timer = 0.0
	emit_signal("hazmat_toggled", hazmat_equipped)

func start_armor_repair() -> void:
	if inv_armor_patch <= 0:
		print("Tidak ada Armor Patch Kit!")
		return
	if armor_repairing:
		print("Sudah dalam proses repair!")
		return
	if armor_hp >= 100.0:
		print("Armor sudah penuh!")
		return
	inv_armor_patch -= 1
	armor_repairing = true
	armor_repair_timer = ARMOR_REPAIR_DURATION
	print("Armor repair started!")

func _update_armor_repair(delta: float) -> void:
	if not armor_repairing:
		return
	armor_repair_timer -= delta
	armor_repair_timer = max(armor_repair_timer, 0.0)
	if armor_repair_timer <= 0.0:
		armor_hp = 100.0
		armor_repairing = false
		grace_period_active = false
		grace_timer = 0.0
		emit_signal("armor_repair_completed")
		print("Armor fully repaired!")

# ============================================================
# COOLANT ACTIONS
# ============================================================
func set_coolant_active(state: bool) -> void:
	if coolant_pump_broken:
		print("Pompa rusak!")
		return
	coolant_active = state
	if not state:
		coolant_rpm = 0

func set_coolant_rpm(rpm: int) -> void:
	if coolant_pump_broken:
		return
	coolant_rpm = clamp(rpm, 1, 3)

func _update_coolant(delta: float) -> void:
	if not coolant_active or coolant_pump_broken:
		return
	if coolant_storage <= 0.0:
		coolant_active = false
		coolant_rpm = 0
		return

	# Efek pendinginan ke reaktor
	var cooling_effect: float = 0.0
	var drain_rate: float = 0.0

	match coolant_rpm:
		1:  # Low
			cooling_effect = COOLANT_EFFECT_LOW
			drain_rate = COOLANT_DRAIN_LOW
		2:  # Medium
			cooling_effect = COOLANT_EFFECT_MED
			drain_rate = COOLANT_DRAIN_MED
		3:  # High
			cooling_effect = COOLANT_EFFECT_HIGH
			drain_rate = COOLANT_DRAIN_HIGH
			# High RPM — random chance merusak pompa per detik
			if randf() < PUMP_DAMAGE_CHANCE_HIGH * delta * 60.0:
				_damage_coolant_pump()

	reactor_temp -= cooling_effect * delta
	reactor_temp = clamp(reactor_temp, 0.0, TEMP_MAX)
	coolant_storage -= drain_rate * delta
	coolant_storage = clamp(coolant_storage, 0.0, COOLANT_STORAGE_MAX)

func _damage_coolant_pump() -> void:
	coolant_active = false
	coolant_rpm = 0
	coolant_pump_broken = true
	emit_signal("coolant_pump_damaged")
	print("COOLANT PUMP DAMAGED!")

func repair_coolant_pump() -> void:
	coolant_pump_broken = false
	coolant_pump_hp = 100.0
	print("Coolant pump repaired!")

func refill_eccs_from_coolant() -> void:
	if coolant_storage < 30.0:
		print("Coolant tidak cukup!")
		return
	if eccs_charges >= 3:
		print("ECCS sudah penuh!")
		return
	coolant_storage -= 30.0
	eccs_charges = min(eccs_charges + 1, 3)
	print("ECCS refilled! Charges: ", eccs_charges)

# ============================================================
# CRAFTING ACTIONS
# ============================================================
func start_craft(item: String) -> void:
	if crafting_item != "":
		print("Sudah ada crafting berjalan: ", crafting_item)
		return
	
	var duration: float = 0.0
	match item:
		"extractor_part":
			duration = CRAFT_TIME_EXTRACTOR
		"mcs_module":
			duration = CRAFT_TIME_MCS
		"coolant_kit":
			duration = CRAFT_TIME_COOLANT_KIT
		"cpu_module":
			duration = CRAFT_TIME_CPU
		"armor_patch":                          # ← tambah
			duration = CRAFT_TIME_ARMOR_PATCH
		_:
			print("Unknown item: ", item)
			return
	
	crafting_item = item
	crafting_timer = duration
	crafting_duration = duration
	emit_signal("crafting_started", item, duration)
	print("Crafting started: ", item, " (", duration, "s)")

func cancel_craft() -> void:
	if crafting_item == "":
		return
	var cancelled = crafting_item
	crafting_item = ""
	crafting_timer = 0.0
	crafting_duration = 0.0
	emit_signal("crafting_cancelled", cancelled)

func _update_crafting(delta: float) -> void:
	if crafting_item == "":
		return
	
	crafting_timer -= delta
	
	if crafting_timer <= 0.0:
		_complete_craft()

func _complete_craft() -> void:
	match crafting_item:
		"extractor_part":
			inv_extractor_part += 1
		"mcs_module":
			inv_mcs_module += 1
		"coolant_kit":
			inv_coolant_kit += 1
		"cpu_module":
			inv_cpu_module += 1
		"armor_patch": 
			inv_armor_patch += 1
	
	print("Crafting complete: ", crafting_item)
	emit_signal("crafting_completed", crafting_item)
	crafting_item = ""
	crafting_timer = 0.0
	crafting_duration = 0.0

# ============================================================
# USE ITEM ACTIONS
# ============================================================
func use_extractor_part() -> void:
	if inv_extractor_part <= 0:
		return
	inv_extractor_part -= 1
	extractor_broken = false
	extraction_stress = 0.0           # stress reset
	extractor_durability = 100.0      # durability fully restored
	print("Extractor repaired!")

func use_mcs_module() -> void:
	if inv_mcs_module <= 0:
		return
	inv_mcs_module -= 1
	mcs_broken = false
	print("MCS module replaced!")

func use_coolant_kit() -> void:
	if inv_coolant_kit <= 0:
		return
	inv_coolant_kit -= 1
	repair_coolant_pump()
	print("Coolant pump repaired!")

func use_cpu_module() -> void:
	if inv_cpu_module <= 0:
		return
	inv_cpu_module -= 1
	cpu_temp = 20.0
	input_delay = 0.0
	print("CPU module replaced!")

# ============================================================
# EMERGENCY SYSTEMS
# ============================================================
func use_eccs() -> void:
	if eccs_charges <= 0 or eccs_cooldown > 0.0 or eccs_active:
		return
	eccs_charges -= 1
	eccs_active = true
	eccs_cooling_timer = ECCS_COOLING_DURATION
	stat_eccs_used += 1
	print("ECCS activated — cooling for %.0fs" % ECCS_COOLING_DURATION)

func use_emergency_vent() -> void:
	if emergency_vent_cooldown > 0.0 or emergency_vent_active:
		return
	emergency_vent_active = true
	emergency_vent_timer = EMERGENCY_VENT_DURATION
	print("Emergency Vent activated — venting for %.0fs" % EMERGENCY_VENT_DURATION)

func _check_mcs_trigger() -> void:
	# Jangan trigger kalau MCS sedang berjalan atau baru selesai
	if mcs_active or mcs_blackout_active or mcs_stabilizing or reactor_shutdown:
		return
	# Jangan trigger saat startup sequence
	if startup_state != StartupState.RUNNING:
		return
	if reactor_state == 4:
		_trigger_mcs()

func _trigger_mcs() -> void:
	mcs_active = true
	mcs_used_count += 1
	
	# Matikan SEMUA sistem
	for i in range(LASER_COUNT):
		laser_intensities[i] = 0.0
	extraction_level = 0.0
	extractor_broken = true
	coolant_active = false
	for i in range(VENT_COUNT):
		vent_states[i] = false
	eccs_active = false
	emergency_vent_active = false
	
	mcs_blackout_active = true
	mcs_blackout_timer = MCS_BLACKOUT_DURATION
	is_in_panel_mode = false
	
	emit_signal("mcs_triggered")
	emit_signal("mcs_blackout_started")
	emit_signal("mcs_state_changed", true)
	print("MCS TRIGGERED — blackout started")

func _update_mcs(delta: float) -> void:
	# Blackout phase
	if mcs_blackout_active:
		mcs_blackout_timer -= delta
		mcs_blackout_timer = clamp(mcs_blackout_timer, 0.0, MCS_BLACKOUT_DURATION)
		
		# Saat blackout, suhu mulai turun paksa
		reactor_temp = move_toward(reactor_temp, 100.0, 30.0 * delta)
		reactor_pressure = move_toward(reactor_pressure, 500.0, 300.0 * delta)
		
		if mcs_blackout_timer <= 0.0:
			mcs_blackout_active = false
			mcs_stabilizing = true
			emit_signal("mcs_blackout_ended")
		return
	
	# Stabilisasi phase
	if mcs_stabilizing:
		reactor_temp = move_toward(reactor_temp, 50.0, 15.0 * delta)
		reactor_pressure = move_toward(reactor_pressure, 200.0, 150.0 * delta)
		
		var temp_stable = abs(reactor_temp - 50.0) < 5.0
		var pressure_stable = abs(reactor_pressure - 200.0) < 20.0
		
		if temp_stable and pressure_stable:
			mcs_stabilizing = false
			mcs_active = false
			reactor_shutdown = true
			_apply_mcs_damage()
			_on_mcs_complete_internal()
			emit_signal("mcs_state_changed", false)
			emit_signal("mcs_stabilization_complete")
			print("MCS complete — cold shutdown")

func _on_mcs_complete_internal() -> void:
	monitor_on = false
	lights_on = false
	startup_state = StartupState.OFFLINE
	startup_phase = StartupPhase.IDLE
	startup_check_done = false
	startup_total_elapsed = 0.0
	
	# Reset stress
	extraction_stress = 0.0
	for i in range(LASER_COUNT):
		laser_stresses[i] = 0.0
	
	# Matikan semua sistem
	coolant_active = false
	coolant_rpm = 0
	for i in range(VENT_COUNT):
		vent_states[i] = false
	for i in range(LASER_COUNT):
		laser_intensities[i] = 0.0
	extraction_level = 0.0
	
	# Reset MCS flags — PENTING agar tidak re-trigger
	mcs_active = false
	mcs_blackout_active = false
	mcs_stabilizing = false
	
	emit_signal("lights_toggled", false)
	emit_signal("monitor_toggled", false)
	emit_signal("startup_state_changed", startup_state)
	print("Control room offline — manual reboot required")

func _apply_mcs_damage() -> void:
	var damaged_systems = []
	
	# Tiap laser ada chance kena damage
	for i in range(LASER_COUNT):
		if randf() < 0.5:
			laser_broken_states[i] = true
			laser_durabilities[i] = randf_range(20.0, 60.0)
			laser_stresses[i] = 0.0
			damaged_systems.append("Laser %d" % (i + 1))
	
	if randf() < 0.6:
		extractor_broken = true
		extractor_durability = randf_range(20.0, 60.0)
		damaged_systems.append("Extractor")
	if randf() < 0.5:
		coolant_pump_broken = true
		coolant_pump_durability = randf_range(30.0, 70.0)
		damaged_systems.append("Coolant Pump")
	if randf() < 0.4:
		mcs_broken = true
		damaged_systems.append("MCS Module")
	
	control_room_shield = randf_range(10.0, 40.0)
	damaged_systems.append("Control Room Shield")
	
	emit_signal("mcs_damage_applied", damaged_systems)

signal mcs_damage_applied(systems: Array)

func _mcs_fail() -> void:
	mcs_broken = true
	mcs_active = false
	laser_broken_states = [true, true, true]
	extractor_broken = true
	print("MCS FAILED!")
	
	# Kalau sudah gagal 2x — SYSTEM//ADMIN mengambil alih
	if mcs_used_count >= 2:
		_trigger_sysadmin()

func _trigger_sysadmin() -> void:
	print("_trigger_sysadmin() called!")
	if sysadmin_active:
		return
	sysadmin_active = true
	sysadmin_timer = SYSADMIN_DURATION
	sysadmin_phase = "takeover"
	is_in_panel_mode = false
	
	# Kunci semua input
	# Paksa matikan semua sistem
	for i in range(LASER_COUNT):
		laser_intensities[i] = 0.0
	extraction_level = 0.0
	coolant_active = false
	for i in range(VENT_COUNT):
		vent_states[i] = false
	
	emit_signal("sysadmin_triggered")
	print("SYSTEM//ADMIN TAKEOVER")

func _update_sysadmin(delta: float) -> void:
	if not sysadmin_active:
		return
	
	print("sysadmin timer: ", sysadmin_timer)
	
	sysadmin_timer -= delta
	sysadmin_timer = max(sysadmin_timer, 0.0)
	
	emit_signal("sysadmin_countdown_tick", sysadmin_timer)
	
	# Phase takeover — 5 detik pertama, reaktor dihancurkan
	if sysadmin_phase == "takeover" and sysadmin_timer <= 25.0:
		sysadmin_phase = "countdown"
		# Paksa semua laser meledak
		for i in range(LASER_COUNT):
			laser_broken_states[i] = true
			laser_stresses[i] = 100.0
	
	# Collapse — timer habis
	if sysadmin_timer <= 0.0:
		sysadmin_phase = "collapse"
		sysadmin_active = false
		emit_signal("sysadmin_collapse")
		_end_game("sysadmin")

func refill_eccs() -> void:
	# Dipanggil saat player di Coolant Room
	eccs_charges = 3
	print("ECCS recharged!")

func _update_eccs(delta: float) -> void:
	# Update cooldown
	if eccs_cooldown > 0.0:
		eccs_cooldown -= delta
		eccs_cooldown = clamp(eccs_cooldown, 0.0, ECCS_COOLDOWN_TIME)
	
	if not eccs_active:
		return
	
	# Aktif mendinginkan — turun bertahap
	eccs_cooling_timer -= delta
	
	# Pause kenaikan suhu + turunkan bertahap
	reactor_temp -= ECCS_COOLING_RATE * delta
	reactor_temp = clamp(reactor_temp, 0.0, TEMP_MAX)
	
	if eccs_cooling_timer <= 0.0:
		eccs_active = false
		eccs_cooldown = ECCS_COOLDOWN_TIME
		print("ECCS cooling complete")

func _update_emergency_vent(delta: float) -> void:
	# Update cooldown
	if emergency_vent_cooldown > 0.0:
		emergency_vent_cooldown -= delta
		emergency_vent_cooldown = clamp(emergency_vent_cooldown, 0.0, EMERGENCY_VENT_COOLDOWN)
	
	if not emergency_vent_active:
		return
	
	# Aktif venting — turun bertahap
	emergency_vent_timer -= delta
	
	reactor_pressure -= EMERGENCY_VENT_RATE * delta
	reactor_pressure = clamp(reactor_pressure, 0.0, PRESSURE_MAX)
	
	if emergency_vent_timer <= 0.0:
		emergency_vent_active = false
		emergency_vent_cooldown = EMERGENCY_VENT_COOLDOWN
		print("Emergency Vent complete")
