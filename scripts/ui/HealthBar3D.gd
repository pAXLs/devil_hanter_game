class_name HealthBar3D
extends Node3D

@onready var bg: MeshInstance3D = $Background
@onready var fill: MeshInstance3D = $Fill
@onready var name_label: Label3D = $NameLabel

var max_val: float = 100.0
var cur_val: float = 100.0
var camera: Camera3D = null
var hide_timer: float = 0.0
var is_active: bool = false

func _ready() -> void:
	visible = false
	camera = get_viewport().get_camera_3d()

func _process(delta: float) -> void:
	if not visible:
		return

	if not camera:
		camera = get_viewport().get_camera_3d()

	# Always face camera (billboard orientation)
	if camera:
		global_rotation = camera.global_rotation

	# Auto-hide after 4 seconds of no damage if health is full
	if hide_timer > 0.0:
		hide_timer -= delta
		if hide_timer <= 0.0 and cur_val >= max_val:
			visible = false

func set_title(text: String, color: Color = Color.WHITE) -> void:
	if name_label:
		name_label.text = text
		name_label.modulate = color
		name_label.visible = (text != "")
	visible = true

func update_health(current: float, maximum: float) -> void:
	cur_val = current
	max_val = maximum
	visible = true
	hide_timer = 4.0

	var ratio: float = clampf(current / maximum, 0.0, 1.0)
	if fill:
		var tween := create_tween()
		var target_scale_x := maxf(ratio, 0.001)
		var target_pos_x := -0.48 * (1.0 - target_scale_x)
		tween.parallel().tween_property(fill, "scale:x", target_scale_x, 0.15)
		tween.parallel().tween_property(fill, "position:x", target_pos_x, 0.15)
