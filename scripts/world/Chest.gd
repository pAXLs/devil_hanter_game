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

	# 3. Spawn 1 Epic / Rare Gear piece with glowing beam (Type 2 = Weapon)
	var gear = loot_scene.instantiate()
	gear.item_type = 2
	var is_legendary := randf() < 0.25
	gear.rarity = 3 if is_legendary else 2
	gear.item_name = "★ Клинок Инквизитора" if is_legendary else "◆ Кованый Палаш"
	root.add_child(gear)
	gear.global_position = spawn_origin
	var gear_angle := randf() * TAU
	gear.velocity = Vector3(cos(gear_angle) * 2.5, 4.8, sin(gear_angle) * 2.5)
