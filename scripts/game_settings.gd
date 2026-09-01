extends Node

var sound_enabled: bool = true
var selected_character_index: int = 0
var selected_map_index: int = 0

const USER_ERROR_MSG := "Connection/Network Issue. Try again."
const SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	if OS.has_feature("web"):
		var saved := BrowserBridge.storage_get("sound_enabled")
		if saved != "":
			sound_enabled = saved == "1"
		var saved_char := BrowserBridge.storage_get("selected_character_index")
		if saved_char != "":
			selected_character_index = int(saved_char)
		var saved_map := BrowserBridge.storage_get("selected_map_index")
		if saved_map != "":
			selected_map_index = int(saved_map)
	else:
		load_settings()
	apply_sound()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		sound_enabled = config.get_value("settings", "sound_enabled", sound_enabled)
		selected_character_index = config.get_value("settings", "selected_character_index", selected_character_index)
		selected_map_index = config.get_value("settings", "selected_map_index", selected_map_index)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "sound_enabled", sound_enabled)
	config.set_value("settings", "selected_character_index", selected_character_index)
	config.set_value("settings", "selected_map_index", selected_map_index)
	config.save(SAVE_PATH)


func set_selected_character(index: int) -> void:
	selected_character_index = index
	if OS.has_feature("web"):
		BrowserBridge.storage_set("selected_character_index", str(index))
	else:
		save_settings()


func set_selected_map(index: int) -> void:
	selected_map_index = index
	if OS.has_feature("web"):
		BrowserBridge.storage_set("selected_map_index", str(index))
	else:
		save_settings()


const MASTER_VOLUME_DB: float = 6.0


func apply_sound() -> void:
	AudioServer.set_bus_mute(0, not sound_enabled)
	if sound_enabled:
		AudioServer.set_bus_volume_db(0, MASTER_VOLUME_DB)
	else:
		AudioServer.set_bus_volume_db(0, 0.0)


func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if OS.has_feature("web"):
		BrowserBridge.storage_set("sound_enabled", "1" if sound_enabled else "0")
		if sound_enabled:
			BrowserBridge.unlock_web_audio()
	else:
		save_settings()
	apply_sound()
