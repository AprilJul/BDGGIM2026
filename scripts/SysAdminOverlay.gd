extends CanvasLayer

@onready var background = $Background
@onready var sysadmin_label = %SysAdminLabel
@onready var sub_label = %SubLabel
@onready var countdown_label = %CountdownLabel
@onready var evac_label = %EvacLabel
@onready var status_label = %StatusLabel

var _glitch_timer: float = 0.0
var _is_active: bool = false

func _ready() -> void:
	visible = false
	background.color.a = 0.0
	
	GameManager.sysadmin_triggered.connect(_on_triggered)
	GameManager.sysadmin_countdown_tick.connect(_on_countdown_tick)
	GameManager.sysadmin_collapse.connect(_on_collapse)
	print("SysAdminOverlay ready — signals connected")

func _process(delta: float) -> void:
	if not _is_active:
		return
	
	# Glitch effect pada label
	_glitch_timer += delta
	if _glitch_timer > 0.1:
		_glitch_timer = 0.0
		_glitch_text()

func _on_triggered() -> void:
	print("_on_triggered() called!")
	_is_active = true
	visible = true
	
	# Fade in background merah
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(background, "color",
		Color(0.1, 0.0, 0.0, 0.92), 1.0)
	
	# Animasi teks muncul
	sysadmin_label.modulate.a = 0.0
	sub_label.modulate.a = 0.0
	countdown_label.modulate.a = 0.0
	evac_label.modulate.a = 0.0
	
	var text_tween = create_tween()
	text_tween.tween_property(sysadmin_label, "modulate:a", 1.0, 0.5)
	text_tween.tween_property(sub_label, "modulate:a", 1.0, 0.3)
	text_tween.tween_property(countdown_label, "modulate:a", 1.0, 0.3)
	text_tween.tween_property(evac_label, "modulate:a", 1.0, 0.3)
	
	status_label.text = "Initiating facility collapse sequence..."
	
	# Flash evac label
	_flash_evac()

func _on_countdown_tick(seconds_left: float) -> void:
	countdown_label.text = "%d" % ceil(seconds_left)
	
	# Warna countdown berubah seiring waktu
	if seconds_left <= 10.0:
		countdown_label.modulate = Color("#E8593C")
		countdown_label.scale = Vector2(1.2, 1.2)  # lebih besar saat kritis
	elif seconds_left <= 20.0:
		countdown_label.modulate = Color("#EF9F27")
	
	# Update status text
	if seconds_left > 25.0:
		status_label.text = "Disabling laser array..."
	elif seconds_left > 20.0:
		status_label.text = "Structural integrity compromised..."
	elif seconds_left > 15.0:
		status_label.text = "Initiating controlled collapse..."
	elif seconds_left > 10.0:
		status_label.text = "⚠ FACILITY COLLAPSE IMMINENT"
		status_label.modulate = Color("#E8593C")
	elif seconds_left > 5.0:
		status_label.text = "⚠ GET OUT NOW"
		status_label.modulate = Color("#E8593C")
	else:
		status_label.text = "TOO LATE"
		status_label.modulate = Color("#E8593C")

func _on_collapse() -> void:
	_is_active = false
	countdown_label.text = "0"
	status_label.text = "FACILITY COLLAPSED"
	
	# Fade ke hitam total
	var tween = create_tween()
	tween.tween_property(background, "color",
		Color(0.0, 0.0, 0.0, 1.0), 1.5)

func _flash_evac() -> void:
	var tween = create_tween()
	tween.set_loops(15)
	tween.tween_property(evac_label, "modulate:a", 0.1, 0.4)
	tween.tween_property(evac_label, "modulate:a", 1.0, 0.4)

func _glitch_text() -> void:
	# Random glitch pada SYSTEM//ADMIN label
	if randf() < 0.3:
		var glitch_chars = ["S̷", "Y̷", "S̷T̷", "//", "ADMIN"]
		var random_text = glitch_chars[randi() % glitch_chars.size()]
		sysadmin_label.text = "SYSTEM%s//ADMIN" % random_text
		await get_tree().create_timer(0.05).timeout
		sysadmin_label.text = "SYSTEM//ADMIN"
