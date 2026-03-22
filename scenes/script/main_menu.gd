extends Control

# Corrected paths to match your CanvasLayer nesting
@onready var main_buttons: VBoxContainer = $Background/CanvasLayer/MainButton
@onready var settings_popup: ColorRect = $Background/CanvasLayer/ColorRect
@onready var master_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/MasterVolume/VolumeSlider
@onready var sfx_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/SFXVolume/SFXSlider
@onready var music_slider: HSlider = $Background/CanvasLayer/ColorRect/VBoxContainer/MusicVolume/MusicSlider

func _ready() -> void:
	# Hide settings by default
	settings_popup.hide() 
	
	# Initialize slider using your AudioManager logic
	if has_node("res://scripts/audioManager.gd"):
		master_slider.value = AudioManager.volumes.master 
		sfx_slider.value = AudioManager.volumes.sfx 
		music_slider.value = AudioManager.volumes.music

func _on_start_button_pressed() -> void:
	set_process_input(false) 
	var tween = create_tween() 
	tween.tween_property(self, "modulate", Color(0, 0, 0, 1), 1.5) 
	
	await tween.finished 
	get_tree().change_scene_to_file("res://scenes/World.tscn") 

func _on_close_settings_pressed() -> void:
	settings_popup.hide() 
	# Re-enable main buttons
	main_buttons.process_mode = PROCESS_MODE_INHERIT

func _on_setting_button_pressed() -> void:
	settings_popup.show() 
	# Disable main buttons so they can't be clicked through the popup
	main_buttons.process_mode = PROCESS_MODE_DISABLED


func _on_master_slider_value_changed(value: float) -> void:
	AudioManager.set_master(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx(value) 

func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music(value)
