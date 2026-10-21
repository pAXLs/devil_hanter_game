class_name MainWorld
extends Node3D

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/SkeletonEnemy.tscn")
@export var spawn_interval: float = 6.0
@export var max_enemies: float = 8

var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_check_and_spawn()

func _check_and_spawn() -> void:
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	if existing_enemies.size() >= max_enemies:
		return

	var angle := randf() * TAU
	var dist := randf_range(10.0, 16.0)
	var spawn_pos := Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)

	if Global.current_player:
		spawn_pos += Global.current_player.global_position
		spawn_pos.y = 0.5

	var enemy = enemy_scene.instantiate()
	enemy.add_to_group("enemies")
	enemy.position = spawn_pos
	add_child(enemy)
