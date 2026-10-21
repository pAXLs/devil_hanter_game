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

	# Manual pickup on [F]: Zero magnetic suction! Player decides when to pick up.
	var player: Node3D = Global.current_player
	if player and is_instance_valid(player) and not is_being_picked_up:
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= pickup_radius:
			if label:
				label.visible = true
				label.text = "[F] " + base_display_name

			if Input.is_action_just_pressed("interact"):
				_collect(player)
		else:
			if label:
				label.text = base_display_name
				label.visible = (item_type != TYPE_GOLD)

func _collect(player: Node3D) -> void:
	is_being_picked_up = true

	match item_type:
		TYPE_GOLD:
			Global.player_gold += amount
		TYPE_POTION_HP:
			if player is PlayerController:
				var pc: PlayerController = player as PlayerController
				var heal: float = minf(45.0, pc.max_health - pc.health)
				if heal > 0:
					pc.health += heal
					Global.player_health_changed.emit(pc.health, pc.max_health)
					Global.damage_spawned.emit(player.global_position + Vector3.UP * 1.5, int(heal), true, false)
		TYPE_WEAPON, TYPE_ARMOR:
			Global.player_gold += 20
			if player is PlayerController:
				var pc: PlayerController = player as PlayerController
				pc.attack_damage += 4.0
				Global.damage_spawned.emit(player.global_position + Vector3.UP * 2.0, 4, true, false)

	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3(0.01, 0.01, 0.01), 0.12)
	tween.tween_callback(queue_free)
