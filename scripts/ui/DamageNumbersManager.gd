class_name DamageNumbersManager
extends Node2D

func _ready() -> void:
	Global.damage_spawned.connect(_spawn_number)
	_prewarm_shaders()

func _prewarm_shaders() -> void:
	# Offscreen invisible label to pre-compile Godot's text/font renderer and shaders
	var dummy := Label.new()
	dummy.text = "- 99!"
	dummy.position = Vector2(-9999, -9999)
	dummy.modulate = Color(1, 1, 1, 0.01)
	add_child(dummy)
	await get_tree().process_frame
	if is_instance_valid(dummy):
		dummy.queue_free()

func _spawn_number(pos: Vector3, amount: int, is_crit: bool, is_player_damage: bool = false) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	if camera.is_position_behind(pos):
		return

	var screen_pos := camera.unproject_position(pos)
	var label := Label.new()
	label.position = screen_pos + Vector2(randf_range(-15, 15), randf_range(-10, 10))
	label.z_index = 100

	if is_player_damage:
		label.text = "- " + str(amount)
		label.modulate = Color(1.0, 0.15, 0.15, 1.0)
		label.scale = Vector2(1.3, 1.3)
	else:
		label.text = str(amount) + ("!" if is_crit else "")
		if is_crit:
			label.modulate = Color(1.0, 0.45, 0.1, 1.0)
			label.scale = Vector2(1.5, 1.5)
		else:
			label.modulate = Color(1.0, 0.95, 0.25, 1.0)
			label.scale = Vector2(1.1, 1.1)

	add_child(label)

	var tween := create_tween()
	var target_y := label.position.y - 50.0
	var float_x := label.position.x + (randf_range(-25, 25) if not is_player_damage else randf_range(20, 40))
	tween.parallel().tween_property(label, "position:y", target_y, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:x", float_x, 0.7).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)
