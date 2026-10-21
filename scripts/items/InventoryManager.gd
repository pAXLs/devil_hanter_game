extends Node

# Inventory & Equipment Manager Singleton
signal inventory_updated()
signal equipment_updated()
signal item_used(item: Dictionary)
signal bag_full()
signal potion_count_changed(current: int, max_val: int)

const BAG_SIZE: int = 24 # 4 rows x 6 columns
const MAX_POTION_BELT: int = 5
const MAX_POTION_STACK: int = 5

var potion_belt_count: int = 3 # Quick Potion Belt charges (max 5)

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

	bag[0] = starter_sword
	bag[1] = starter_shield
	potion_belt_count = 3
	potion_count_changed.emit(potion_belt_count, MAX_POTION_BELT)

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

# Adds an item to the bag or dedicated potion slot.
func add_item(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false

	var is_potion: bool = (item_data.get("type") == TYPE_POTION or item_data.get("id") == "pot_healing")

	# 1. POTIONS: Priority is to stack into the dedicated belt slot (max 5)
	if is_potion:
		var to_add: int = item_data.get("amount", 1)

		if potion_belt_count < MAX_POTION_BELT:
			var needed: int = MAX_POTION_BELT - potion_belt_count
			var added_to_belt: int = mini(to_add, needed)
			potion_belt_count += added_to_belt
			to_add -= added_to_belt
			potion_count_changed.emit(potion_belt_count, MAX_POTION_BELT)
			if to_add <= 0:
				return true

		# 2. If belt is full (5/5), stack into existing bag potion slots up to MAX_POTION_STACK (5)
		for i in range(BAG_SIZE):
			var slot = bag[i]
			if slot != null and (slot.get("type") == TYPE_POTION or slot.get("id") == "pot_healing"):
				var cur_amt: int = slot.get("amount", 1)
				if cur_amt < MAX_POTION_STACK:
					var space: int = MAX_POTION_STACK - cur_amt
					var added_to_slot: int = mini(to_add, space)
					slot["amount"] = cur_amt + added_to_slot
					to_add -= added_to_slot
					inventory_updated.emit()
					if to_add <= 0:
						return true

		# 3. If still potions remaining and bag has empty slot, put into a new stack
		if to_add > 0:
			for i in range(BAG_SIZE):
				if bag[i] == null:
					var new_pot = item_data.duplicate(true)
					new_pot["amount"] = mini(to_add, MAX_POTION_STACK)
					bag[i] = new_pot
					inventory_updated.emit()
					return true

		bag_full.emit()
		return false

	# For regular gear: find first empty slot
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

# Use item at bag index (e.g., drink potion or equip gear)
func use_item_at(bag_idx: int) -> bool:
	if bag_idx < 0 or bag_idx >= BAG_SIZE or bag[bag_idx] == null:
		return false

	var item: Dictionary = bag[bag_idx]
	var type: String = item.get("type", "")

	if type == TYPE_POTION or item.get("id") == "pot_healing":
		return use_potion()
	else:
		return equip_item_from_bag(bag_idx)

# Drinks a potion from the belt first, then from the bag
func use_potion() -> bool:
	var player = Global.current_player
	if not player or not is_instance_valid(player):
		return false

	var current_hp: float = player.health
	var max_hp: float = player.max_health
	if current_hp >= max_hp:
		return false # Don't waste potion on full HP

	# 1. Belt charges have first priority
	if potion_belt_count > 0:
		potion_belt_count -= 1
		potion_count_changed.emit(potion_belt_count, MAX_POTION_BELT)
		_apply_potion_heal(player, 45.0)
		return true

	# 2. Check bag for stored potion stacks
	for i in range(BAG_SIZE):
		var slot = bag[i]
		if slot != null and (slot.get("type") == TYPE_POTION or slot.get("id") == "pot_healing"):
			slot["amount"] = slot.get("amount", 1) - 1
			if slot["amount"] <= 0:
				bag[i] = null
			inventory_updated.emit()
			_apply_potion_heal(player, 45.0)
			return true

	return false

func _apply_potion_heal(player: CharacterBody3D, heal_val: float) -> void:
	var actual_heal: float = minf(heal_val, player.max_health - player.health)
	player.health += actual_heal
	Global.player_health_changed.emit(player.health, player.max_health)
	Global.damage_spawned.emit(player.global_position + Vector3.UP * 1.6, int(actual_heal), false, false)
	item_used.emit({"name": "Зелье Здоровья", "type": TYPE_POTION})

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
