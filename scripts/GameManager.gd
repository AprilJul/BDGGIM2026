extends Node

# ============================================================
# REACTOR VARIABLES — unit realistis
# ============================================================
var reactor_temp: float = 180.0       # Celcius, range 0–350°C
var reactor_pressure: float = 800.0   # PSI, range 0–2200 PSI
var laser_intensity: float = 0.0      # 0–100% (kontrol internal)

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
var electricity_output: float = 0.0   # MW/h output saat ini
var electricity_quota: float = 0.0    # MW/h terkumpul (target 1000)
var extraction_level: float = 0.0     # 0–100% kontrol
var extraction_stress: float = 0.0    # 0–100%
var laser_stress: float = 0.0        # 0–100%, laser overheat
var laser_broken: bool = false

const ELECTRICITY_TARGET: float = 1000.0

# ============================================================
# PLAYER
# ============================================================
var player_hp: float = 100.0
var armor_hp: float = 100.0
var current_room: String = "control_room"

# ============================================================
# SYSTEMS
# ============================================================
var vent_active: bool = false
var vent_cooldown: float = 0.0
const VENT_COOLDOWN_TIME: float = 30.0   # detik cooldown
const VENT_DROP_AMOUNT: float = 400.0    # PSI yang di-drop sekali vent
const VENT_OFF_THRESHOLD: float = 200.0  # PSI — vent otomatis off di bawah ini
var coolant_capacity: float = 100.0
var cpu_temp: float = 20.0
var input_delay: float = 0.0          # detik — Tweak 1

# ECCS
var eccs_charges: int = 3
var eccs_cooling: bool = false        # sedang aktif mendinginkan
var eccs_cooldown: float = 0.0
const ECCS_TEMP_DROP: float = 80.0   # °C yang di-drop
const ECCS_COOLDOWN_TIME: float = 20.0

# Emergency Vent
var emergency_vent_cooldown: float = 0.0
const EMERGENCY_VENT_COOLDOWN: float = 120.0
const EMERGENCY_VENT_DROP: float = 1200.0  # PSI drop instan

# MCS
var mcs_used_count: int = 0
var mcs_active: bool = false
var mcs_broken: bool = false          # butuh repair manual di Reactor Room

# ============================================================
# TIME
# ============================================================
var is_night: bool = false
var time_elapsed: float = 0.0
var day_duration: float = 300.0       # 5 menit = siang

# ============================================================
# STATE
# ============================================================
var reactor_state: int = 1            # -1, 0, 1, 2, 3, 4
var game_over: bool = false
var extractor_broken: bool = false
var is_in_panel_mode: bool = false
var reactor_shutdown: bool = false 

# Sinyal untuk memberi tahu UI
signal reactor_state_changed(new_state: int)
signal game_ended(reason: String)
signal night_toggled(is_night: bool)
signal mcs_state_changed(is_active: bool)

# ============================================================
# GAME LOOP
# ============================================================
func _process(delta: float) -> void:
	if game_over:
		return

	time_elapsed += delta
	_update_day_night_cycle()
	_update_reactor(delta)
	_update_vent(delta)
	_update_eccs(delta)    
	_update_emergency_vent(delta)    
	_update_mcs(delta)
	_update_cpu(delta)
	_update_armor(delta)
	_check_win_lose()

func _update_day_night_cycle() -> void:
	var was_night = is_night
	is_night = fmod(time_elapsed, day_duration * 2) >= day_duration
	if is_night != was_night:
		emit_signal("night_toggled", is_night)

