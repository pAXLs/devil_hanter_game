extends Node

# Skill Manager Singleton / Core Controller
signal skill_unlocked(skill_id: String)
signal skill_points_changed(points: int)

var available_skill_points: int = 1
var unlocked_skills: Dictionary = {}

# Active skill bound to [Q]
var active_q_skill: String = "" # "holy_hammer" or "whirlwind"

# Passive bonuses aggregated from tree
var bonus_max_hp_percent: float = 0.0
var hp_regen_per_sec: float = 0.0
var lifesteal_percent: float = 0.0
var attack_speed_mult: float = 1.0
var move_speed_mult: float = 1.0
var thorn_damage_percent: float = 0.0

func _ready() -> void:
	Global.player_xp_changed.connect(_on_xp_changed)

func _on_xp_changed(current: int, needed: int, level: int) -> void:
	# Check if level increased
	if level > Global.player_level:
		var levels_gained := level - Global.player_level
		available_skill_points += levels_gained
		Global.player_level = level
		skill_points_changed.emit(available_skill_points)

func add_skill_point(amount: int = 1) -> void:
	available_skill_points += amount
	skill_points_changed.emit(available_skill_points)

func is_skill_unlocked(skill_id: String) -> bool:
	return unlocked_skills.get(skill_id, false)

func unlock_skill(skill_id: String) -> bool:
	if available_skill_points <= 0 or is_skill_unlocked(skill_id):
		return false

	available_skill_points -= 1
	unlocked_skills[skill_id] = true
	_apply_skill_effect(skill_id)
	skill_points_changed.emit(available_skill_points)
	skill_unlocked.emit(skill_id)
	return true

func _apply_skill_effect(skill_id: String) -> void:
	match skill_id:
		# --- ПАЛАДИН ---
		"paladin_resilience":
			bonus_max_hp_percent += 0.25
			hp_regen_per_sec += 3.0
			_refresh_player_stats()
		"holy_hammer":
			active_q_skill = "holy_hammer"
		"retribution_aura":
			thorn_damage_percent += 0.25
		"paladin_earthshaker":
			# Upgrades R ultimate damage by 50%
			pass

		# --- БЕРСЕРК ---
		"bloodthirst":
			lifesteal_percent += 0.15 # 15% life steal on hit
		"whirlwind":
			active_q_skill = "whirlwind"
		"furious_charge":
			move_speed_mult += 0.20
			attack_speed_mult += 0.25
			_refresh_player_stats()
		"titan_wrath":
			# Upgrades R ultimate into Titan mode
			pass

func _refresh_player_stats() -> void:
	var pc: PlayerController = Global.current_player as PlayerController
	if pc and is_instance_valid(pc):
		var base_hp := 150.0
		var new_max := base_hp * (1.0 + bonus_max_hp_percent)
		pc.max_health = new_max
		pc.health = minf(pc.health, new_max)
		pc.speed = 6.8 * move_speed_mult
		Global.player_health_changed.emit(pc.health, pc.max_health)
