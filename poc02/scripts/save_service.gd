# Autoload SaveService — persistencia en user:// con schema versionado (SPEC_02 §19)
extends Node

const SAVE_PATH := "user://poc02_save.json"
const SCHEMA_VERSION := 1


func is_persistent() -> bool:
	return OS.is_userfs_persistent()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(player: Node) -> bool:
	var cam: Dictionary = player.get_camera_state()
	var data := {
		"schema_version": SCHEMA_VERSION,
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.visual_yaw(),
		},
		"camera": cam,
		"inventory": GameState.inventory,
		"flags": GameState.flags,
		"room_id": GameState.room_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SAVE] no se pudo abrir %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data))
	print("[SAVE] guardado")
	return true


func load_game(player: Node) -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		push_warning("[SAVE] schema incompatible, se ignora")
		return false
	GameState.flags = data.get("flags", {})
	GameState.inventory = data.get("inventory", [])
	GameState.room_id = str(data.get("room_id", "lobby"))
	var p: Array = data.get("player", {}).get("position", [0, 0, 4])
	player.apply_saved_state(Vector3(p[0], p[1], p[2]),
		float(data.get("player", {}).get("rotation_y", 0.0)), data.get("camera", {}))
	get_tree().call_group("saveable", "sync_from_state")
	GameState.inventory_changed.emit()
	GameState.room_changed.emit(GameState.room_id)
	print("[SAVE] cargado")
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
	print("[SAVE] borrado")
