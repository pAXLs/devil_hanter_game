extends Node

# Inventory & Equipment Manager Singleton
signal inventory_updated()
signal equipment_updated()
signal stash_updated()
signal item_used(item: Dictionary)
signal bag_full()
signal potion_count_changed(current: int, max_val: int)

const BAG_SIZE: int = 24 # 4 rows x 6 columns
const STASH_SIZE: int = 36 # 6 rows x 6 columns
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

# 36 Stash slots (Array of null or item Dictionary)
var stash: Array = []

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
var bonus_spell_power: float = 0.0

func _ready() -> void:
	bag.resize(BAG_SIZE)
	for i in range(BAG_SIZE):
		bag[i] = null

	stash.resize(STASH_SIZE)
	for i in range(STASH_SIZE):
		stash[i] = null

	Global.class_changed.connect(_on_class_changed)
	_grant_starter_items()
	_recalculate_equipment_bonuses()

func _grant_starter_items() -> void:
	var starter_items: Array[Dictionary] = get_starter_items_for_class(Global.current_class)
	for i in range(mini(starter_items.size(), BAG_SIZE)):
		bag[i] = starter_items[i]
	potion_belt_count = 3
	potion_count_changed.emit(potion_belt_count, MAX_POTION_BELT)

# Returns starter gear set for a specific class
func get_starter_items_for_class(c_id: String) -> Array[Dictionary]:
	match c_id:
		Global.CLASS_WARRIOR:
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
			return [starter_sword, starter_shield]

		Global.CLASS_ROGUE:
			var starter_bow: Dictionary = create_item(
				"wpn_starter_bow",
				"Охотничий Лук",
				TYPE_WEAPON,
				RARITY_COMMON,
				"🏹",
				{"damage": 7.0, "crit_chance": 0.08, "move_speed": 0.05},
				"Легкий дальнобойный лук следопыта из гибкого ясеня."
			)
			var starter_dagger: Dictionary = create_item(
				"wpn_starter_dagger",
				"Охотничий Кинжал",
				TYPE_SHIELD,
				RARITY_COMMON,
				"🗡️",
				{"damage": 5.0, "crit_chance": 0.06, "crit_damage": 0.15},
				"Острый кинжал для левой руки, парирующий удары и вспарывающий уязвимые места."
			)
			return [starter_bow, starter_dagger]

		Global.CLASS_MAGE:
			var starter_staff: Dictionary = create_item(
				"wpn_starter_staff",
				"Посох Ученика Огня",
				TYPE_WEAPON,
				RARITY_COMMON,
				"🪄",
				{"damage": 6.0, "spell_power": 15.0, "max_hp": 5.0},
				"Деревянный посох с тлеющим рубиновым кристаллом."
			)
			var starter_robe: Dictionary = create_item(
				"arm_apprentice_robe",
				"Мантия Послушника",
				TYPE_ARMOR,
				RARITY_COMMON,
				"🥋",
				{"armor": 5.0, "max_hp": 15.0, "spell_power": 10.0},
				"Тканая мантия с вышитыми защитными рунами чародеев."
			)
			return [starter_staff, starter_robe]

		_:
			return []

# Helper function to switch character class and equip corresponding starter gear
func change_class(new_c: String) -> void:
	if Global.current_class != new_c:
		Global.set_character_class(new_c)
	else:
		switch_class_starter_equipment(new_c)

func _on_class_changed(new_c: String) -> void:
	switch_class_starter_equipment(new_c)

