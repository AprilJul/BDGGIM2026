extends Node

# ============================================================
# REACTOR VARIABLES
# ============================================================
var reactor_temp: float = 30.0        # 0–100 persen
var reactor_pressure: float = 20.0    # 0–100 persen
var laser_intensity: float = 0.0      # 0–100 persen

# ============================================================
# ELECTRICITY
# ============================================================
var electricity_output: float = 0.0   # output per detik
var electricity_quota: float = 0.0    # total terkumpul (target 100)
var extraction_level: float = 0.0     # 0–100 persen
var extraction_stress: float = 0.0    # 0–100, kalau > 100 extractor rusak

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
	# Ambient modifier: malam = pendingin alami, tapi di Tweak 2 kita balik jadi negatif
	var ambient_modifier: float = -0.5 if not is_night else 2.0

	# Laser menaikkan suhu
	reactor_temp += laser_intensity * 0.05 * delta

	# Ambient effect
	reactor_temp += ambient_modifier * delta

	# Vent menurunkan pressure (tapi efisiensinya turun kalau pressure > 80)
	if vent_active:
		var vent_efficiency = 1.0 if reactor_pressure <= 80.0 else 0.4
		reactor_pressure -= 15.0 * vent_efficiency * delta

	# Suhu tinggi menaikkan pressure
	reactor_pressure += (reactor_temp - 50.0) * 0.02 * delta

	# Extraction stress
	if not extractor_broken:
		extraction_stress += extraction_level * 0.01 * delta
		electricity_output = extraction_level * 0.5
		electricity_quota += electricity_output * delta * 0.01
		if extraction_stress >= 100.0:
			extractor_broken = true
			electricity_output = 0.0

	# Clamp semua nilai biar tidak keluar batas
	reactor_temp = clamp(reactor_temp, 0.0, 100.0)
	reactor_pressure = clamp(reactor_pressure, 0.0, 100.0)
	electricity_quota = clamp(electricity_quota, 0.0, 100.0)
	extraction_stress = clamp(extraction_stress, 0.0, 100.0)

	_update_reactor_state()

func _update_reactor_state() -> void:
	var old_state = reactor_state
	if reactor_temp < 10.0:
		reactor_state = -1
	elif reactor_temp < 50.0:
		reactor_state = 1
	elif reactor_temp < 70.0:
		reactor_state = 1
	elif reactor_temp < 85.0:
		reactor_state = 2
	elif reactor_temp < 95.0:
		reactor_state = 3
	else:
		reactor_state = 4
		extraction_stress = 100.0   # auto shutdown

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
	if electricity_quota >= 100.0:
		_end_game("win")
	elif reactor_temp >= 100.0 and reactor_pressure >= 100.0:
		_end_game("meltdown")
	elif reactor_temp <= 0.0 and reactor_pressure <= 0.0:
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
