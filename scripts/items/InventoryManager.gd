extends Node

# Inventory & Equipment Manager Singleton
signal inventory_updated()
signal equipment_updated()
signal item_used(item: Dictionary)
signal bag_full()

const BAG_SIZE: int = 24 # 4 rows x 6 columns

# Item types
const TYPE_WEAPON: String = "weapon"
const TYPE_SHIELD: String = "shield"
const TYPE_ARMOR: String = "armor"
const TYPE_HELM: String = "helm"
const TYPE_AMULET: String = "amulet"
const TYPE_RING: String = "ring"
const TYPE_POTION: String = "potion"

# Rarity
const RARITY_COMMON: int = 0
const RARITY_RARE: int = 1
const RARITY_EPIC: int = 2
const RARITY_LEGENDARY: int = 3

const RARITY_COLORS: Dictionary = {
	RARITY_COMMON: Color(0.88, 0.88, 0.88, 1.0),
	RARITY_RARE: Color(0.24, 0.62, 1.0, 1.0),
	RARITY_EPIC: Color(0.72, 0.32, 1.0, 1.0),
	RARITY_LEGENDARY: Color(1.0, 0.65, 0.12, 1.0),
}

const RARITY_NAMES: Dictionary = {
	RARITY_COMMON: "Обычный",
	RARITY_RARE: "Редкий",
	RARITY_EPIC: "Эпический",
	RARITY_LEGENDARY: "Легендарный",
}

# 24 Bag slots (Array of null or item Dictionary)
var bag: Array = []

# Equipment slots: helm, amulet, armor, weapon, shield, ring_1, ring_2
var equipment: Dictionary = {
	"helm": null,
	"amulet": null,
	"armor": null,
	"weapon": null,
	"shield": null,
	"ring_1": null,
	"ring_2": null,
}

# Cached equipment aggregate stats
var bonus_damage: float = 0.0
var bonus_armor: float = 0.0
var bonus_max_hp: float = 0.0
var bonus_crit_chance: float = 0.0
var bonus_crit_damage: float = 0.0
var bonus_move_speed: float = 0.0

func _ready() -> void:
	bag.resize(BAG_SIZE)
	for i in range(BAG_SIZE):
		bag[i] = null

	_grant_starter_items()
	_recalculate_equipment_bonuses()

func _grant_starter_items() -> void:
	# Give starter weapon & shield & potions for instant testing
	var starter_sword: Dictionary = create_item(
		"wpn_starter_sword",
		"Кованый Меч Рекрута",
		TYPE_WEAPON,
		RARITY_COMMON,
		"⚔️",
		{"damage": 8.0, "crit_chance": 0.04},
		"Простой, но надежно сбалансированный меч пехотинца."
	)
	var starter_shield: Dictionary = create_item(
		"shd_iron_buckler",
		"Железный Баклер",
		TYPE_SHIELD,
		RARITY_COMMON,
		"🛡️",
		{"armor": 12.0, "max_hp": 15.0},
		"Крепкий круглый щит из черного железа."
	)
	var starter_potion: Dictionary = create_item(
		"pot_healing",
		"Зелье Здоровья",
		TYPE_POTION,
		RARITY_RARE,
		"🧪",
		{"heal": 45.0},
		"Восстанавливает 45 единиц здоровья.",
		3
	)

	bag[0] = starter_sword
	bag[1] = starter_shield
	bag[2] = starter_potion

# Factory function to build standardized item dictionary
func create_item(id: String, name: String, type: String, rarity: int, icon: String, stats: Dictionary, desc: String = "", amount: int = 1) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"rarity": rarity,
		"icon": icon,
		"stats": stats.duplicate(),
		"desc": desc,
		"amount": amount,
	}

