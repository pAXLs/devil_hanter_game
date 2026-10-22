class_name VenomSpitterSpider
extends BaseEnemy

var poison_cloud_scene: PackedScene = preload("res://scenes/combat/PoisonCloud.tscn")
var spit_timer: float = 0.0
@export var spit_interval: float = 3.2

func _ready() -> void:
	max_health = 60.0
	health = 60.0
	speed = 4.2
	attack_damage = 14.0
	attack_cooldown = 1.8
	attack_range = 6.5
	xp_reward = 22
	gold_min = 3
	gold_max = 8
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	spit_timer += delta
	var target = Global.current_player
	if target and is_instance_valid(target) and not is_dead:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range and spit_timer >= spit_interval:
			spit_timer = 0.0
			_spit_acid(target.global_position)

func _spit_acid(target_pos: Vector3) -> void:
	if not poison_cloud_scene:
		return
	var cloud = poison_cloud_scene.instantiate()
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = target_pos
	if cloud.has_method("setup"):
		cloud.setup(self, attack_damage * 0.65, 4.0)