func _update_reactor(delta: float) -> void:
		# Kalau shutdown, reaktor dingin sendiri perlahan, tidak ada proses
	if reactor_shutdown:
		reactor_temp = move_toward(reactor_temp, 20.0, 3.0 * delta)
		reactor_pressure = move_toward(reactor_pressure, 100.0, 50.0 * delta)
		return   # skip semua kalkulasi normal

	# Malam: ambient jadi pemanas, bukan pendingin
	var ambient_modifier: float = -1.5 if not is_night else 10.0

	# Laser menaikkan suhu (skala ke unit Celcius)
	reactor_temp += laser_intensity * 0.3 * delta

	# Ambient effect
	reactor_temp += ambient_modifier * delta

	# Vent menurunkan pressure
	if vent_active:
		var vent_efficiency = 1.0 if reactor_pressure <= PRESSURE_WARNING else 0.4
		reactor_pressure -= 180.0 * vent_efficiency * delta

	# Suhu tinggi menaikkan pressure (skala PSI)
	var temp_ratio = (reactor_temp - 150.0) / TEMP_MAX
	var extract_pressure = (extraction_level / 100.0) * 25.0
	reactor_pressure += (temp_ratio * 40.0 + extract_pressure) * delta
	
	# Laser stress naik saat laser_intensity tinggi
	if not laser_broken:
		laser_stress += (laser_intensity / 100.0) * 0.8 * delta
		# Laser stress turun sendiri saat intensity rendah
		if laser_intensity < 20.0:
			laser_stress -= 1.5 * delta
		laser_stress = clamp(laser_stress, 0.0, 100.0)
		if laser_stress >= 100.0:
			laser_broken = true
			laser_intensity = 0.0
	else:
		# Laser pelan-pelan dingin sendiri saat rusak
		laser_stress -= 0.5 * delta
		laser_stress = clamp(laser_stress, 0.0, 100.0)
		if laser_stress <= 0.0:
			laser_broken = false

	# Extraction
	if not extractor_broken:
		extraction_stress += extraction_level * 0.01 * delta
		electricity_output = extraction_level * 10.0   # max 1000 MW/h
		electricity_quota += electricity_output * delta * 0.01
		if extraction_stress >= 100.0:
			extractor_broken = true
			electricity_output = 0.0

	# Clamp
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

func repair_laser() -> void:
	laser_broken = false
	laser_stress = 0.0

func _update_cpu(delta: float) -> void:
	# CPU memanas seiring reaktor panas
	cpu_temp += (reactor_temp - 40.0) * 0.01 * delta
	cpu_temp = clamp(cpu_temp, 10.0, 100.0)
	# Input delay berbanding lurus suhu CPU di atas 60
	input_delay = max(0.0, (cpu_temp - 60.0) * 0.05)

func _update_armor(delta: float) -> void:
	if current_room == "reactor_room":
		var radiation_damage = (reactor_temp / 100.0) * 5.0 * delta
		armor_hp -= radiation_damage
		armor_hp = clamp(armor_hp, 0.0, 100.0)
		if armor_hp <= 0.0:
			player_hp -= 2.0 * delta

func _check_win_lose() -> void:
	if electricity_quota >= ELECTRICITY_TARGET:
		_end_game("win")
	elif reactor_temp >= TEMP_MAX and reactor_pressure >= PRESSURE_MAX:
		_end_game("meltdown")
	elif reactor_temp <= 5.0 and reactor_pressure <= 50.0:
		_end_game("blackhole")
	elif player_hp <= 0.0:
		_end_game("death")

func _end_game(reason: String) -> void:
	game_over = true
	emit_signal("game_ended", reason)

# ============================================================
# PLAYER ACTIONS (dipanggil dari tombol UI)
# ============================================================
func set_laser(value: float) -> void:
	laser_intensity = clamp(value, 0.0, 100.0)

func set_extraction(value: float) -> void:
	if not extractor_broken:
		extraction_level = clamp(value, 0.0, 100.0)

func activate_vent() -> void:
	# Hanya bisa diaktifkan kalau tidak cooldown
	if vent_cooldown > 0.0:
		return
	vent_active = true

