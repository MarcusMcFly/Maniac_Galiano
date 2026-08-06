# Interactable — contrato get_prompt/can_interact/interact (SPEC_02 §12 INT-001..005)
# Un único script con `kind` para los 6 tipos requeridos de la tabla 12.1.
class_name Interactable
extends StaticBody3D

enum Kind { KEY, DOOR, SWITCH, NOTICE, VENDING, STAIR }

signal interaction_completed(id: String)

@export var kind: Kind = Kind.KEY
@export var id := ""
@export var linked_light: NodePath      # SWITCH
@export var stair_target := Vector3.ZERO  # STAIR: destino del teletransporte

var mesh: MeshInstance3D
var _door_open := false
var _highlighted := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("saveable")
	mesh = get_node_or_null("Mesh")
	sync_from_state()


func get_prompt() -> String:
	match kind:
		Kind.KEY:
			return "Coger la llave"
		Kind.DOOR:
			if GameState.get_flag(id + "_unlocked"):
				return "Cerrar la puerta" if _door_open else "Abrir la puerta"
			return "Usar la llave" if GameState.has_item("room_key") else "Cerrada con llave"
		Kind.SWITCH:
			return "Apagar la luz" if GameState.get_flag(id + "_on") else "Encender la luz"
		Kind.NOTICE:
			return "Inspeccionar la foto"
		Kind.VENDING:
			return "Usar la máquina"
		Kind.STAIR:
			return "Usar la escalera"
	return "Interactuar"


func can_interact() -> bool:
	if kind == Kind.KEY and GameState.get_flag(id + "_taken"):
		return false
	if kind == Kind.DOOR and not GameState.get_flag(id + "_unlocked") \
			and not GameState.has_item("room_key"):
		return false            # el prompt informa, pero no hay acción válida
	return true


func interact(player: Node) -> void:
	match kind:
		Kind.KEY:
			GameState.add_item("room_key")
			GameState.set_flag(id + "_taken", true)
			sync_from_state()
		Kind.DOOR:
			if not GameState.get_flag(id + "_unlocked"):
				GameState.set_flag(id + "_unlocked", true)
				print("[INTERACTION] puerta %s desbloqueada con la llave" % id)
			else:
				GameState.set_flag(id + "_open", not _door_open)
			sync_from_state()
		Kind.SWITCH:
			GameState.set_flag(id + "_on", not GameState.get_flag(id + "_on"))
			sync_from_state()
		Kind.NOTICE:
			GameState.set_flag(id + "_inspected", true)
			get_tree().call_group("hud", "show_inspection", self)
		Kind.VENDING:
			GameState.set_flag(id + "_used", true)
			get_tree().call_group("hud", "show_toast", "La máquina zumba… sale un refresco.")
			GameState.add_item("soda")
		Kind.STAIR:
			get_tree().call_group("hud", "show_toast", "Subes por la escalera.")
			player.cam_mode = player.CamMode.TRANSITION
			var tw := create_tween()
			tw.tween_property(player, "global_position", stair_target, 0.6) \
				.set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func() -> void: player.cam_mode = player.CamMode.FREE)
	interaction_completed.emit(id)


# Restaura el estado visual/colisión desde GameState (para load y flags)
func sync_from_state() -> void:
	match kind:
		Kind.KEY:
			var taken := GameState.get_flag(id + "_taken")
			visible = not taken
			set_collision_layer_value(1, not taken)
		Kind.DOOR:
			_door_open = GameState.get_flag(id + "_open")
			rotation.y = -PI / 2.0 * (1.0 if _door_open else 0.0)
			set_collision_layer_value(1, not _door_open)
			set_collision_layer_value(2, not _door_open)
		Kind.SWITCH:
			var l: Light3D = get_node_or_null(linked_light)
			if l:
				l.visible = GameState.get_flag(id + "_on")


func set_highlight(on: bool) -> void:
	if _highlighted == on or mesh == null or mesh.material_override == null:
		return
	_highlighted = on
	mesh.material_override.emission_enabled = on
	if on:
		mesh.material_override.emission = Color(0.3, 0.5, 0.9)
		mesh.material_override.emission_energy_multiplier = 0.6
