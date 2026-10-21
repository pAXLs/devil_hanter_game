class_name Hitbox3D
extends Area3D

@export var damage: float = 25.0
@export var is_crit: bool = false
@export var knockback_force: float = 8.0
@export var source_entity: Node3D = null

func _ready() -> void:
	monitoring = true
	monitorable = true
