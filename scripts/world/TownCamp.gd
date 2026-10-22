class_name TownCamp
extends Node3D

@onready var campfire: Area3D = $Bonfire
@onready var stash_chest: Area3D = $StashChest
@onready var dungeon_gate: Area3D = $CampDungeonGate
@onready var town_portal_return: Area3D = $TownPortalReturn
@onready var player_node: Node3D = $Player

func _ready() -> void:
	Global.in_town = true
	Global.floor_changed.emit(0, "Лагерь Охотников")
	Global.save_game()

	if player_node:
		# Place player right by the warm campfire
		player_node.global_position = Vector3(0, 0.2, 1.8)
