class_name Hurtbox3D
extends Area3D

const HitboxClass = preload("res://scripts/combat/Hitbox3D.gd")

signal received_damage(amount: float, is_crit: bool, source: Node3D, knockback: float)

@export var is_invulnerable: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if is_invulnerable:
		return
	if "damage" in area:
		var dmg: float = area.get("damage")
		var is_crit: bool = area.get("is_crit") if "is_crit" in area else false
		var source: Node3D = area.get("source_entity") if "source_entity" in area else null
		var knock: float = area.get("knockback_force") if "knockback_force" in area else 5.0
		received_damage.emit(dmg, is_crit, source, knock)
