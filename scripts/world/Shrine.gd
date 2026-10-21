class_name Shrine
extends StaticBody3D

const TYPE_FRENZY = 0     # +100% Crit Chance & +25% Attack Speed for 30s
const TYPE_PROTECTION = 1 # +75 Armor & +8 HP/sec Regen for 30s
const TYPE_GREED = 2      # Fountain of 12-16 Gold Coins + Epic Gear

@export var shrine_type: int = TYPE_FRENZY
@export var buff_duration: float = 30.0

var is_activated: bool = false
var player_in_range: bool = false

@onready var crystal: MeshInstance3D = $Visuals/Crystal
@onready var light: OmniLight3D = $Visuals/Crystal/OmniLight3D
@onready var prompt_label: Label3D = $PromptLabel
@onready var interact_area: Area3D = $InteractArea

var loot_scene: PackedScene = preload("res://scenes/items/LootDrop.tscn")

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false

	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

	_setup_shrine_visuals()

func _setup_shrine_visuals() -> void:
	var color := Color.WHITE
	var title := "Святилище"

	match shrine_type:
		TYPE_FRENZY:
			color = Color(1.0, 0.15, 0.25, 1.0) # Crimson red
			title = "Святилище Ярости (+100% Крит)"
		TYPE_PROTECTION:
			color = Color(1.0, 0.82, 0.2, 1.0) # Radiant golden
			title = "Святилище Защиты (+75 Брони)"
		TYPE_GREED:
			color = Color(0.2, 0.95, 0.45, 1.0) # Emerald gold
			title = "Святилище Богатства (Золотой Фонтан)"

	if prompt_label:
		prompt_label.text = "[F] " + title
		prompt_label.modulate = color

	if light:
		light.light_color = color
		light.light_energy = 2.2

	if crystal and crystal.material_override:
		var mat := crystal.material_override.duplicate() as StandardMaterial3D
		if mat:
			mat.albedo_color = color
			mat.emission = color
			crystal.material_override = mat

func _physics_process(delta: float) -> void:
	if crystal:
		crystal.rotation.y += 1.6 * delta
		crystal.position.y = 1.65 + sin(Time.get_ticks_msec() * 0.003) * 0.08

	if is_activated or not player_in_range:
		return

	if Input.is_action_just_pressed("interact"):
		activate_shrine()

func _on_body_entered(body: Node3D) -> void:
	if is_activated:
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

func activate_shrine() -> void:
	if is_activated:
		return

	is_activated = true
	player_in_range = false
	if prompt_label:
		prompt_label.visible = false

	AudioManager.play_hammer()

	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(0.25, 0.15)

	# Pulse crystal and dim
	var tween := create_tween()
	tween.tween_property(crystal, "scale", Vector3(1.6, 1.6, 1.6), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(crystal, "scale", Vector3(0.5, 0.5, 0.5), 0.4)
	if light:
		tween.parallel().tween_property(light, "light_energy", 0.4, 0.4)

	# Trigger shrine effect
	var player = Global.current_player
	if player and is_instance_valid(player) and player.has_method("apply_shrine_buff"):
		if shrine_type == TYPE_GREED:
			_spawn_greed_fountain()
		else:
			player.apply_shrine_buff(shrine_type, buff_duration)

func _spawn_greed_fountain() -> void:
	var root := get_tree().current_scene
	var spawn_origin := global_position + Vector3.UP * 1.8

	# 14-18 Gold Coins
	var coin_count := randi_range(14, 18)
	for i in range(coin_count):
		var coin = loot_scene.instantiate()
		coin.item_type = 0
		coin.amount = randi_range(8, 20)
		root.add_child(coin)
		coin.global_position = spawn_origin
		var angle := randf() * TAU
		var spd := randf_range(2.5, 4.5)
		coin.velocity = Vector3(cos(angle) * spd, randf_range(4.5, 6.5), sin(angle) * spd)

	# 1 Guaranteed Rare or Epic Gear
	var gear = loot_scene.instantiate()
	gear.item_type = 2
	gear.rarity = 2 # Epic
	gear.item_name = "◆ Клинок Древних Богов"
	root.add_child(gear)
	gear.global_position = spawn_origin
	gear.velocity = Vector3(0, 5.5, 0)
