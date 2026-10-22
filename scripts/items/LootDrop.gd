class_name LootDrop
extends Area3D

const TYPE_GOLD = 0
const TYPE_POTION_HP = 1
const TYPE_WEAPON = 2
const TYPE_ARMOR = 3
const TYPE_SHIELD = 4

const RARITY_COMMON = 0
const RARITY_RARE = 1
const RARITY_EPIC = 2
const RARITY_LEGENDARY = 3

const WEAPON_SWORD_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponSword.tscn")
const WEAPON_GREATSWORD_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponGreatsword.tscn")
const WEAPON_WARHAMMER_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponWarhammer.tscn")
const WEAPON_GREATHAMMER_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponGreathammer.tscn")
const WEAPON_BOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponBow.tscn")
const WEAPON_COMPOSITE_BOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponCompositeBow.tscn")
const WEAPON_CROSSBOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponCrossbow.tscn")
const WEAPON_HEAVY_CROSSBOW_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponHeavyCrossbow.tscn")
const WEAPON_STAFF_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponStaff.tscn")
const WEAPON_WAND_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponWand.tscn")
const WEAPON_DAGGER_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponDagger.tscn")
const WEAPON_AXE_SCENE: PackedScene = preload("res://scenes/player/equipment/WeaponAxe.tscn")
const SHIELD_BUCKLER_SCENE: PackedScene = preload("res://scenes/player/equipment/ShieldBuckler.tscn")
const SHIELD_TOWER_SCENE: PackedScene = preload("res://scenes/player/equipment/ShieldTower.tscn")

@export var item_type: int = TYPE_GOLD
@export var rarity: int = RARITY_COMMON
@export var item_name: String = "Золото"
@export var amount: int = 10
var custom_item_data: Dictionary = {}

var velocity: Vector3 = Vector3.ZERO
var fall_gravity: float = 18.0
var is_grounded: bool = false
var ground_y: float = 0.1
var is_being_picked_up: bool = false
var pickup_radius: float = 1.8

@onready var visuals: Node3D = $Visuals
@onready var label: Label3D = $Label3D
@onready var beam: MeshInstance3D = $LootBeam

var base_display_name: String = ""

func _ready() -> void:
	collision_layer = 64 # Layer 7: Loot
	collision_mask = 2   # Layer 2: Player

	if item_type == TYPE_GOLD:
		base_display_name = "Золото (+%d)" % amount
	elif item_type == TYPE_POTION_HP:
		amount = 1
		item_name = "Зелье Здоровья"
		base_display_name = item_name
	else:
		base_display_name = item_name

	_setup_visuals()

	# Outward scatter pop impulse to the sides
	var angle := randf() * TAU
	var h_speed := randf_range(1.6, 2.8)
	velocity = Vector3(cos(angle) * h_speed, randf_range(3.2, 4.6), sin(angle) * h_speed)

func _setup_visuals() -> void:
	var rarity_color := Color.WHITE
	match rarity:
		RARITY_COMMON:
			rarity_color = Color(0.9, 0.9, 0.9, 1.0)
		RARITY_RARE:
			rarity_color = Color(0.2, 0.6, 1.0, 1.0) # Bright Blue
		RARITY_EPIC:
			rarity_color = Color(0.7, 0.2, 1.0, 1.0) # Purple
		RARITY_LEGENDARY:
			rarity_color = Color(1.0, 0.6, 0.05, 1.0) # Golden Orange

	# Replace coin mesh with 3D gear model if item is weapon or shield
	if item_type == TYPE_WEAPON or item_type == TYPE_SHIELD:
		for child in visuals.get_children():
			child.queue_free()

		var gear_scene: PackedScene = _get_gear_scene()
		if gear_scene:
			var m = gear_scene.instantiate()
			m.scale = Vector3(0.55, 0.55, 0.55)
			m.rotation_degrees = Vector3(15.0, 45.0, 30.0)
			m.position = Vector3(0, 0.25, 0)
			visuals.add_child(m)

	if label:
		label.text = base_display_name
		label.modulate = rarity_color
		label.visible = (item_type != TYPE_GOLD)

	if beam:
		if item_type == TYPE_WEAPON or item_type == TYPE_ARMOR or item_type == TYPE_SHIELD or rarity >= RARITY_RARE:
			beam.visible = true
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.45)
			beam.material_override = mat
		else:
			beam.visible = false

func _get_gear_scene() -> PackedScene:
	var sub: String = custom_item_data.get("subtype", "")
	var i_id: String = custom_item_data.get("id", "")
	var name_lower := (item_name + " " + base_display_name).to_lower()

	if sub == "greathammer" or i_id.contains("greathammer") or name_lower.contains("титан") or name_lower.contains("крушитель"):
		return WEAPON_GREATHAMMER_SCENE
	if sub == "hammer" or i_id.contains("warhammer") or name_lower.contains("молот") or name_lower.contains("инквизитор"):
		return WEAPON_WARHAMMER_SCENE
	if sub == "greatsword" or i_id.contains("greatsword") or name_lower.contains("клеймор") or name_lower.contains("погибел"):
		return WEAPON_GREATSWORD_SCENE
	if sub == "heavy_crossbow" or i_id.contains("heavy_crossbow") or name_lower.contains("баллист"):
		return WEAPON_HEAVY_CROSSBOW_SCENE
	if sub == "crossbow" or i_id.contains("crossbow") or name_lower.contains("самострел"):
		return WEAPON_CROSSBOW_SCENE
	if sub == "composite_bow" or i_id.contains("composite_bow") or name_lower.contains("композит"):
		return WEAPON_COMPOSITE_BOW_SCENE
	if sub == "wand" or i_id.contains("wand") or name_lower.contains("фокус") or name_lower.contains("жезл"):
		return WEAPON_WAND_SCENE
	if sub == "staff" or i_id.contains("staff") or name_lower.contains("посох"):
		return WEAPON_STAFF_SCENE
	if sub == "dagger" or i_id.contains("dagger") or name_lower.contains("кинжал") or name_lower.contains("зуб"):
		return WEAPON_DAGGER_SCENE
	if sub == "axe" or i_id.contains("axe") or name_lower.contains("секир"):
		return WEAPON_AXE_SCENE
	if sub == "tower_shield" or i_id.contains("tower") or name_lower.contains("башенн"):
		return SHIELD_TOWER_SCENE
	if item_type == TYPE_SHIELD or sub == "shield" or name_lower.contains("щит") or name_lower.contains("баклер"):
		return SHIELD_BUCKLER_SCENE
	if sub == "bow" or name_lower.contains("лук"):
		return WEAPON_BOW_SCENE

	return WEAPON_SWORD_SCENE

func _physics_process(delta: float) -> void:
	if not is_grounded:
		velocity.y -= fall_gravity * delta
		global_position += velocity * delta

		if global_position.y <= ground_y:
			global_position.y = ground_y
			if velocity.y < -2.0:
				velocity.y = -velocity.y * 0.4
				velocity.x *= 0.6
				velocity.z *= 0.6
			else:
				is_grounded = true
				velocity = Vector3.ZERO
		return

	# Grounded: gentle rotation
	visuals.rotation.y += 1.8 * delta

	var player: Node3D = Global.current_player
	if player and is_instance_valid(player) and not is_being_picked_up:
		var dist: float = global_position.distance_to(player.global_position)

		# 1. GOLD: Automatic walk-over pickup when stepping over it (radius ~1.0m)
		if item_type == TYPE_GOLD:
			if dist <= 1.0:
				_collect(player)
		else:
			# 2. ITEMS & POTIONS: 100% Manual pickup on [F]. Player decides what to take.
			if dist <= pickup_radius:
				if label:
					label.visible = true
					label.text = "[F] " + base_display_name

				if Input.is_action_just_pressed("interact"):
					_collect(player)
			else:
				if label:
					label.text = base_display_name
					label.visible = true

func get_or_create_item_data() -> Dictionary:
	if not custom_item_data.is_empty():
		return custom_item_data

	var id := "drop_%d_%d" % [item_type, randi() % 100000]
	var it_name := item_name
	var type_str := InventoryManager.TYPE_WEAPON
	var icon := "⚔️"
	var stats: Dictionary = {}
	var desc := ""

	match item_type:
		TYPE_POTION_HP:
			type_str = InventoryManager.TYPE_POTION
			icon = "🧪"
			stats = {"heal": 45.0}
			desc = "Восстанавливает 45 ед. здоровья при использовании."
			return InventoryManager.create_item("pot_healing", "Зелье Здоровья", type_str, RARITY_RARE, icon, stats, desc, 1)
		TYPE_WEAPON:
			type_str = InventoryManager.TYPE_WEAPON
			var wpn_roll := randi() % 12
			var pref_class := "warrior"
			var subtype := "sword"
			var base_dmg := 12.0 + (rarity * 8.0) + randi_range(1, 4)

			match wpn_roll:
				0:
					pref_class = "warrior"
					subtype = "sword"
					icon = "⚔️"
					it_name = "Клинок Стража"
					stats = {"damage": base_dmg, "crit_chance": 0.05 + (rarity * 0.02)}
					desc = "Классический кованый клинок с рубином в гарде."
				1:
					pref_class = "warrior"
					subtype = "greatsword"
					icon = "🗡️"
					it_name = "Клеймор Погибели"
					stats = {"damage": base_dmg * 1.45, "crit_damage": 0.35, "attack_speed": -0.10}
					desc = "Массивный двуручный цвайхендер сокрушительной силы."
				2:
					pref_class = "warrior"
					subtype = "hammer"
					icon = "🔨"
					it_name = "Молот Инквизитора"
					stats = {"damage": base_dmg * 1.15, "armor_penetration": 15.0}
					desc = "Граненый боевой молот с пробивающим клевцом."
				3:
					pref_class = "warrior"
					subtype = "greathammer"
					icon = "⚒️"
					it_name = "Крушитель Титанов"
					stats = {"damage": base_dmg * 1.6, "stun_chance": 0.15, "attack_speed": -0.15}
					desc = "Двуручный монолитный молот с рунической вязью."
				4:
					pref_class = "warrior"
					subtype = "axe"
					icon = "🪓"
					it_name = "Боевая Секира"
					stats = {"damage": base_dmg * 1.1, "bleed_chance": 0.20}
					desc = "Тяжелая двулезвийная секира палача."
				5:
					pref_class = "rogue"
					subtype = "bow"
					icon = "🏹"
					it_name = "Охотничий Лук"
					stats = {"damage": base_dmg * 0.9, "crit_chance": 0.08 + (rarity * 0.03), "move_speed": 0.04}
					desc = "Дальнобойный лук следопыта с высокой скоростью."
				6:
					pref_class = "rogue"
					subtype = "composite_bow"
					icon = "🏹"
					it_name = "Композитный Лук"
					stats = {"damage": base_dmg * 1.05, "crit_chance": 0.12 + (rarity * 0.03)}
					desc = "Изогнутый роговой лук с костяными накладками."
				7:
					pref_class = "rogue"
					subtype = "crossbow"
					icon = "🎯"
					it_name = "Шестерёнчатый Самострел"
					stats = {"damage": base_dmg * 1.25, "crit_chance": 0.10}
					desc = "Механический арбалет со стальной дугой."
				8:
					pref_class = "rogue"
					subtype = "heavy_crossbow"
					icon = "🎯"
					it_name = "Баллиста Тени"
					stats = {"damage": base_dmg * 1.55, "armor_penetration": 25.0}
					desc = "Тяжелый двухзарядный арбалет с магазином."
				9:
					pref_class = "rogue"
					subtype = "dagger"
					icon = "🗡️"
					it_name = "Змеиный Зуб"
					stats = {"damage": base_dmg * 0.8, "crit_chance": 0.18 + (rarity * 0.04), "poison_damage": 8.0}
					desc = "Волнообразный крис с ядовитым отливом лезвия."
				10:
					pref_class = "mage"
					subtype = "staff"
					icon = "🪄"
					it_name = "Посох Древних Таинств"
					stats = {"damage": base_dmg * 0.85, "spell_power": 14.0 + (rarity * 12.0), "max_hp": 10.0}
					desc = "Мореное дерево, оплетенное серебром, с кристальным навершием."
				11:
					pref_class = "mage"
					subtype = "wand"
					icon = "🔥"
					it_name = "Огненный Фокус"
					stats = {"damage": base_dmg * 0.9, "spell_power": 18.0 + (rarity * 10.0), "crit_chance": 0.08}
					desc = "Обсидиановый жезл с пылающей сферой первородного огня."

			if rarity >= InventoryManager.RARITY_EPIC:
				stats["crit_damage"] = 0.25

			return InventoryManager.create_item(id, it_name, type_str, rarity, icon, stats, desc, 1, pref_class, subtype)

		TYPE_SHIELD:
			type_str = InventoryManager.TYPE_SHIELD
			var is_tower := (randf() < 0.5)
			var pref_class := "warrior"
			var subtype := "tower_shield" if is_tower else "shield"
			var icon := "🛡️"
			var it_name := "Башенный Щит Защитника" if is_tower else "Железный Баклер"
			var stats := {
				"armor": (28.0 if is_tower else 16.0) + (rarity * 12.0),
				"max_hp": (35.0 if is_tower else 18.0) + (rarity * 15.0),
				"block_chance": 0.25 if is_tower else 0.12
			}
			var desc := "Массивный рыцарский щит с геральдическим крестом." if is_tower else "Легкий стальной диск с центральным шипом."
			return InventoryManager.create_item(id, it_name, type_str, rarity, icon, stats, desc, 1, pref_class, subtype)
		TYPE_ARMOR:
			type_str = InventoryManager.TYPE_ARMOR
			var arm_roll := randi() % 3
			var pref_class := "warrior"
			var subtype := "armor"
			var arm := 12.0 + (rarity * 10.0)
			var hp := 15.0 + (rarity * 15.0)

			match arm_roll:
				0: # Heavy Plate (Warrior)
					pref_class = "warrior"
					icon = "🥋"
					it_name = "Стальной Панцирь"
					stats = {"armor": arm * 1.25, "max_hp": hp * 1.2}
					desc = "Тяжелые латы, поглощающие сокрушительные удары."
				1: # Leather (Rogue)
					pref_class = "rogue"
					icon = "🥋"
					it_name = "Кожаный Доспех Тени"
					stats = {"armor": arm * 0.8, "max_hp": hp * 0.9, "move_speed": 0.06, "crit_chance": 0.04}
					desc = "Легкий доспех из прочной кожи, дарующий подвижность."
				2: # Robe (Mage)
					pref_class = "mage"
					subtype = "robe"
					icon = "🥋"
					it_name = "Мантия Чародея"
					stats = {"armor": arm * 0.5, "max_hp": hp * 0.8, "spell_power": 15.0 + (rarity * 12.0)}
					desc = "Тканая мантия с защитными рунами, усиливающая заклинания."

			return InventoryManager.create_item(id, it_name, type_str, rarity, icon, stats, desc, 1, pref_class, subtype)
		_:
			type_str = InventoryManager.TYPE_WEAPON
			stats = {"damage": 12.0}

	return InventoryManager.create_item(id, it_name, type_str, rarity, icon, stats, desc, amount if type_str == InventoryManager.TYPE_POTION else 1)

func _collect(player: Node3D) -> void:
	if item_type == TYPE_GOLD:
		is_being_picked_up = true
		Global.player_gold += amount
		Global.gold_collected_floor += amount
		Global.run_gold_collected += amount
		AudioManager.play_gold()
		var tween := create_tween()
		tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.12)
		tween.tween_callback(queue_free)
	else:
		var item_data := get_or_create_item_data()
		var success: bool = InventoryManager.add_item(item_data)
		if success:
			is_being_picked_up = true
			if item_type == TYPE_POTION_HP:
				AudioManager.play_potion()
			else:
				AudioManager.play_equip()
			var tween := create_tween()
			tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.12)
			tween.tween_callback(queue_free)
		else:
			if label:
				label.text = "Зелья полны (5/5)!" if item_type == TYPE_POTION_HP else "Сумка полна!"
				label.modulate = Color(1.0, 0.3, 0.3)
				var reset_tween := create_tween()
				reset_tween.tween_interval(1.5)
				reset_tween.tween_callback(func():
					if is_instance_valid(label):
						label.text = "[F] " + base_display_name
						_setup_visuals()
				)
