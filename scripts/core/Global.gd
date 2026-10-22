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

# Death & Respawn signals
signal player_died(kills: int, gold: int)
signal player_respawn_requested()

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

# Current Run stats (reset on camp respawn or new run)
var run_kills: int = 0
var run_gold_collected: int = 0

# Active Save Slot (1, 2, 3)
var current_save_slot: int = 1

func get_floor_name(floor_num: int) -> String:
	match floor_num:
		1:
			return "Древний Склеп"
		2:
			return "Дремучая Чаща"
		3:
			return "Паучье Логово"
		4:
			return "Заброшенная Деревня"
		5:
			return "Цитадель Тьмы"
		_:
			return "Цитадель Тьмы (Этаж %d)" % floor_num

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

# --- Save & Load System ---

func get_save_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func get_save_slot_info(slot: int) -> Dictionary:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return { "exists": false, "slot": slot }
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return { "exists": false, "slot": slot }
	var text := file.get_as_text()
	var json = JSON.parse_string(text)
	if json is Dictionary:
		json["exists"] = true
		json["slot"] = slot
		return json
	return { "exists": false, "slot": slot }

func save_game(slot: int = -1) -> bool:
	if slot <= 0:
		slot = current_save_slot
	current_save_slot = slot

	var inv_data := {}
	var inv_node = get_node_or_null("/root/InventoryManager")
	if inv_node and inv_node.has_method("get_save_data"):
		inv_data = inv_node.get_save_data()

	var skill_data := {}
	var skill_node = get_node_or_null("/root/SkillManager")
	if skill_node and skill_node.has_method("get_save_data"):
		skill_data = skill_node.get_save_data()

	var save_data := {
		"version": 1,
		"slot": slot,
		"class": current_class,
		"level": player_level,
		"gold": player_gold,
		"floor": current_floor,
		"enemies_killed_total": enemies_killed_total,
		"timestamp": int(Time.get_unix_time_from_system()),
		"datetime": Time.get_datetime_string_from_system(),
		"inventory": inv_data,
		"skills": skill_data
	}

	var path := get_save_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for writing: %s" % path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("Game saved successfully to slot %d (%s)" % [slot, path])
	return true

func load_game(slot: int = -1) -> bool:
	if slot <= 0:
		slot = current_save_slot
	current_save_slot = slot

	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		return false

	var saved_c: String = data.get("class", CLASS_WARRIOR)
	player_class = saved_c
	current_class = saved_c
	player_level = int(data.get("level", 1))
	player_gold = int(data.get("gold", 0))
	current_floor = int(data.get("floor", 1))
	enemies_killed_total = int(data.get("enemies_killed_total", 0))

	var inv_node = get_node_or_null("/root/InventoryManager")
	if inv_node and data.has("inventory") and data["inventory"] is Dictionary:
		inv_node.load_save_data(data["inventory"])

	var skill_node = get_node_or_null("/root/SkillManager")
	if skill_node and data.has("skills") and data["skills"] is Dictionary:
		skill_node.load_save_data(data["skills"])

	class_changed.emit(current_class)
	print("Game loaded successfully from slot %d" % slot)
	return true

func delete_save(slot: int) -> void:
	var path := get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Deleted save slot %d" % slot)

func start_new_game(slot: int = 1, chosen_class: String = CLASS_WARRIOR) -> void:
	current_save_slot = slot
	current_class = chosen_class
	player_class = chosen_class
	player_level = 1
	player_gold = 0
	current_floor = 1
	enemies_killed_total = 0
	enemies_killed_floor = 0
	run_kills = 0
	run_gold_collected = 0
	in_town = true
	town_portal_active = false

	var inv_node = get_node_or_null("/root/InventoryManager")
	if inv_node and inv_node.has_method("init_starter_items"):
		inv_node.init_starter_items()
	var skill_node = get_node_or_null("/root/SkillManager")
	if skill_node and skill_node.has_method("reset_all_skills"):
		skill_node.reset_all_skills()

	save_game(slot)
	var trans_node = get_node_or_null("/root/SceneTransition")
	if trans_node and trans_node.has_method("change_scene_to_file"):
		trans_node.change_scene_to_file(
			"res://scenes/world/TownCamp.tscn",
			"ЛАГЕРЬ СТРАЖЕЙ",
			"Ваш путь охотника на демонов начинается..."
		)
	else:
		get_tree().change_scene_to_file("res://scenes/world/TownCamp.tscn")

# --- Death & Respawn Lifecycle ---

func notify_player_death() -> void:
	AudioManager.play_death()
	player_died.emit(run_kills, run_gold_collected)

func respawn_player_in_camp() -> void:
	player_respawn_requested.emit()
	run_kills = 0
	run_gold_collected = 0
	in_town = true
	current_floor = 1

	if current_player and is_instance_valid(current_player):
		current_player.health = current_player.max_health
		current_player.can_act = true
		if current_player.visuals:
			current_player.visuals.rotation_degrees.x = 0.0

	SceneTransition.change_scene_to_file(
		"res://scenes/world/TownCamp.tscn",
		"ВОЗРОЖДЕНИЕ В ЛАГЕРЕ",
		"У священного костра вы восстанавливаете силы..."
	)

func return_to_main_menu() -> void:
	save_game(current_save_slot)
	run_kills = 0
	run_gold_collected = 0
	in_town = false

	SceneTransition.change_scene_to_file(
		"res://scenes/ui/MainMenu.tscn",
		"ГЛАВНОЕ МЕНЮ",
		""
	)

