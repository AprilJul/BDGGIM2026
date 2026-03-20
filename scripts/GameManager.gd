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
# COOLANT SYSTEM
# ============================================================
var coolant_active: bool = false
var coolant_storage: float = 500.0      # unit storage, bukan persen
const COOLANT_STORAGE_MAX: float = 500.0

# RPM: 0 = off, 1 = low, 2 = medium, 3 = high
var coolant_rpm: int = 0

# Placeholder values — bisa diatur saat balancing
const COOLANT_EFFECT_LOW: float = 5.0      # °C/s
const COOLANT_EFFECT_MED: float = 12.0     # °C/s
const COOLANT_EFFECT_HIGH: float = 22.0    # °C/s

const COOLANT_DRAIN_LOW: float = 2.0       # storage/s
const COOLANT_DRAIN_MED: float = 5.0       # storage/s
const COOLANT_DRAIN_HIGH: float = 10.0     # storage/s

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
# CRAFTING SYSTEM
# ============================================================
# Inventory item yang sudah di-craft
var inv_extractor_part: int = 0
var inv_mcs_module: int = 0
var inv_coolant_kit: int = 0
var inv_cpu_module: int = 0

# Crafting queue — hanya 1 item bisa di-craft sekaligus
var crafting_item: String = ""       # nama item yang sedang di-craft
var crafting_timer: float = 0.0
var crafting_duration: float = 0.0

# Durasi craft tiap item (detik) — bisa diatur saat balancing
const CRAFT_TIME_EXTRACTOR: float = 15.0
const CRAFT_TIME_MCS: float = 25.0
const CRAFT_TIME_COOLANT_KIT: float = 10.0
const CRAFT_TIME_CPU: float = 20.0

signal crafting_started(item: String, duration: float)
signal crafting_completed(item: String)
signal crafting_cancelled(item: String)

# ============================================================
# TIME
# ============================================================
var is_night: bool = false
var time_elapsed: float = 0.0
var day_duration: float = 10       # 5 menit = siang
var _night_warning_sent: bool = false

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
signal night_warning
signal grace_period_started
signal control_room_breached(shield_level: float)
signal coolant_pump_damaged

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
	_update_coolant(delta)
	_update_crafting(delta)
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
	# CPU memanas seiring reaktor panas
	cpu_temp += (reactor_temp - 40.0) * 0.01 * delta
	cpu_temp = clamp(cpu_temp, 10.0, 100.0)
	# Input delay berbanding lurus suhu CPU di atas 60
	input_delay = max(0.0, (cpu_temp - 60.0) * 0.05)

func _update_armor(delta: float) -> void:
	var radiation_damage = _get_radiation_damage()
	
	if radiation_damage <= 0.0:
		# Armor perlahan recover saat di zona aman
		armor_hp = min(armor_hp + 2.0 * delta, 100.0)
		grace_period_active = false
		grace_timer = 0.0
		return
	
	# Kurangi armor dulu
	armor_hp -= radiation_damage * delta
	armor_hp = clamp(armor_hp, 0.0, 100.0)
	
	if armor_hp <= 0.0:
		_handle_no_armor(delta)

func _get_radiation_damage() -> float:
	var temp_ratio = reactor_temp / TEMP_MAX
	
	match current_room:
		"reactor_room":
			# Makin panas reaktor, makin besar radiasi
			return RADIATION_REACTOR * temp_ratio
		"control_room":
			# Hanya tembus kalau shield di bawah 40%
			if control_room_shield < 40.0:
				var breach_ratio = (40.0 - control_room_shield) / 40.0
				return RADIATION_CONTROL * breach_ratio * temp_ratio
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
	extraction_stress = 0.0
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
