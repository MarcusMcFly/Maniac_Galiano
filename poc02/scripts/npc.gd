# NPC residente — NavigationAgent3D + máquina de estados IDLE/WALK/TALK/RETURN
# (SPEC_02 §13 NPC-001..005) y diálogo con opción condicionada (§15.1 DIA-001..003)
class_name ResidentNpc
extends CharacterBody3D

enum State { IDLE, WALK, TALK, RETURN }

@export var speed := 2.0
@export var waypoints: Array[Vector3] = []

var state: int = State.IDLE
var agent: NavigationAgent3D
var _wp := 0
var _idle_left := 1.5

var dialogue := {
	"start": {
		"speaker": "Residente",
		"text": "Hola. Ando buscando la llave de la habitación del fondo…",
		"options": [
			{"text": "¿Dónde la viste por última vez?", "next": "hint"},
			{"text": "Ya tengo la llave.", "next": "have_key", "requires_item": "room_key"},
			{"text": "Adiós.", "next": ""},
		],
	},
	"hint": {
		"speaker": "Residente",
		"text": "Creo que estaba sobre la mesa de la sala oeste.",
		"options": [{"text": "Gracias.", "next": ""}],
	},
	"have_key": {
		"speaker": "Residente",
		"text": "¡Genial! Abre la puerta del fondo del pasillo.",
		"set_flag": "npc_hinted",
		"options": [{"text": "Voy.", "next": ""}],
	},
}


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")
	collision_layer = 1
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.5
	mi.mesh = cm
	mi.position.y = 0.85
	mi.name = "Mesh"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.55, 0.35)
	mi.material_override = mat
	add_child(mi)

	agent = NavigationAgent3D.new()
	agent.radius = 0.4
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 0.5
	add_child(agent)


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_idle_left -= delta
			if _idle_left <= 0.0 and waypoints.size() > 1:
				_wp = (_wp + 1) % waypoints.size()
				agent.target_position = waypoints[_wp]
				state = State.WALK
		State.WALK, State.RETURN:
			if agent.is_navigation_finished():
				velocity = Vector3.ZERO
				state = State.IDLE
				_idle_left = randf_range(2.0, 4.0)   # deja de pedir rutas: sin jitter (NPC-002)
				return
			var next := agent.get_next_path_position()
			var dir := (next - global_position)
			dir.y = 0.0
			velocity = dir.normalized() * speed
			if dir.length() > 0.1:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
			move_and_slide()
		State.TALK:
			velocity = Vector3.ZERO


# --- contrato interactable ---
func get_prompt() -> String:
	return "Hablar"


func can_interact() -> bool:
	return state != State.TALK


func interact(player: Node) -> void:
	state = State.TALK                          # NPC-004: el diálogo detiene la navegación
	var to_p: Vector3 = player.global_position - global_position
	rotation.y = atan2(to_p.x, to_p.z)
	player.enter_dialogue(self)
	get_tree().call_group("hud", "start_dialogue", self)


func end_dialogue(player: Node) -> void:
	player.exit_dialogue()
	state = State.RETURN                        # replanifica al terminar
	if not waypoints.is_empty():
		agent.target_position = waypoints[_wp]


func set_highlight(_on: bool) -> void:
	pass
