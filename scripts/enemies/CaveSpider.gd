class_name CaveSpider
extends BaseEnemy

# Small, fast, aggressive swarm spider
func _ready() -> void:
	max_health = 35.0
	health = 35.0
	speed = 6.2 # Fast scuttling movement
	attack_damage = 8.0
	attack_cooldown = 0.55
	attack_range = 1.3
	xp_reward = 12
	gold_min = 1
	gold_max = 4
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Fast skittering visual tilt/wobble while moving
	if velocity.length() > 0.5 and visuals:
		visuals.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.12
	elif visuals:
		visuals.rotation.z = 0.0
