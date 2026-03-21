extends Node

# Dictionary nama ruangan yang valid
const VALID_ROOMS = {
	"control_room": "Control Room",
	"reactor_room": "Reactor Room", 
	"cpu_room": "CPU Room",
	"coolant_room": "Coolant Room",
	"lab": "Laboratory",
	"medbay": "Medical Bay",
	"armory": "Armory",
	"corridor": "Corridor"
}

# Ruangan yang berbahaya (radiasi aktif)
const DANGEROUS_ROOMS = ["reactor_room"]

# Ruangan yang kena shield breach
const SHIELDED_ROOMS = ["control_room"]

static func is_dangerous(room: String) -> bool:
	return room in DANGEROUS_ROOMS

static func get_display_name(room: String) -> String:
	return VALID_ROOMS.get(room, room)
