# Main — composición del vertical slice (SPEC_02 §4, §6, §10, §11, §17)
# Blockout con primitivas: lobby, pasillo con estrechamiento, 3 salas
# (una cerrada con llave), escalera con rellano, NPC y 6 interactuables.
extends Node3D

const WALL_H := 2.6
const T := 0.24

var player: Poc02Player
var hud: Poc02Hud
var nav_region: NavigationRegion3D
var ceilings := {}          # room_id -> MeshInstance3D
var profiles := {}          # room_id -> CameraProfile
var _target: Node = null
var _amb: AudioStreamPlayer
var _step_sfx: AudioStreamPlayer3D


func _enter_tree() -> void:
	_setup_input_map()      # INP-001: acciones nombradas definidas por código


func _ready() -> void:
	add_to_group("audio_root")
	_setup_environment()
	_setup_profiles()
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)
	_build_floor_blockout()
	_build_interactables()
	_setup_player_and_npc()
	_setup_room_volumes()
	_setup_audio()
	hud = Poc02Hud.new()
	hud.player = player
	add_child(hud)
	# Bake de navegación en runtime tras montar la geometría (NPC-001)
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh.call_deferred(false)


func _setup_input_map() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"interact": [KEY_E], "inventory": [KEY_I, KEY_TAB],
		"camera_recenter": [KEY_R], "pause": [KEY_ESCAPE],
		"save_game": [KEY_F5], "load_game": [KEY_F9], "reset_game": [KEY_F10],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in keys[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)
	for action in [["camera_zoom_in", MOUSE_BUTTON_WHEEL_UP], ["camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(action[0]):
			InputMap.add_action(action[0])
			var ev := InputEventMouseButton.new()
			ev.button_index = action[1]
			InputMap.action_add_event(action[0], ev)


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.83, 1.0)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true       # única luz con sombra (ART-004)
	add_child(sun)


func _setup_profiles() -> void:
	profiles = {
		"lobby": CameraProfile.new(),
		"corridor": CameraProfile.make({"max_distance": 3.0, "default_distance": 2.6, "min_pitch_deg": -10.0}),
		"room_a": CameraProfile.make({"max_distance": 3.5, "default_distance": 3.0}),
		"room_b": CameraProfile.make({"default_distance": 4.0}),
		"room_c": CameraProfile.make({"max_distance": 6.0, "default_distance": 5.0}),
	}


func _box_mesh_body(center: Vector3, size: Vector3, color: Color, fadeable: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1 | 2      # mundo + bloqueador de cámara (OCC-006)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if fadeable else BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.material_override = mat        # material por instancia (OCC-003)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if fadeable:
		body.add_to_group("camera_fadeable")
	nav_region.add_child(body)
	return body


func _wall(cx: float, cz: float, w: float, d: float, fadeable := false) -> void:
	_box_mesh_body(Vector3(cx, WALL_H / 2.0, cz), Vector3(w, WALL_H, d),
		Color(0.55, 0.6, 0.68), fadeable)


func _build_floor_blockout() -> void:
	# Suelo (solo capa 1: la cámara no colisiona con él)
	var floor_body := _box_mesh_body(Vector3(0, -0.1, -1.5), Vector3(12.6, 0.2, 19.8),
		Color(0.42, 0.36, 0.3), false)
	floor_body.collision_layer = 1
	# Lobby (10×8, z 0..8)
	_wall(0, 8, 10.5, T)
	_wall(-5, 4, T, 8.5)
	_wall(5, 4, T, 8.5)
	_wall(-3, 0, 4, T)
	_wall(3, 0, 4, T)
	# Pasillo (x −1..1, z −6..0) con huecos de puerta y estrechamiento
	_wall(-1, -4, T, 4, true)
	_wall(-1, -0.5, T, 1, true)
	_wall(1, -5.5, T, 1, true)
	_wall(1, -2, T, 4, true)
	_wall(-0.75, -2.5, 0.28, 1.2)     # estrechamiento (§4.1)
	_wall(0.75, -2.5, 0.28, 1.2)
	# Sala A (este, pequeña)
	_wall(3.5, -6, 5, T)
	_wall(6, -3.5, T, 5)
	_wall(3.5, -1, 5, T, true)
	# Sala B (oeste)
	_wall(-3.5, -6, 5, T)
	_wall(-6, -3.5, T, 5)
	_wall(-3.5, -1, 5, T, true)
	# Sala C (norte, cerrada con llave)
	_wall(-3, -8.5, T, 5)
	_wall(3, -8.5, T, 5)
	_wall(0, -11, 6.5, T)
	_wall(-1.8, -6, 2.4, T, true)
	_wall(1.8, -6, 2.4, T, true)
	# Techos por sala (OCC-005)
	var ceil_defs := {
		"lobby": [Vector3(0, WALL_H, 4), Vector3(10.5, 0.15, 8.5)],
		"corridor": [Vector3(0, WALL_H, -3), Vector3(2.3, 0.15, 6.3)],
		"room_a": [Vector3(3.5, WALL_H, -3.5), Vector3(5.2, 0.15, 5.2)],
		"room_b": [Vector3(-3.5, WALL_H, -3.5), Vector3(5.2, 0.15, 5.2)],
		"room_c": [Vector3(0, WALL_H, -8.5), Vector3(6.5, 0.15, 5.2)],
	}
	for rid in ceil_defs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = ceil_defs[rid][1]
		mi.mesh = bm
		mi.position = ceil_defs[rid][0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.37, 0.42)
		mi.material_override = mat
		add_child(mi)             # sin colisión: solo visual
		ceilings[rid] = mi
	# Escalera con rellano (§4.1): peldaños visuales + rampa de colisión
	for i in 6:
		_box_mesh_body(Vector3(4, 0.1 + i * 0.2, 3.2 + i * 0.4), Vector3(1.6, 0.2, 0.4),
			Color(0.5, 0.44, 0.36), false).collision_layer = 0
	var ramp := _box_mesh_body(Vector3(4, 0.5, 4.2), Vector3(1.6, 0.18, 2.9),
		Color(1, 1, 1, 0), false)
	ramp.rotation.x = -atan2(1.2, 2.4)
	ramp.get_node("Mesh").visible = false
	ramp.collision_layer = 1
	_box_mesh_body(Vector3(4, 1.15, 6.4), Vector3(2.0, 0.15, 2.0), Color(0.5, 0.44, 0.36), false)
	# Mesa de la sala B (soporte de la llave)
	_box_mesh_body(Vector3(-3.5, 0.4, -3.5), Vector3(1.4, 0.8, 0.8), Color(0.5, 0.35, 0.22), false)
	# Pedestal recompensa en la sala C
	_box_mesh_body(Vector3(0, 0.5, -9), Vector3(0.6, 1.0, 0.6), Color(0.75, 0.62, 0.2), false)


func _interactable(kind: int, id: String, pos: Vector3, size: Vector3, color: Color) -> Interactable:
	var it := Interactable.new()
	it.kind = kind
	it.id = id
	it.position = pos
	it.collision_layer = 1 | 2
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	it.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	nav_region.add_child(it)
	return it


func _build_interactables() -> void:
	# Llave sobre la mesa de la sala B
	var key := _interactable(Interactable.Kind.KEY, "room_key", Vector3(-3.5, 0.9, -3.5),
		Vector3(0.3, 0.12, 0.15), Color(0.95, 0.8, 0.2))
	key.collision_layer = 0
	# Puerta cerrada de la sala C (bisagra en el borde, mesh desplazado)
	var door := Interactable.new()
	door.kind = Interactable.Kind.DOOR
	door.id = "door_c"
	door.position = Vector3(-0.6, 0, -6)
	door.collision_layer = 1 | 2
	var dm := MeshInstance3D.new()
	dm.name = "Mesh"
	var dbm := BoxMesh.new()
	dbm.size = Vector3(1.2, 2.2, 0.12)
	dm.mesh = dbm
	dm.position = Vector3(0.6, 1.1, 0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.42, 0.26, 0.15)
	dm.material_override = dmat
	door.add_child(dm)
	var dcs := CollisionShape3D.new()
	var dsh := BoxShape3D.new()
	dsh.size = Vector3(1.2, 2.2, 0.12)
	dcs.shape = dsh
	dcs.position = Vector3(0.6, 1.1, 0)
	door.add_child(dcs)
	nav_region.add_child(door)
	door.interaction_completed.connect(func(_id): _play_at(door.global_position, 180.0, 0.35, true))
	# Interruptor del lobby + luz vinculada
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.3, 4)
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.visible = false
	add_child(light)
	var sw := _interactable(Interactable.Kind.SWITCH, "lobby_light", Vector3(-4.8, 1.2, 2),
		Vector3(0.12, 0.2, 0.12), Color(0.9, 0.9, 0.9))
	sw.linked_light = sw.get_path_to(light)
	sw.sync_from_state()
	# Foto inspeccionable en la sala A (INS-001)
	_interactable(Interactable.Kind.NOTICE, "photo", Vector3(5.8, 1.4, -3.5),
		Vector3(0.08, 0.6, 0.8), Color(0.8, 0.7, 0.5))
	# Máquina expendedora en el lobby
	var vend := _interactable(Interactable.Kind.VENDING, "vending", Vector3(4.3, 0.8, 0.5),
		Vector3(0.8, 1.6, 0.6), Color(0.75, 0.2, 0.2))
	vend.interaction_completed.connect(func(_id): _play_at(vend.global_position, 880.0, 0.15, false))
	# Escalera: interactuable de transición en la base (modo TRANSITION)
	var st := _interactable(Interactable.Kind.STAIR, "stair", Vector3(3.2, 0.5, 2.6),
		Vector3(0.3, 1.0, 0.3), Color(0.4, 0.7, 0.9))
	st.stair_target = Vector3(4, 1.3, 6.4)


func _setup_player_and_npc() -> void:
	player = Poc02Player.new()
	player.position = Vector3(0, 0.1, 5)
	add_child(player)
	player.stepped.connect(func(): _play_step())
	var npc := ResidentNpc.new()
	npc.position = Vector3(-2, 0.1, 5)
	npc.waypoints = [Vector3(-2, 0, 5), Vector3(0, 0, -4.5), Vector3(-3.5, 0, -2.5)]
	add_child(npc)


func _setup_room_volumes() -> void:
	var vols := {
		"lobby": [Vector3(0, 1.5, 4), Vector3(10, 3, 8)],
		"corridor": [Vector3(0, 1.5, -3), Vector3(2, 3, 6)],
		"room_a": [Vector3(3.5, 1.5, -3.5), Vector3(5, 3, 5)],
		"room_b": [Vector3(-3.5, 1.5, -3.5), Vector3(5, 3, 5)],
		"room_c": [Vector3(0, 1.5, -8.5), Vector3(6, 3, 5)],
	}
	for rid in vols:
		var area := Area3D.new()
		area.position = vols[rid][0]
		area.collision_mask = 4          # solo detecta al jugador (ROOM-001)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = vols[rid][1]
		cs.shape = sh
		area.add_child(cs)
		add_child(area)
		area.body_entered.connect(func(body):
			if body is Poc02Player:
				_enter_room(rid))


func _enter_room(rid: String) -> void:
	GameState.set_room(rid)
	player.set_profile(profiles[rid])
	for r in ceilings:
		ceilings[r].visible = not (r == rid and profiles[rid].hide_ceiling)
	print("[ROOM] ", rid)


# --- Selección de interactuable más cercano y prompt (INT-001) ---
func _physics_process(_delta: float) -> void:
	if hud == null or player.cam_mode != Poc02Player.CamMode.FREE or hud.start_overlay.visible:
		if _target:
			_target.set_highlight(false)
			_target = null
		if hud:
			hud.set_prompt("")
		return
	var best: Node = null
	var best_d := player.interaction_distance
	for it in get_tree().get_nodes_in_group("interactable"):
		var d: float = player.global_position.distance_to(it.global_position)
		if d < best_d and it.can_interact():
			best = it
			best_d = d
	if _target and _target != best:
		_target.set_highlight(false)
	_target = best
	if _target:
		_target.set_highlight(true)
		hud.set_prompt("[E] " + _target.get_prompt())
	else:
		hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _target and player.cam_mode == Poc02Player.CamMode.FREE:
		_target.interact(player)


# --- Audio procedural (AUD-001..005): sin ficheros, WAV generados en código ---
func _tone(freq: float, secs: float, vol: float, noise: bool, do_loop := false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(secs * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := 1.0 if do_loop else 1.0 - float(i) / n
		var s := randf() * 2.0 - 1.0 if noise else sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	if do_loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w


func _setup_audio() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_amb = AudioStreamPlayer.new()
	_amb.stream = _tone(55.0, 2.0, 0.05, false, true)
	_amb.bus = "Music"
	add_child(_amb)
	_step_sfx = AudioStreamPlayer3D.new()
	_step_sfx.stream = _tone(0.0, 0.07, 0.25, true)
	_step_sfx.bus = "SFX"
	player.add_child(_step_sfx)


func unlock_audio() -> void:
	if not _amb.playing:
		_amb.play()          # solo tras gesto del usuario (AUD-001)


func _play_step() -> void:
	if _amb.playing:
		_step_sfx.pitch_scale = randf_range(0.8, 1.2)
		_step_sfx.play()


func _play_at(pos: Vector3, freq: float, secs: float, noise: bool) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _tone(freq, secs, 0.4, noise)
	p.bus = "SFX"
	p.position = pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
