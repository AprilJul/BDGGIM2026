extends Control

# Corrected paths to match your CanvasLayer nesting
@onready var main_buttons: VBoxContainer = $Background/CanvasLayer/MainButton
@onready var settings_popup: ColorRect = $Background/CanvasLayer/ColorRect
@onready var master_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/SliderContainer/MasterVolume/MasterSlider
@onready var sfx_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/SliderContainer/SFXVolume/SFXSlider
@onready var music_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/SliderContainer/MusicVolume/MusicSlider
@onready var dialogue_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/SliderContainer/DialogueVolume/DialogueSlider
@onready var click_sfx: AudioStreamPlayer = $ClickSound
@onready var fade_overlay: ColorRect = $Background/CanvasLayer/FadeOverlay

func _ready() -> void:
	# Hide settings by default
	settings_popup.hide() 
	
	
	# Initialize slider using your AudioManager logic
	if has_node("res://scripts/audioManager.gd"):
		master_slider.value = AudioManager.volumes.master 
		sfx_slider.value = AudioManager.volumes.sfx 
		music_slider.value = AudioManager.volumes.music
		dialogue_slider.value = AudioManager.volumes.dialogue

func _on_start_button_pressed() -> void:
	click_sfx.play()
	set_process_input(false)
	main_buttons.process_mode = PROCESS_MODE_DISABLED  # prevent double-click during fade

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_overlay, "color:a", 1.0, 3.0)

	await tween.finished
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_close_settings_pressed() -> void:
	settings_popup.hide() 
	# Re-enable main buttons
	main_buttons.process_mode = PROCESS_MODE_INHERIT
	click_sfx.play()

func _on_setting_button_pressed() -> void:
	settings_popup.show() 
	# Disable main buttons so they can't be clicked through the popup
	main_buttons.process_mode = PROCESS_MODE_DISABLED
	click_sfx.play()

func _on_master_slider_value_changed(value: float) -> void:
	AudioManager.set_master(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx(value) 

func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music(value)

func _on_dialogue_slider_value_changed(value: float) -> void:
	AudioManager.set_dialogue(value)
