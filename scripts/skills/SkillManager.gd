extends Node

# Skill Manager Singleton / Core Controller
signal skill_unlocked(skill_id: String)
signal skill_points_changed(points: int)
signal skills_updated()

# Available points for allocating
var available_skill_points: int = 2
var total_points_spent: int = 0

# Skill ranks: skill_id -> current rank (int)
var skill_ranks: Dictionary = {}

# Active skill equipped to [Q]
var active_q_skill: String = "" # e.g. "holy_hammer", "whirlwind", "thunder_slam", "iron_skin"

# Passive modifiers aggregated from all allocated skills
var bonus_max_hp: float = 0.0
var hp_regen_per_sec: float = 0.0
var lifesteal_percent: float = 0.0
var attack_damage_mult: float = 1.0
var attack_speed_mult: float = 1.0
var move_speed_mult: float = 1.0
var crit_chance_bonus: float = 0.0
var crit_damage_bonus: float = 0.0
var dash_cd_reduction: float = 0.0
var resource_regen_bonus: float = 0.0
var thorn_damage_percent: float = 0.0

# Skill Definitions Database
# type: "active", "upgrade", "passive"
# shape: "square", "diamond", "circle"
var skill_defs: Dictionary = {
	# --- North Branch: Holy Hammer (Active [Q]) ---
	"holy_hammer": {
		"id": "holy_hammer",
		"name": "Священный Молот",
		"type": "active",
		"shape": "square",
		"icon": "🔨",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(0, -140),
		"desc": "Призывает сияющие священные молоты, вращающиеся по орбите вокруг героя и сокрушающие врагов.",
		"stat_desc": "+20% к урону молотов за ранг"
	},
	"hammer_stun": {
		"id": "hammer_stun",
		"name": "Раскалывающий Шок",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "⚡",
		"max_rank": 3,
		"prereq": "holy_hammer",
		"pos": Vector2(-70, -220),
		"desc": "Удары молотов вызывают трещины в броне и оглушают врагов.",
		"stat_desc": "+15% шанса оглушить врага на 1.2 сек за ранг"
	},
	"hammer_wrath": {
		"id": "hammer_wrath",
		"name": "Двойной Молот",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "✨",
		"max_rank": 1,
		"prereq": "holy_hammer",
		"pos": Vector2(0, -235),
		"desc": "Заклинание призывает сразу два вращающихся молота света.",
		"stat_desc": "Количество молотов: 2"
	},
	"retribution_aura": {
		"id": "retribution_aura",
		"name": "Аура Возмездия",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "☀️",
		"max_rank": 3,
		"prereq": "holy_hammer",
		"pos": Vector2(70, -220),
		"desc": "Молоты излучают пульсирующие волны святого огня.",
		"stat_desc": "+12 периодического святого урона в секунду за ранг"
	},

	# --- East Branch: Whirlwind (Active [Q]) ---
	"whirlwind": {
		"id": "whirlwind",
		"name": "Вихрь Клинков",
		"type": "active",
		"shape": "square",
		"icon": "🌪️",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(150, 0),
		"desc": "Непрерывное сокрушительное круговое вращение, рассекающее всех врагов на пути.",
		"stat_desc": "+18% к урону вращения за ранг"
	},
	"whirl_vortex": {
		"id": "whirl_vortex",
		"name": "Притягивающий Вихрь",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🌀",
		"max_rank": 1,
		"prereq": "whirlwind",
		"pos": Vector2(235, -50),
		"desc": "Вихрь создает вакуумную воронку, затягивая окружающих врагов в эпицентр.",
		"stat_desc": "Притягивает врагов в радиусе 4.5м"
	},
	"blood_storm": {
		"id": "blood_storm",
		"name": "Кровавая Буря",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🩸",
		"max_rank": 3,
		"prereq": "whirlwind",
		"pos": Vector2(235, 50),
		"desc": "Каждое попадание лезвия вихря насыщает героя жизненной силой.",
		"stat_desc": "+2.5 HP лечения за каждый задетый удар за ранг"
	},

	# --- South Branch: Thunder Slam (Active [Q]) ---
	"thunder_slam": {
		"id": "thunder_slam",
		"name": "Громовой Удар",
		"type": "active",
		"shape": "square",
		"icon": "💥",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(0, 140),
		"desc": "Герой обрушивает оружие оземь, порождая сейсмическую волну колоссальной мощи.",
		"stat_desc": "+25% к урону удара по площади за ранг"
	},
	"shockwave": {
		"id": "shockwave",
		"name": "Разлом Земли",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🌋",
		"max_rank": 3,
		"prereq": "thunder_slam",
		"pos": Vector2(-70, 220),
		"desc": "Расширяет радиус ударной волны и сбивает чудовищ с ног.",
		"stat_desc": "+20% радиуса волны и усиление отбрасывания"
	},
	"chain_lightning": {
		"id": "chain_lightning",
		"name": "Цепной Разряд",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "⚡",
		"max_rank": 1,
		"prereq": "thunder_slam",
		"pos": Vector2(0, 235),
		"desc": "Эпицентр удара извергает дуги молний, поражающие 3 ближайшие цели.",
		"stat_desc": "Молния наносит 40 ед. шокового урона"
	},
	"aftershock": {
		"id": "aftershock",
		"name": "Остаточный Тремор",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🔥",
		"max_rank": 3,
		"prereq": "thunder_slam",
		"pos": Vector2(70, 220),
		"desc": "Земля раскаляется, нанося периодический урон оставшимся врагам.",
		"stat_desc": "+10 урона горения в сек на 3 сек"
	},

	# --- West Branch: Iron Skin (Active [Q]) ---
	"iron_skin": {
		"id": "iron_skin",
		"name": "Железная Кожа",
		"type": "active",
		"shape": "square",
		"icon": "🛡️",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(-150, 0),
		"desc": "Покрывает героя закаленной броней, снижая получаемый урон и даруя стойкость.",
		"stat_desc": "+8% снижения урона на 4 сек за ранг"
	},
	"thorns": {
		"id": "thorns",
		"name": "Шипастый Панцирь",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "⚔️",
		"max_rank": 3,
		"prereq": "iron_skin",
		"pos": Vector2(-235, -50),
		"desc": "Отражает часть полученного удара обратно во врага в виде шипов.",
		"stat_desc": "+20% отражения урона атакующим за ранг"
	},
	"unbreakable": {
		"id": "unbreakable",
		"name": "Непреклонность",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "👑",
		"max_rank": 1,
		"prereq": "iron_skin",
		"pos": Vector2(-235, 50),
		"desc": "Активация Железной Кожи снимает эффекты замедления и дает неуязвимость на 1.2 сек.",
		"stat_desc": "Полная неуязвимость на 1.2 сек при активации"
	},

	# --- Passives (Circles) ---
	# North-East: Attack & Crits
	"battle_fury": {
		"id": "battle_fury",
		"name": "Ярость Битвы",
		"type": "passive",
		"shape": "circle",
		"icon": "🗡️",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(95, -95),
		"desc": "Удары мечом становятся свирепее и сокрушительнее.",
		"stat_desc": "+8% урона оружия за ранг"
	},
	"deadly_strike": {
		"id": "deadly_strike",
		"name": "Смертоносный Клинок",
		"type": "passive",
		"shape": "circle",
		"icon": "🎯",
		"max_rank": 3,
		"prereq": "battle_fury",
		"pos": Vector2(170, -165),
		"desc": "Повышает вероятность и силу критических рассечений.",
		"stat_desc": "+5% к шансу крита, +20% к критическому урону за ранг"
	},

	# South-East: Lifesteal & Attack Speed
	"bloodthirst": {
		"id": "bloodthirst",
		"name": "Жажда Крови",
		"type": "passive",
		"shape": "circle",
		"icon": "🩸",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(95, 95),
		"desc": "Каждое попадание вытягивает жизненную силу из поверженных противников.",
		"stat_desc": "+4% вампиризма при любых ударах за ранг"
	},
	"furious_tempo": {
		"id": "furious_tempo",
		"name": "Бешеный Ритм",
		"type": "passive",
		"shape": "circle",
		"icon": "⚡",
		"max_rank": 3,
		"prereq": "bloodthirst",
		"pos": Vector2(170, 165),
		"desc": "Увеличивает скорость проведения базовых взмахов и атак.",
		"stat_desc": "+7% к скорости атаки за ранг"
	},

	# South-West: Mobility & Resource
	"fleet_foot": {
		"id": "fleet_foot",
		"name": "Быстрая Поступь",
		"type": "passive",
		"shape": "circle",
		"icon": "👟",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(-95, 95),
		"desc": "Облегчает доспехи, увеличивая скорость бега и маневренность.",
		"stat_desc": "+6% скорости передвижения, -0.06с КД рывка за ранг"
	},
	"second_wind": {
		"id": "second_wind",
		"name": "Второе Дыхание",
		"type": "passive",
		"shape": "circle",
		"icon": "💧",
		"max_rank": 3,
		"prereq": "fleet_foot",
		"pos": Vector2(-170, 165),
		"desc": "Ускоряет естественное восполнение боевой ярости / маны.",
		"stat_desc": "+6 ед. генерации ресурса в секунду за ранг"
	},

	# North-West: Defense & HP Regen
	"juggernaut": {
		"id": "juggernaut",
		"name": "Несокрушимость",
		"type": "passive",
		"shape": "circle",
		"icon": "❤️",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(-95, -95),
		"desc": "Закаляет дух и плоть воителя, увеличивая запас здоровья.",
		"stat_desc": "+30 к максимальному здоровью за ранг"
	},
	"vital_surge": {
		"id": "vital_surge",
		"name": "Живая Кровь",
		"type": "passive",
		"shape": "circle",
		"icon": "🌿",
		"max_rank": 3,
		"prereq": "juggernaut",
		"pos": Vector2(-170, -165),
		"desc": "Непрерывно залечивает раны прямо во время боя.",
		"stat_desc": "+2.5 HP/сек пассивной регенерации за ранг"
	}
}

