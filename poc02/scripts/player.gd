# Player — CharacterBody3D + rig YawPivot/PitchPivot/SpringArm3D/Camera3D
# (SPEC_02 §7 PLY-001..004, §8 CAM-GD-001..005, §9 OCC-001..006)
class_name Poc02Player
extends CharacterBody3D

enum CamMode { FREE, DIALOGUE, INSPECTION, TRANSITION, PAUSED }

@export var walk_speed := 3.2
@export var acceleration := 14.0
@export var rotation_speed_deg := 540.0
@export var gravity := 14.0
@export var mouse_sensitivity := 0.0025
@export var interaction_distance := 2.2

var cam_mode: int = CamMode.FREE
var profile: CameraProfile = CameraProfile.new()
var preferred_distance := 4.5
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var visual: Node3D
var _recentering := false
var _fade_timers := {}          # mesh -> tiempo de oclusión acumulado (histéresis OCC-004)
var _dialogue_target: Node3D = null
var _step_accum := 0.0

signal stepped                  # para audio de pasos


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4          # capa propia: excluida de la máscara de la cámara (CAM-GD-003)
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	visual = Node3D.new()
	add_child(visual)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.3
	bm.height = 1.5
	body.mesh = bm
	body.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.83, 0.35, 0.23)
	body.material_override = mat
	visual.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.1
	nm.height = 0.3
	nose.mesh = nm
	nose.rotation_degrees.x = -90
	nose.position = Vector3(0, 1.35, -0.35)
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(1.0, 0.81, 0.35)
	nose.material_override = nmat
	visual.add_child(nose)

	# Rig orbital (CAM-GD-001)
	yaw_pivot = Node3D.new()
	yaw_pivot.position.y = 1.4
	add_child(yaw_pivot)
	pitch_pivot = Node3D.new()
	yaw_pivot.add_child(pitch_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = preferred_distance
	spring.margin = 0.15
	spring.collision_mask = 2    # solo bloqueadores de cámara (CAM-GD-002)
	var ss := SphereShape3D.new()
	ss.radius = 0.25
	spring.shape = ss
	spring.add_excluded_object(get_rid())
	pitch_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.position.z = 0.0
	spring.add_child(camera)
	camera.current = true

	yaw_pivot.rotation.y = PI    # detrás del personaje
	pitch_pivot.rotation.x = -deg_to_rad(25.0)


func _unhandled_input(event: InputEvent) -> void:
	if cam_mode != CamMode.FREE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x - event.relative.y * mouse_sensitivity * 0.8,
			-deg_to_rad(profile.max_pitch_deg), -deg_to_rad(profile.min_pitch_deg))
		_recentering = false
	elif event.is_action_pressed("camera_zoom_in"):
		preferred_distance = clamp(preferred_distance - 0.5, profile.min_distance, profile.max_distance)
	elif event.is_action_pressed("camera_zoom_out"):
		preferred_distance = clamp(preferred_distance + 0.5, profile.min_distance, profile.max_distance)
	elif event.is_action_pressed("camera_recenter"):
		_recentering = true


func _physics_process(delta: float) -> void:
	if cam_mode == CamMode.FREE:
		_move(delta)
	elif cam_mode == CamMode.DIALOGUE and _dialogue_target:
		_frame_dialogue(delta)
	_update_camera(delta)
	_update_occlusion_fade(delta)


func _move(delta: float) -> void:
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := -camera.global_basis.z
	var right := camera.global_basis.x
	fwd.y = 0.0
	right.y = 0.0
	var desired := (right.normalized() * input_2d.x + fwd.normalized() * -input_2d.y)
	if desired.length() > 1.0:
		desired = desired.normalized()
	velocity.x = move_toward(velocity.x, desired.x * walk_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z * walk_speed, acceleration * delta)
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.5
	move_and_slide()

	var horiz := Vector2(velocity.x, velocity.z)
	if horiz.length() > 0.3:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		visual.rotation.y = rotate_toward(visual.rotation.y, target_yaw, deg_to_rad(rotation_speed_deg) * delta)
		_step_accum += horiz.length() * delta
		if _step_accum > 1.1 and is_on_floor():
			_step_accum = 0.0
			stepped.emit()


func _update_camera(delta: float) -> void:
	# Blending del perfil activo (CAM-GD-005, ROOM-003)
	var k := 1.0 - exp(-6.0 * delta)
	preferred_distance = clamp(preferred_distance, profile.min_distance, profile.max_distance)
	spring.spring_length = lerp(spring.spring_length, preferred_distance, k * 2.0)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x,
		-deg_to_rad(profile.max_pitch_deg), -deg_to_rad(profile.min_pitch_deg))
	if _recentering:
		var target := visual.rotation.y + PI
		yaw_pivot.rotation.y = rotate_toward(yaw_pivot.rotation.y, target,
			deg_to_rad(profile.recenter_speed_deg) * delta)
		if absf(angle_difference(yaw_pivot.rotation.y, target)) < 0.02:
			_recentering = false


func _frame_dialogue(delta: float) -> void:
	velocity = Vector3.ZERO
	var to_npc := _dialogue_target.global_position - global_position
	var target_yaw := atan2(to_npc.x, to_npc.z)
	yaw_pivot.rotation.y = rotate_toward(yaw_pivot.rotation.y, target_yaw + PI * 0.85, 3.0 * delta)
	spring.spring_length = lerp(spring.spring_length, 2.4, 4.0 * delta)


# Fundido de paredes camera_fadeable entre cámara y personaje (OCC-001..004)
func _update_occlusion_fade(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := yaw_pivot.global_position
	var hits := {}
	var exclude: Array[RID] = [get_rid()]
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, to, 2)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var collider: Object = hit.collider
		exclude.append(hit.rid)
		if collider is Node and collider.is_in_group("camera_fadeable") and profile.fade_walls:
			hits[collider] = true
	for wall in get_tree().get_nodes_in_group("camera_fadeable"):
		var t: float = _fade_timers.get(wall, 0.0)
		t = clamp(t + (delta if hits.has(wall) else -delta), 0.0, 0.5)
		_fade_timers[wall] = t
		var want_alpha := 0.25 if t > 0.15 else 1.0
		var mesh: MeshInstance3D = wall.get_node_or_null("Mesh")
		if mesh and mesh.material_override:
			var c: Color = mesh.material_override.albedo_color
			c.a = lerp(c.a, want_alpha, 1.0 - exp(-12.0 * delta))
			mesh.material_override.albedo_color = c


func set_profile(p: CameraProfile) -> void:
	profile = p
	preferred_distance = clamp(p.default_distance, p.min_distance, p.max_distance)


func enter_dialogue(npc: Node3D) -> void:
	cam_mode = CamMode.DIALOGUE
	_dialogue_target = npc


func exit_dialogue() -> void:
	cam_mode = CamMode.FREE
	_dialogue_target = null


func visual_yaw() -> float:
	return visual.rotation.y


func get_camera_state() -> Dictionary:
	return {
		"yaw": yaw_pivot.rotation.y,
		"pitch": -pitch_pivot.rotation.x,
		"preferred_distance": preferred_distance,
	}


func apply_saved_state(pos: Vector3, rot_y: float, cam: Dictionary) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	visual.rotation.y = rot_y
	yaw_pivot.rotation.y = float(cam.get("yaw", PI))
	pitch_pivot.rotation.x = -float(cam.get("pitch", 0.43))
	preferred_distance = float(cam.get("preferred_distance", 4.5))
