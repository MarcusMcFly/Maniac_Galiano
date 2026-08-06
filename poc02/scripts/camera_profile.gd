# CameraProfile Resource — parámetros de cámara por sala (SPEC_02 §8.2)
class_name CameraProfile
extends Resource

@export_group("Orbit")
@export var min_distance := 2.2
@export var max_distance := 8.0
@export var default_distance := 4.5
@export_range(-60.0, 60.0, 0.5) var min_pitch_deg := -15.0
@export_range(-10.0, 85.0, 0.5) var max_pitch_deg := 60.0

@export_group("Response")
@export var follow_speed := 12.0
@export var rotation_speed := 14.0
@export var zoom_speed := 10.0
@export var recenter_speed_deg := 180.0

@export_group("Room Assistance")
@export var fade_walls := true
@export var hide_ceiling := true


static func make(d: Dictionary) -> CameraProfile:
	var p := CameraProfile.new()
	for k in d:
		p.set(k, d[k])
	return p