func _update_vent(delta: float) -> void:
	if vent_cooldown > 0.0:
		vent_cooldown -= delta
		vent_cooldown = clamp(vent_cooldown, 0.0, VENT_COOLDOWN_TIME)

	if not vent_active:
		return

	# Drop pressure
	var vent_efficiency = 1.0 if reactor_pressure > PRESSURE_WARNING else 0.4
	reactor_pressure -= VENT_DROP_AMOUNT * vent_efficiency * delta

	# Auto off saat pressure sudah cukup rendah
	if reactor_pressure <= VENT_OFF_THRESHOLD:
		reactor_pressure = VENT_OFF_THRESHOLD
		vent_active = false
		vent_cooldown = VENT_COOLDOWN_TIME

func set_room(room_name: String) -> void:
	current_room = room_name

# ============================================================
# EMERGENCY SYSTEMS
# ============================================================
func use_eccs() -> void:
	print("use_eccs() called — charges: ", eccs_charges, " cooldown: ", eccs_cooldown)
	if eccs_charges <= 0 or eccs_cooldown > 0.0:
		print("ECCS blocked!")
		return
	eccs_charges -= 1
	eccs_cooldown = ECCS_COOLDOWN_TIME
	reactor_temp -= ECCS_TEMP_DROP
	reactor_temp = clamp(reactor_temp, 0.0, TEMP_MAX)
	print("ECCS fired! Temp now: ", reactor_temp)

func use_emergency_vent() -> void:
	print("use_emergency_vent() called — cooldown: ", emergency_vent_cooldown)
	if emergency_vent_cooldown > 0.0:
		print("E-Vent blocked!")
		return
	emergency_vent_cooldown = EMERGENCY_VENT_COOLDOWN
	reactor_pressure -= EMERGENCY_VENT_DROP
	reactor_pressure = clamp(reactor_pressure, 0.0, PRESSURE_MAX)
	print("E-Vent fired! Pressure now: ", reactor_pressure)

func use_mcs() -> void:
	print("use_mcs() called — used_count: ", mcs_used_count)
	if mcs_broken:
		print("MCS broken!")
		return
	mcs_used_count += 1
	if mcs_used_count == 1:
		_mcs_success()
		return
	if randf() < 0.5:
		_mcs_success()
	else:
		_mcs_fail()

func _mcs_success() -> void:
	print("MCS SUCCESS!")
	mcs_active = true
	laser_intensity = 0.0
	extraction_level = 0.0
	vent_active = false
	reactor_shutdown = false   # belum shutdown, masih dalam proses
	emit_signal("mcs_state_changed", true)

func _mcs_fail() -> void:
	print("MCS FAILED!")
	mcs_broken = true
	mcs_active = false
	laser_broken = true
	extractor_broken = true

func refill_eccs() -> void:
	# Dipanggil saat player di Coolant Room
	eccs_charges = 3
	print("ECCS recharged!")

func _update_eccs(delta: float) -> void:
	if eccs_cooldown > 0.0:
		eccs_cooldown -= delta
		eccs_cooldown = clamp(eccs_cooldown, 0.0, ECCS_COOLDOWN_TIME)

func _update_emergency_vent(delta: float) -> void:
	if emergency_vent_cooldown > 0.0:
		emergency_vent_cooldown -= delta
		emergency_vent_cooldown = clamp(emergency_vent_cooldown, 0.0, EMERGENCY_VENT_COOLDOWN)

func _update_mcs(delta: float) -> void:
	if not mcs_active:
		return
	reactor_temp = move_toward(reactor_temp, 50.0, 20.0 * delta)      # ← target 50°C, bukan 150
	reactor_pressure = move_toward(reactor_pressure, 200.0, 200.0 * delta)  # ← target 200 PSI
	var temp_stable = abs(reactor_temp - 50.0) < 5.0
	var pressure_stable = abs(reactor_pressure - 200.0) < 20.0
	if temp_stable and pressure_stable:
		mcs_active = false
		reactor_shutdown = true    # ← reaktor sekarang cold shutdown
		laser_intensity = 0.0
		extraction_level = 0.0
		emit_signal("mcs_state_changed", false)
		emit_signal("reactor_state_changed", reactor_state)
		print("MCS complete — reactor in cold shutdown")
