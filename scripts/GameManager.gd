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
var coolant_capacity: float = 100.0
var cpu_temp: float = 20.0
var input_delay: float = 0.0          # detik — Tweak 1

var eccs_charges: int = 3
var mcs_used: bool = false

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

# Sinyal untuk memberi tahu UI
signal reactor_state_changed(new_state: int)
signal game_ended(reason: String)
signal night_toggled(is_night: bool)

# ============================================================
# GAME LOOP
# ============================================================
func _process(delta: float) -> void:
	if game_over:
		return

	time_elapsed += delta
	_update_day_night_cycle()
	_update_reactor(delta)
	_update_cpu(delta)
	_update_armor(delta)
	_check_win_lose()

func _update_day_night_cycle() -> void:
	var was_night = is_night
	is_night = fmod(time_elapsed, day_duration * 2) >= day_duration
	if is_night != was_night:
		emit_signal("night_toggled", is_night)

func _update_reactor(delta: float) -> void:
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
	reactor_pressure += temp_ratio * 40.0 * delta

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

func toggle_vent(state: bool) -> void:
	vent_active = state

func use_eccs() -> void:
	if eccs_charges > 0:
		reactor_temp -= 30.0
		reactor_temp = clamp(reactor_temp, 0.0, 100.0)
		eccs_charges -= 1

func set_room(room_name: String) -> void:
	current_room = room_name
