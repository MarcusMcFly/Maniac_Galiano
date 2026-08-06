# Autoload GameState — flags de puzzle, inventario, sala actual (SPEC_02 §6.1)
extends Node

signal flag_changed(flag: String, value: bool)
signal inventory_changed
signal room_changed(room_id: String)

var flags := {}
var inventory := []
var selected_item := ""
var room_id := "lobby"


func set_flag(f: String, v: bool) -> void:
	flags[f] = v
	flag_changed.emit(f, v)


func get_flag(f: String) -> bool:
	return flags.get(f, false)


func add_item(id: String) -> void:
	if not inventory.has(id):
		inventory.append(id)
		inventory_changed.emit()


func remove_item(id: String) -> void:
	inventory.erase(id)
	if selected_item == id:
		selected_item = ""
	inventory_changed.emit()


func has_item(id: String) -> bool:
	return inventory.has(id)


func set_room(id: String) -> void:
	if room_id != id:
		room_id = id
		room_changed.emit(id)


func reset() -> void:
	flags.clear()
	inventory.clear()
	selected_item = ""
	room_id = "lobby"
	inventory_changed.emit()
