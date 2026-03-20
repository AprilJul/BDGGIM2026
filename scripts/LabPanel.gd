extends Node2D

@onready var area = $Area2D
var is_open: bool = false

func _ready() -> void:
	%PanelUI.visible = false
	area.add_to_group("interaction_panel")

	%BtnCraftExtractor.pressed.connect(func(): _on_craft("extractor_part"))
	%BtnCraftMCS.pressed.connect(func(): _on_craft("mcs_module"))
	%BtnCraftCoolant.pressed.connect(func(): _on_craft("coolant_kit"))
	%BtnCraftCPU.pressed.connect(func(): _on_craft("cpu_module"))
	%BtnCancel.pressed.connect(_on_cancel)
	%BtnCraftArmor.pressed.connect(func(): _on_craft("armor_patch"))

	GameManager.crafting_started.connect(_on_crafting_started)
	GameManager.crafting_completed.connect(_on_crafting_completed)
	GameManager.crafting_cancelled.connect(_on_crafting_cancelled)
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
func _process(_delta: float) -> void:
	if not is_open:
		return
	_update_ui()

	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y >= screen_h - 50:
		close_panel()

func _update_ui() -> void:
	_update_crafting_progress()
	_update_item_buttons()

func _update_crafting_progress() -> void:
	var is_crafting = GameManager.crafting_item != ""

	if is_crafting:
		# Update progress bar
		var progress = 1.0 - (GameManager.crafting_timer / GameManager.crafting_duration)
		%CraftingBar.value = progress
		%CraftingLabel.text = "CRAFTING: %s  (%.0fs)" % [
			_item_display_name(GameManager.crafting_item),
			GameManager.crafting_timer
		]
		%CraftingLabel.modulate = Color("#EF9F27")
		%BtnCancel.visible = true
	else:
		%CraftingBar.value = 0.0
		%CraftingLabel.text = "IDLE — select item to craft"
		%CraftingLabel.modulate = Color("#888780")
		%BtnCancel.visible = false

func _update_item_buttons() -> void:
	var is_crafting = GameManager.crafting_item != ""

	# Update stock labels
	%ExtractorStock.text = "Stock: %d" % GameManager.inv_extractor_part
	%MCSStock.text = "Stock: %d" % GameManager.inv_mcs_module
	%CoolantStock.text = "Stock: %d" % GameManager.inv_coolant_kit
	%CPUStock.text = "Stock: %d" % GameManager.inv_cpu_module
	%ArmorStock.text = "Stock: %d" % GameManager.inv_armor_patch

	# Warna stock label — hijau kalau ada, abu kalau kosong
	%ExtractorStock.modulate = Color("#3B9E7A") if GameManager.inv_extractor_part > 0 else Color("#888780")
	%MCSStock.modulate = Color("#3B9E7A") if GameManager.inv_mcs_module > 0 else Color("#888780")
	%CoolantStock.modulate = Color("#3B9E7A") if GameManager.inv_coolant_kit > 0 else Color("#888780")
	%CPUStock.modulate = Color("#3B9E7A") if GameManager.inv_cpu_module > 0 else Color("#888780")
	%ArmorStock.modulate = Color("#3B9E7A") \
		if GameManager.inv_armor_patch > 0 else Color("#888780")

	# Disable semua tombol craft kalau sedang ada crafting
	%BtnCraftExtractor.disabled = is_crafting
	%BtnCraftMCS.disabled = is_crafting
	%BtnCraftCoolant.disabled = is_crafting
	%BtnCraftCPU.disabled = is_crafting
	%BtnCraftArmor.disabled = is_crafting

	# Highlight tombol yang relevan — item yang dibutuhkan saat ini
	_highlight_needed_items()

func _highlight_needed_items() -> void:
	# Highlight merah kalau sistem rusak dan belum ada stock
	%BtnCraftExtractor.modulate = Color("#E8593C") \
		if GameManager.extractor_broken and GameManager.inv_extractor_part == 0 \
		else Color.WHITE
	%BtnCraftMCS.modulate = Color("#E8593C") \
		if GameManager.mcs_broken and GameManager.inv_mcs_module == 0 \
		else Color.WHITE
	%BtnCraftCoolant.modulate = Color("#E8593C") \
		if GameManager.coolant_pump_broken and GameManager.inv_coolant_kit == 0 \
		else Color.WHITE
	%BtnCraftArmor.modulate = Color("#E8593C") \
		if GameManager.armor_hp < 50.0 and GameManager.inv_armor_patch == 0 \
		else Color.WHITE

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_craft(item: String) -> void:
	await get_tree().create_timer(GameManager.input_delay).timeout
	GameManager.start_craft(item)

func _on_cancel() -> void:
	GameManager.cancel_craft()

# ============================================================
# SIGNAL HANDLERS
# ============================================================
func _on_crafting_started(item: String, _duration: float) -> void:
	print("Lab UI: crafting started — ", item)

func _on_crafting_completed(item: String) -> void:
	print("Lab UI: crafting done — ", item)
	# Flash stock label yang baru bertambah
	var stock_label = _get_stock_label(item)
	if stock_label:
		var tween = create_tween()
		tween.tween_property(stock_label, "modulate", Color("#3B9E7A"), 0.1)
		tween.tween_property(stock_label, "modulate", Color.WHITE, 0.3)

func _on_crafting_cancelled(item: String) -> void:
	print("Lab UI: crafting cancelled — ", item)

func _on_mcs_state_changed(is_active: bool) -> void:
	%BtnCraftExtractor.disabled = is_active
	%BtnCraftMCS.disabled = is_active
	%BtnCraftCoolant.disabled = is_active
	%BtnCraftCPU.disabled = is_active

# ============================================================
# HELPERS
# ============================================================
func _item_display_name(item: String) -> String:
	match item:
		"extractor_part": return "Extractor Part"
		"mcs_module": return "MCS Module"
		"coolant_kit": return "Coolant Kit"
		"cpu_module": return "CPU Module"
		"armor_patch": return "Armor Patch"
		_: return item

func _get_stock_label(item: String) -> Label:
	match item:
		"extractor_part": return %ExtractorStock
		"mcs_module": return %MCSStock
		"coolant_kit": return %CoolantStock
		"cpu_module": return %CPUStock
		"armor_patch": return %ArmorStock
		_: return null