# Equips starter gear for the designated class into doll slots
func switch_class_starter_equipment(new_c: String) -> void:
	var items: Array[Dictionary] = get_starter_items_for_class(new_c)
	if items.is_empty():
		return

	var starter_ids := [
		"wpn_starter_sword", "shd_iron_buckler",
		"wpn_starter_bow", "wpn_starter_dagger",
		"wpn_starter_staff", "arm_apprentice_robe"
	]

	# Remove obsolete starter items from bag
	for i in range(BAG_SIZE):
		var it = bag[i]
		if it != null and it is Dictionary and it.get("id") in starter_ids:
			bag[i] = null

	# Equip new starter items into doll slots
	for it in items:
		var slot_to_use := ""
		match it.get("type"):
			TYPE_WEAPON:
				slot_to_use = "weapon"
			TYPE_SHIELD:
				slot_to_use = "shield"
			TYPE_ARMOR:
				slot_to_use = "armor"

		if slot_to_use != "":
			var old_item = equipment[slot_to_use]
			if old_item != null and old_item is Dictionary:
				# Preserve non-starter equipment by putting it in bag
				if not old_item.get("id") in starter_ids:
					add_item(old_item)
			equipment[slot_to_use] = it.duplicate(true)

	# Clean up leftover starter gear in non-applicable doll slots
	if new_c == Global.CLASS_MAGE:
		if equipment["shield"] != null and equipment["shield"].get("id") in starter_ids:
			equipment["shield"] = null
	elif new_c == Global.CLASS_WARRIOR or new_c == Global.CLASS_ROGUE:
		if equipment["armor"] != null and equipment["armor"].get("id") in starter_ids:
			equipment["armor"] = null

	_recalculate_equipment_bonuses()
	equipment_updated.emit()
	inventory_updated.emit()

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
			if item.get("id") == "wpn_starter_dagger" and equipment["weapon"] != null and equipment["shield"] == null:
				target_slot = "shield"
			else:
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
	AudioManager.play_equip()
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
	AudioManager.play_equip()
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
	AudioManager.play_potion()
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
	bonus_spell_power = 0.0

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
			bonus_spell_power += stats.get("spell_power", 0.0)

	# Notify player if present
	var player = Global.current_player
	if player and is_instance_valid(player) and player.has_method("on_equipment_stats_changed"):
		player.on_equipment_stats_changed()

# --- Stash (Personal Chest) Operations ---

func add_item_to_stash(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false

	# 1. Stackable check (potions)
	var it_type: String = item_data.get("type", "")
	if it_type == TYPE_POTION:
		for i in range(STASH_SIZE):
			var slot = stash[i]
			if slot != null and slot.get("type") == TYPE_POTION and slot.get("id") == item_data.get("id"):
				var cur_amount: int = slot.get("amount", 1)
				if cur_amount < MAX_POTION_STACK:
					slot["amount"] = cur_amount + item_data.get("amount", 1)
					stash_updated.emit()
					return true

	# 2. Find empty slot in stash
	for i in range(STASH_SIZE):
		if stash[i] == null:
			stash[i] = item_data
			stash_updated.emit()
			return true

	return false

func move_bag_to_stash(bag_index: int) -> bool:
	if bag_index < 0 or bag_index >= BAG_SIZE or bag[bag_index] == null:
		return false

	var item: Dictionary = bag[bag_index]
	var success: bool = add_item_to_stash(item)
	if success:
		bag[bag_index] = null
		inventory_updated.emit()
		AudioManager.play_equip()
		return true
	return false

func move_stash_to_bag(stash_index: int) -> bool:
	if stash_index < 0 or stash_index >= STASH_SIZE or stash[stash_index] == null:
		return false

	var item: Dictionary = stash[stash_index]
	var success: bool = add_item(item)
	if success:
		stash[stash_index] = null
		stash_updated.emit()
		AudioManager.play_equip()
		return true
	return false

func swap_stash_items(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= STASH_SIZE or to_idx < 0 or to_idx >= STASH_SIZE:
		return
	var temp = stash[from_idx]
	stash[from_idx] = stash[to_idx]
	stash[to_idx] = temp
	stash_updated.emit()

# --- Merchant & Blacksmith Economy ---

func get_item_sell_price(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var rar: int = item.get("rarity", 0)
	var base_price: int = 15
	match rar:
		RARITY_COMMON: base_price = 15
		RARITY_RARE: base_price = 45
		RARITY_EPIC: base_price = 110
		RARITY_LEGENDARY: base_price = 280
	var amt: int = item.get("amount", 1)
	var up_lvl: int = item.get("upgrade_level", 0)
	return (base_price + up_lvl * 25) * amt

func get_upgrade_cost(item: Dictionary) -> int:
	var cur_lvl: int = item.get("upgrade_level", 0)
	match cur_lvl:
		0: return 40
		1: return 80
		2: return 150
		3: return 260
		4: return 450
		_: return 999

func upgrade_item(item: Dictionary) -> bool:
	var cur_lvl: int = item.get("upgrade_level", 0)
	if cur_lvl >= 5:
		return false
	var cost := get_upgrade_cost(item)
	if Global.player_gold < cost:
		return false

	Global.player_gold -= cost
	item["upgrade_level"] = cur_lvl + 1
	var clean_name: String = item.get("name", "Предмет")
	if " +" in clean_name:
		clean_name = clean_name.split(" +")[0]
	item["name"] = clean_name + " +" + str(cur_lvl + 1)

	var stats: Dictionary = item.get("stats", {})
	for k in stats.keys():
		stats[k] = round(stats[k] * 1.25)
	item["stats"] = stats

	_recalculate_equipment_bonuses()
	inventory_updated.emit()
	equipment_updated.emit()
	return true


