extends Node

# Global game events and state
signal player_health_changed(current: float, max_val: float)
signal player_resource_changed(current: float, max_val: float)
signal player_xp_changed(current: int, needed: int, level: int)
signal damage_spawned(pos: Vector3, amount: int, is_crit: bool, is_player_damage: bool)
signal loot_dropped(item_data: Dictionary, pos: Vector3)

var current_player: CharacterBody3D = null
var player_class: String = "Paladin"
var player_level: int = 1
var player_gold: int = 0