func _ready() -> void:
	Global.player_xp_changed.connect(_on_xp_changed)
	recalculate_stats()

func _on_xp_changed(_current: int, _needed: int, level: int) -> void:
	if level > Global.player_level:
		var levels_gained: int = level - Global.player_level
		available_skill_points += levels_gained
		Global.player_level = level
		skill_points_changed.emit(available_skill_points)

func add_skill_point(amount: int = 1) -> void:
	available_skill_points += amount
	skill_points_changed.emit(available_skill_points)

func get_skill_rank(id: String) -> int:
	return skill_ranks.get(id, 0)

func is_skill_unlocked(id: String) -> bool:
	return get_skill_rank(id) > 0

func can_upgrade_skill(id: String) -> bool:
	if available_skill_points <= 0:
		return false
	if not skill_defs.has(id):
		return false
	var def: Dictionary = skill_defs[id]
	var current_rank: int = get_skill_rank(id)
	if current_rank >= def["max_rank"]:
		return false
	# Check prerequisite
	var prereq: String = def["prereq"]
	if prereq != "" and get_skill_rank(prereq) <= 0:
		return false
	return true

func can_refund_skill(id: String) -> bool:
	var current_rank: int = get_skill_rank(id)
	if current_rank <= 0:
		return false
	# Cannot refund if any active child node depends on this being >= 1
	if current_rank == 1:
		for other_id in skill_defs.keys():
			if skill_defs[other_id]["prereq"] == id and get_skill_rank(other_id) > 0:
				return false
	return true

