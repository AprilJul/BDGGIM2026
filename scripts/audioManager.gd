extends Node

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_DIALOGUE := "Dialogue"
const BUS_MUSIC := "Music"


var volumes := {
	"master": 1.0,
	"sfx": 1.0,
	"dialogue": 1.0,
	"music": 1.0
}

func _ready():
	apply_all_volumes()

# =========================
# PUBLIC API (USED BY UI)
# =========================

func set_master(value: float):
	volumes.master = clamp(value, 0.0, 1.0)
	_apply(BUS_MASTER, volumes.master)

func set_sfx(value: float):
	volumes.sfx = clamp(value, 0.0, 1.0)
	_apply(BUS_SFX, volumes.sfx)

func set_dialogue(value: float):
	volumes.dialogue = clamp(value, 0.0, 1.0)
	_apply(BUS_DIALOGUE, volumes.dialogue)

func set_music(value: float):
	volumes.music = clamp(value, 0.0, 1.0)
	_apply(BUS_MUSIC, volumes.music)

# =========================
# INTERNAL LOGIC
# =========================

func apply_all_volumes():
	_apply(BUS_MASTER, volumes.master)
	_apply(BUS_SFX, volumes.sfx)
	_apply(BUS_DIALOGUE, volumes.dialogue)
	_apply(BUS_MUSIC, volumes.music)

func _apply(bus_name: String, value: float):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value <= 0.001)
