class_name Chest
extends StaticBody3D

const LootDropClass = preload("res://scripts/items/LootDrop.gd")

@export var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

var is_opened: bool = false
var player_in_range: bool = false

@onready var lid_pivot: Node3D = $LidPivot
@onready var prompt_label: Label3D = $PromptLabel
@onready var interact_area: Area3D = $InteractArea

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if is_opened or not player_in_range:
		return

	if Input.is_action_just_pressed("interact"):
		open_chest()

func _on_body_entered(body: Node3D) -> void:
	if is_opened:
		return
	if body is PlayerController:
		player_in_range = true
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false

func open_chest() -> void:
	if is_opened:
		return

	is_opened = true
	player_in_range = false
	if prompt_label:
		prompt_label.visible = false

	# Pop open lid with spring bounce
	var tween := create_tween()
	tween.tween_property(lid_pivot, "rotation_degrees:x", -110.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.2, 0.15)

	_spawn_loot_fountain()

func _spawn_loot_fountain() -> void:
	var root := get_tree().current_scene
	var spawn_origin := global_position + Vector3.UP * 0.8

	# 1. Spawn 5-7 Gold Coins (Type 0 = Gold)
	var coin_count := randi_range(5, 8)
	for i in range(coin_count):
		var loot = loot_scene.instantiate()
		loot.item_type = 0
		loot.rarity = 0
		loot.amount = randi_range(8, 25)
		root.add_child(loot)
		loot.global_position = spawn_origin
		var angle := randf() * TAU
		var h_spd := randf_range(2.0, 3.8)
		loot.velocity = Vector3(cos(angle) * h_spd, randf_range(3.5, 5.2), sin(angle) * h_spd)

	# 2. Spawn 1-2 Health Potions (Type 1 = Potion, Rarity 1 = Rare)
	var pot_count := randi_range(1, 2)
	for i in range(pot_count):
		var pot = loot_scene.instantiate()
		pot.item_type = 1
		pot.rarity = 1
		pot.item_name = "Зелье Здоровья"
		root.add_child(pot)
		pot.global_position = spawn_origin
		var angle := randf() * TAU
		var h_spd := randf_range(1.8, 3.2)
		pot.velocity = Vector3(cos(angle) * h_spd, randf_range(3.8, 5.5), sin(angle) * h_spd)

	# 3. Spawn 1-2 Epic / Rare Gear pieces with glowing beam
	var gear_count := randi_range(1, 2)
	for g in range(gear_count):
		var gear = loot_scene.instantiate()
		var roll := randf()
		var is_legendary := (roll < 0.22)
		var rar: int = InventoryManager.RARITY_LEGENDARY if is_legendary else (InventoryManager.RARITY_EPIC if roll < 0.65 else InventoryManager.RARITY_RARE)
		var item_roll := randi() % 5
		var it_data: Dictionary = {}

		match item_roll:
			0: # Weapon
				var w_name := "★ Клинок Инквизитора" if is_legendary else "◆ Кованый Палаш"
				it_data = InventoryManager.create_item("wpn_" + str(randi()%9999), w_name, InventoryManager.TYPE_WEAPON, rar, "⚔️", {"damage": 18.0 + rar * 8.0, "crit_chance": 0.05 + rar * 0.03}, "Закаленный клинок, несущий возмездие.")
				gear.item_type = 2
			1: # Armor
				var a_name := "★ Панцирь Титана" if is_legendary else "◆ Латы Праведника"
				it_data = InventoryManager.create_item("arm_" + str(randi()%9999), a_name, InventoryManager.TYPE_ARMOR, rar, "🥋", {"armor": 22.0 + rar * 12.0, "max_hp": 30.0 + rar * 20.0}, "Тяжелые латы из закаленной руды.")
				gear.item_type = 3
			2: # Helm
				var h_name := "★ Венец Чемпиона" if is_legendary else "◆ Шлем Крестоносца"
				it_data = InventoryManager.create_item("hlm_" + str(randi()%9999), h_name, InventoryManager.TYPE_HELM, rar, "🪖", {"armor": 14.0 + rar * 7.0, "max_hp": 15.0 + rar * 15.0, "crit_damage": 0.15}, "Стальной шлем с забралом.")
				gear.item_type = 3
			3: # Shield
				var s_name := "★ Эгида Света" if is_legendary else "◆ Освященный Щит"
				it_data = InventoryManager.create_item("shd_" + str(randi()%9999), s_name, InventoryManager.TYPE_SHIELD, rar, "🛡️", {"armor": 18.0 + rar * 10.0, "max_hp": 25.0 + rar * 15.0}, "Массивный щит с гравировкой ордена.")
				gear.item_type = 3
			4: # Ring
				var r_name := "★ Перстень Погибели" if is_legendary else "◆ Кольцо Багровой Луны"
				it_data = InventoryManager.create_item("rng_" + str(randi()%9999), r_name, InventoryManager.TYPE_RING, rar, "💍", {"damage": 6.0 + rar * 5.0, "crit_chance": 0.04 + rar * 0.03, "move_speed": 0.05}, "Магическое кольцо древней крови.")
				gear.item_type = 3

		gear.rarity = rar
		gear.item_name = it_data["name"]
		gear.custom_item_data = it_data
		root.add_child(gear)
		gear.global_position = spawn_origin
		var gear_angle := randf() * TAU
		gear.velocity = Vector3(cos(gear_angle) * randf_range(2.0, 3.2), randf_range(4.2, 5.2), sin(gear_angle) * randf_range(2.0, 3.2))
