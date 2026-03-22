extends Node2D

@onready var area = $Area2D
var is_open: bool = false

# Replace timers per CPU (15 detik)
var replace_timers: Array = [-1.0, -1.0, -1.0, -1.0]
const REPLACE_DURATION: float = 15.0

# Arrays referensi node
var temp_bars: Array = []
var temp_labels: Array = []
var status_labels: Array = []
var replace_buttons: Array = []
var replace_statuses: Array = []

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")

	# Kumpulkan referensi node
	temp_bars = [%CPU1TempBar, %CPU2TempBar, %CPU3TempBar, %CPU4TempBar]
	temp_labels = [%CPU1TempLabel, %CPU2TempLabel, %CPU3TempLabel, %CPU4TempLabel]
	status_labels = [%CPU1StatusLabel, %CPU2StatusLabel, %CPU3StatusLabel, %CPU4StatusLabel]
	replace_buttons = [%BtnReplaceCPU1, %BtnReplaceCPU2, %BtnReplaceCPU3, %BtnReplaceCPU4]
	replace_statuses = [%CPU1ReplaceStatus, %CPU2ReplaceStatus, %CPU3ReplaceStatus, %CPU4ReplaceStatus]

	for i in range(4):
		var idx = i
		replace_buttons[i].pressed.connect(func(): _on_replace(idx))
		temp_bars[i].max_value = 100.0

	GameManager.cpu_failed.connect(_on_cpu_failed)
	GameManager.cpu_module_replaced.connect(_on_cpu_replaced)
	GameManager.mcs_state_changed.connect(_on_mcs_state_changed)

# ============================================================
# OPEN / CLOSE
# ============================================================
func open_panel() -> void:
	is_open = true
	GameManager.is_in_panel_mode = true
	%PanelUI.visible = true
	var viewport_size = get_viewport().get_visible_rect().size
	%PanelContainer.position = (viewport_size - %PanelContainer.size) / 2.0
	_zoom_in()

func close_panel() -> void:
	is_open = false
	GameManager.is_in_panel_mode = false
	%PanelUI.visible = false
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
# UPDATE
# ============================================================
func _process(delta: float) -> void:
	if not is_open:
		return
	_update_replace_timers(delta)
	_update_ui()

	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_replace_timers(delta: float) -> void:
	for i in range(4):
		if replace_timers[i] > 0.0:
			replace_timers[i] -= delta
			if replace_timers[i] <= 0.0:
				replace_timers[i] = -1.0
				GameManager.complete_cpu_replace(i)

func _update_ui() -> void:
	for i in range(4):
		var temp = GameManager.cpu_temps[i]
		var broken = GameManager.cpu_broken_states[i]
		var replacing = replace_timers[i] > 0.0

		# Temp bar
		temp_bars[i].value = temp
		temp_labels[i].text = "%.0f°C" % temp

		if broken:
			temp_bars[i].modulate = Color("#444441")
			temp_labels[i].modulate = Color("#888780")
		elif temp > 80.0:
			temp_bars[i].modulate = Color("#E8593C")
			temp_labels[i].modulate = Color("#E8593C")
		elif temp > 65.0:
			temp_bars[i].modulate = Color("#EF9F27")
			temp_labels[i].modulate = Color("#EF9F27")
		else:
			temp_bars[i].modulate = Color.WHITE
			temp_labels[i].modulate = Color.WHITE

		# Status
		if broken and not replacing:
			status_labels[i].text = "⚠ FAILED"
			status_labels[i].modulate = Color("#E8593C")
		elif replacing:
			var progress = (1.0 - replace_timers[i] / REPLACE_DURATION) * 100
			status_labels[i].text = "🔧 REPLACING %.0f%%" % progress
			status_labels[i].modulate = Color("#EF9F27")
		elif GameManager.cpu_failure_timers[i] > 0.0:
			status_labels[i].text = "⚠ OVERHEATING"
			status_labels[i].modulate = Color("#E8593C")
		elif temp > 65.0:
			status_labels[i].text = "▶ THROTTLING"
			status_labels[i].modulate = Color("#EF9F27")
		else:
			status_labels[i].text = "● NOMINAL"
			status_labels[i].modulate = Color("#3B9E7A")

		# Replace button
		var can_replace = broken and \
			not replacing and \
			GameManager.inv_cpu_module > 0
		replace_buttons[i].disabled = not can_replace
		replace_buttons[i].text = "REPLACE" if not replacing else "REPLACING..."

		if replacing:
			replace_statuses[i].text = "%.0fs remaining" % replace_timers[i]
			replace_statuses[i].modulate = Color("#EF9F27")
		elif broken:
			replace_statuses[i].text = "Need CPU module"
			replace_statuses[i].modulate = Color("#888780")
		else:
			replace_statuses[i].text = ""

	# Summary
	%DelayLabel.text = "INPUT DELAY: %.1fs" % GameManager.input_delay
	%DelayLabel.modulate = Color("#E8593C") if GameManager.input_delay > 1.0 \
		else Color("#EF9F27") if GameManager.input_delay > 0.3 \
		else Color("#3B9E7A")
	%ModuleStockLabel.text = "CPU Modules: %d" % GameManager.inv_cpu_module
	%ModuleStockLabel.modulate = Color("#3B9E7A") \
		if GameManager.inv_cpu_module > 0 else Color("#888780")

# ============================================================
# HANDLERS
# ============================================================
func _on_replace(index: int) -> void:
	if GameManager.inv_cpu_module <= 0:
		return
	if not GameManager.cpu_broken_states[index]:
		return
	if replace_timers[index] > 0.0:
		return
	GameManager.replace_cpu_module(index)
	replace_timers[index] = REPLACE_DURATION
	print("Started replacing CPU %d" % (index + 1))

func _on_cpu_failed(index: int) -> void:
	# Flash status saat CPU fail
	var tween = create_tween()
	tween.set_loops(4)
	tween.tween_property(status_labels[index], "modulate:a", 0.1, 0.15)
	tween.tween_property(status_labels[index], "modulate:a", 1.0, 0.15)

func _on_cpu_replaced(index: int) -> void:
	replace_statuses[index].text = "✓ REPLACED"
	replace_statuses[index].modulate = Color("#3B9E7A")

func _on_mcs_state_changed(is_active: bool) -> void:
	for btn in replace_buttons:
		btn.disabled = is_active
