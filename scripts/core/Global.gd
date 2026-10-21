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

# Town & Hub progression
signal town_portal_requested()
signal stash_opened()
signal stash_closed()
signal merchant_opened()
signal merchant_closed()
signal blacksmith_opened()
signal blacksmith_closed()

# Character class signals & constants
const CLASS_WARRIOR: String = "warrior"
const CLASS_ROGUE: String = "rogue"
const CLASS_MAGE: String = "mage"

signal class_changed(new_class: String)
signal open_class_selection()

var current_player: CharacterBody3D = null
var current_class: String = CLASS_WARRIOR
var player_class: String = CLASS_WARRIOR
var player_level: int = 1
var player_gold: int = 0

# Town / Dungeon state persistence
var in_town: bool = false
var town_portal_active: bool = false
var saved_dungeon_floor: int = 1
var saved_dungeon_player_pos: Vector3 = Vector3(0, 0.2, 0)

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

# --- Character Class Management & Data ---

func set_character_class(new_c: String) -> void:
	if current_class == new_c:
		return
	current_class = new_c
	player_class = new_c
	class_changed.emit(new_c)

func get_class_info(c_id: String) -> Dictionary:
	match c_id:
		CLASS_WARRIOR:
			return {
				"id": CLASS_WARRIOR,
				"name": "Воитель",
				"title": "Воитель (Warrior)",
				"description": "Несокрушимый мастер ближнего боя, черпающий силу в ярости сражения.",
				"resource_name": "Ярость",
				"resource_type": "fury",
				"max_resource": 100.0,
				"start_resource": 0.0,
				"resource_regen": -5.0, # decays out of combat
				"resource_decay": 5.0,
				"resource_desc": "Ярость: макс 100, накапливается при атаках и ударах, угасает вне боя (-5/сек)",
				"base_hp": 120.0,
				"max_hp": 120.0,
				"armor": 15.0,
				"speed": 6.8,
				"crit": 0.05,
				"crit_chance": 0.05,
				"spell_power": 0.0,
				"icon": "🛡️",
				"starter_items": ["wpn_starter_sword", "shd_iron_buckler"],
			}
		CLASS_ROGUE:
			return {
				"id": CLASS_ROGUE,
				"name": "Ловкач",
				"title": "Ловкач (Rogue)",
				"description": "Смертоносный стрелок и следопыт, поражающий врагов с дистанции градом стрел.",
				"resource_name": "Энергия",
				"resource_type": "energy",
				"max_resource": 100.0,
				"start_resource": 100.0,
				"resource_regen": 20.0, # rapidly regens +20/sec
				"resource_decay": 0.0,
				"resource_desc": "Энергия: макс 100, стремительно восполняется (+20/сек)",
				"base_hp": 90.0,
				"max_hp": 90.0,
				"armor": 8.0,
				"speed": 7.6,
				"crit": 0.12,
				"crit_chance": 0.12,
				"spell_power": 0.0,
				"icon": "🏹",
				"starter_items": ["wpn_starter_bow", "wpn_starter_dagger"],
			}
		CLASS_MAGE:
			return {
				"id": CLASS_MAGE,
				"name": "Послушник",
				"title": "Послушник (Mage)",
				"description": "Повелитель тайной магии, сокрушающий орды нежити разрушительными чарами.",
				"resource_name": "Мана",
				"resource_type": "mana",
				"max_resource": 150.0,
				"start_resource": 150.0,
				"resource_regen": 6.0, # regens +6/sec
				"resource_decay": 0.0,
				"resource_desc": "Мана: макс 150, плавно восстанавливается со временем (+6/сек)",
				"base_hp": 75.0,
				"max_hp": 75.0,
				"armor": 5.0,
				"speed": 6.6,
				"crit": 0.05,
				"crit_chance": 0.05,
				"spell_power": 25.0,
				"icon": "🔮",
				"starter_items": ["wpn_starter_staff", "arm_apprentice_robe"],
			}
		_:
			return {}

func get_current_class_info() -> Dictionary:
	return get_class_info(current_class)

func get_all_classes() -> Array[Dictionary]:
	return [
		get_class_info(CLASS_WARRIOR),
		get_class_info(CLASS_ROGUE),
		get_class_info(CLASS_MAGE),
	]
