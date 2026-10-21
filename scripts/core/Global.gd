extends Node

# Global game events and state
signal player_health_changed(current: float, max_val: float)
signal player_resource_changed(current: float, max_val: float)
signal player_xp_changed(current: int, needed: int, level: int)
signal damage_spawned(pos: Vector3, amount: int, is_crit: bool, is_player_damage: bool)
signal loot_dropped(item_data: Dictionary, pos: Vector3)

# Boss signals
signal boss_spawned(boss_name: String, max_hp: float)
signal boss_health_changed(current: float, max_val: float)
signal boss_defeated()

# Shrine buff signals
signal shrine_buff_changed(shrine_type: int, time_left: float)

# Dungeon Floors & Portals progression
signal floor_changed(floor_num: int, floor_name: String)
signal request_floor_transition(stats: Dictionary)
signal execute_floor_descent()

var current_player: CharacterBody3D = null
var player_class: String = "Paladin"
var player_level: int = 1
var player_gold: int = 0

# Floor stats
var current_floor: int = 1
var enemies_killed_floor: int = 0
var gold_collected_floor: int = 0
var enemies_killed_total: int = 0
var floor_start_time: float = 0.0

func get_floor_name(floor_num: int) -> String:
	match floor_num:
		1:
			return "Древний Склеп"
		2:
			return "Кровавые Катакомбы"
		3:
			return "Обитель Хаоса"
		_:
			return "Глубины Преисподней (Этаж %d)" % floor_num

func get_floor_hp_multiplier() -> float:
	return 1.0 + (current_floor - 1) * 0.25

func get_floor_damage_multiplier() -> float:
	return 1.0 + (current_floor - 1) * 0.15

func get_floor_elite_chance() -> float:
	return clampf(0.18 + (current_floor - 1) * 0.08, 0.18, 0.45)