# Adds an item to the bag. Supports stacking for potions.
func add_item(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false

	# If potion, check if we can stack with existing potion of same ID
	if item_data.get("type") == TYPE_POTION:
		for i in range(BAG_SIZE):
			var slot = bag[i]
			if slot != null and slot.get("id") == item_data.get("id"):
				slot["amount"] = slot.get("amount", 1) + item_data.get("amount", 1)
				inventory_updated.emit()
				return true

	# Find first empty slot
	for i in range(BAG_SIZE):
		if bag[i] == null:
			bag[i] = item_data.duplicate(true)
			inventory_updated.emit()
			return true

	bag_full.emit()
	return false

# Removes item at index, returns the removed item or null
func remove_item_at(index: int):
	if index < 0 or index >= BAG_SIZE:
		return null
	var it = bag[index]
	bag[index] = null
	inventory_updated.emit()
	return it

# Swaps two slots inside bag
func swap_bag_slots(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= BAG_SIZE or to_idx < 0 or to_idx >= BAG_SIZE:
		return
	var temp = bag[from_idx]
	bag[from_idx] = bag[to_idx]
	bag[to_idx] = temp
	inventory_updated.emit()

# Equip item from bag index into appropriate doll slot
func equip_item_from_bag(bag_idx: int) -> bool:
	if bag_idx < 0 or bag_idx >= BAG_SIZE or bag[bag_idx] == null:
		return false

	var item: Dictionary = bag[bag_idx]
	var type: String = item.get("type", "")
	var target_slot: String = ""

	match type:
		TYPE_HELM:
			target_slot = "helm"
		TYPE_AMULET:
			target_slot = "amulet"
		TYPE_ARMOR:
			target_slot = "armor"
		TYPE_WEAPON:
			target_slot = "weapon"
		TYPE_SHIELD:
			target_slot = "shield"
		TYPE_RING:
			if equipment["ring_1"] == null:
				target_slot = "ring_1"
			elif equipment["ring_2"] == null:
				target_slot = "ring_2"
			else:
				target_slot = "ring_1"
		_:
			return false # Not equipable gear

	# Swap item in equipment with bag slot
	var prev_equipped = equipment[target_slot]
	equipment[target_slot] = item
	bag[bag_idx] = prev_equipped

	_recalculate_equipment_bonuses()
	equipment_updated.emit()
	inventory_updated.emit()
	return true

# Unequip item from doll slot back to first available bag slot
func unequip_slot_to_bag(slot_name: String) -> bool:
	if not equipment.has(slot_name) or equipment[slot_name] == null:
		return false

	# Find empty bag slot
	var empty_idx: int = -1
	for i in range(BAG_SIZE):
		if bag[i] == null:
			empty_idx = i
			break

	if empty_idx == -1:
		bag_full.emit()
		return false

	bag[empty_idx] = equipment[slot_name]
	equipment[slot_name] = null

	_recalculate_equipment_bonuses()
	equipment_updated.emit()
	inventory_updated.emit()
	return true

# Use item at bag index (e.g., drink potion)
func use_item_at(bag_idx: int) -> bool:
	if bag_idx < 0 or bag_idx >= BAG_SIZE or bag[bag_idx] == null:
		return false

	var item: Dictionary = bag[bag_idx]
	var type: String = item.get("type", "")

	if type == TYPE_POTION:
		var heal_val: float = item.get("stats", {}).get("heal", 45.0)
		var player = Global.current_player
		if player and is_instance_valid(player):
			var current_hp: float = player.health
			var max_hp: float = player.max_health
			if current_hp >= max_hp:
				# Already full HP, don't waste
				return false

			var actual_heal: float = minf(heal_val, max_hp - current_hp)
			player.health += actual_heal
			Global.player_health_changed.emit(player.health, player.max_health)
			Global.damage_spawned.emit(player.global_position + Vector3.UP * 1.6, int(actual_heal), false, false)

			item["amount"] = item.get("amount", 1) - 1
			if item["amount"] <= 0:
				bag[bag_idx] = null

			item_used.emit(item)
			inventory_updated.emit()
			return true
	else:
		# If gear, right click equips it!
		return equip_item_from_bag(bag_idx)

	return false

func _recalculate_equipment_bonuses() -> void:
	bonus_damage = 0.0
	bonus_armor = 0.0
	bonus_max_hp = 0.0
	bonus_crit_chance = 0.0
	bonus_crit_damage = 0.0
	bonus_move_speed = 0.0

	for slot_name in equipment.keys():
		var it = equipment[slot_name]
		if it != null and it is Dictionary:
			var stats: Dictionary = it.get("stats", {})
			bonus_damage += stats.get("damage", 0.0)
			bonus_armor += stats.get("armor", 0.0)
			bonus_max_hp += stats.get("max_hp", 0.0)
			bonus_crit_chance += stats.get("crit_chance", 0.0)
			bonus_crit_damage += stats.get("crit_damage", 0.0)
			bonus_move_speed += stats.get("move_speed", 0.0)

	# Notify player if present
	var player = Global.current_player
	if player and is_instance_valid(player) and player.has_method("on_equipment_stats_changed"):
		player.on_equipment_stats_changed()
