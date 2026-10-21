class_name IsometricCamera
extends Camera3D

@export var target: Node3D = null
@export var smooth_speed: float = 6.0
@export var offset: Vector3 = Vector3(0, 14, 11)

var shake_intensity: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	# Isometric angle looking down at origin
	transform.origin = offset
	look_at(Vector3.ZERO, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not target:
		if Global.current_player:
			target = Global.current_player
		else:
			return

	var target_pos := target.global_position + offset
	global_position = global_position.lerp(target_pos, smooth_speed * delta)

	# Handle screen shake
	if shake_timer > 0.0:
		shake_timer -= delta
		var offset_shake := Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		global_position += offset_shake

func shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration
