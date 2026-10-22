class_name LootDrop
extends Area3D

const TYPE_GOLD = 0
const TYPE_POTION_HP = 1
const TYPE_WEAPON = 2
const TYPE_ARMOR = 3

const RARITY_COMMON = 0
const RARITY_RARE = 1
const RARITY_EPIC = 2
const RARITY_LEGENDARY = 3

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

	if label:
		label.text = base_display_name
		label.modulate = rarity_color
		label.visible = (item_type != TYPE_GOLD)

	if beam:
		if item_type == TYPE_WEAPON or item_type == TYPE_ARMOR or rarity >= RARITY_RARE:
			beam.visible = true
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.45)
			beam.material_override = mat
		else:
			beam.visible = false

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
			var wpn_roll := randi() % 3
			var pref_class := "warrior"
			var subtype := "sword"
			var base_dmg := 12.0 + (rarity * 8.0) + randi_range(1, 4)

			match wpn_roll:
				0: # Warrior: Sword / Axe
					pref_class = "warrior"
					subtype = "sword" if randf() < 0.6 else "axe"
					icon = "⚔️" if subtype == "sword" else "🪓"
					it_name = ("Кованый Меч" if subtype == "sword" else "Боевая Секира")
					stats = {"damage": base_dmg, "crit_chance": 0.04 + (rarity * 0.02)}
					desc = "Мощное воинское оружие ближнего боя."
				1: # Rogue: Bow
					pref_class = "rogue"
					subtype = "bow"
					icon = "🏹"
					it_name = "Охотничий Лук"
					stats = {"damage": base_dmg * 0.9, "crit_chance": 0.08 + (rarity * 0.03), "move_speed": 0.04}
					desc = "Дальнобойный лук следопыта с высокой скоростью."
				2: # Mage: Staff
					pref_class = "mage"
					subtype = "staff"
					icon = "🪄"
					it_name = "Посох Стихий"
					stats = {"damage": base_dmg * 0.85, "spell_power": 12.0 + (rarity * 10.0), "max_hp": 8.0}
					desc = "Тайный магический посох, концентрирующий энергию заклинаний."

			if rarity >= InventoryManager.RARITY_EPIC:
				stats["crit_damage"] = 0.25

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
