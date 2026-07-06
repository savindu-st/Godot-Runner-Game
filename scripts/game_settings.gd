extends Node

var sound_enabled: bool = true

const USER_ERROR_MSG := "Connection/Network Issue. Try again."


func _ready() -> void:
	if OS.has_feature("web"):
		var saved := BrowserBridge.storage_get("sound_enabled")
		if saved != "":
			sound_enabled = saved == "1"
	apply_sound()


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
	apply_sound()