func upgrade_skill(id: String) -> bool:
	if not can_upgrade_skill(id):
		return false

	available_skill_points -= 1
	total_points_spent += 1
	var new_rank: int = get_skill_rank(id) + 1
	skill_ranks[id] = new_rank

	var def: Dictionary = skill_defs[id]
	if def["type"] == "active":
		# Auto-equip if no Q skill equipped
		if active_q_skill == "":
			active_q_skill = id

	recalculate_stats()
	skill_points_changed.emit(available_skill_points)
	skill_unlocked.emit(id)
	skills_updated.emit()
	return true

# Backwards compatibility alias for single unlock
func unlock_skill(id: String) -> bool:
	return upgrade_skill(id)

func refund_skill(id: String) -> bool:
	if not can_refund_skill(id):
		return false

	skill_ranks[id] = get_skill_rank(id) - 1
	available_skill_points += 1
	total_points_spent -= 1

	if skill_ranks[id] <= 0:
		skill_ranks.erase(id)
		if active_q_skill == id:
			_auto_select_fallback_q_skill()

	recalculate_stats()
	skill_points_changed.emit(available_skill_points)
	skills_updated.emit()
	return true

func reset_all_skills() -> void:
	available_skill_points += total_points_spent
	total_points_spent = 0
	skill_ranks.clear()
	active_q_skill = ""
	recalculate_stats()
	skill_points_changed.emit(available_skill_points)
	skills_updated.emit()

func set_active_q_skill(id: String) -> void:
	if get_skill_rank(id) > 0 and skill_defs.has(id) and skill_defs[id]["type"] == "active":
		active_q_skill = id
		skills_updated.emit()

func _auto_select_fallback_q_skill() -> void:
	active_q_skill = ""
	for id in ["holy_hammer", "whirlwind", "thunder_slam", "iron_skin"]:
		if get_skill_rank(id) > 0:
			active_q_skill = id
			break

func recalculate_stats() -> void:
	# Reset defaults
	bonus_max_hp = 30.0 * get_skill_rank("juggernaut")
	hp_regen_per_sec = 2.5 * get_skill_rank("vital_surge")
	lifesteal_percent = 0.04 * get_skill_rank("bloodthirst")
	attack_damage_mult = 1.0 + (0.08 * get_skill_rank("battle_fury"))
	attack_speed_mult = 1.0 + (0.07 * get_skill_rank("furious_tempo"))
	move_speed_mult = 1.0 + (0.06 * get_skill_rank("fleet_foot"))
	dash_cd_reduction = 0.06 * get_skill_rank("fleet_foot")
	crit_chance_bonus = 0.05 * get_skill_rank("deadly_strike")
	crit_damage_bonus = 0.20 * get_skill_rank("deadly_strike")
	resource_regen_bonus = 6.0 * get_skill_rank("second_wind")
	thorn_damage_percent = 0.20 * get_skill_rank("thorns")

	_refresh_player_stats()

func _refresh_player_stats() -> void:
	var pc: PlayerController = Global.current_player as PlayerController
	if pc and is_instance_valid(pc):
		var base_hp := 150.0
		var new_max := base_hp + bonus_max_hp
		pc.max_health = new_max
		pc.health = minf(pc.health, new_max)
		pc.speed = 6.8 * move_speed_mult
		pc.dash_cooldown = maxf(0.3, 0.65 - dash_cd_reduction)
		pc.attack_cooldown = maxf(0.2, 0.38 / attack_speed_mult)
		pc.resource_regen_rate = 15.0 + resource_regen_bonus
		Global.player_health_changed.emit(pc.health, pc.max_health)
