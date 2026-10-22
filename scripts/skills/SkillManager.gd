extends Node

# Skill Manager Singleton / Core Controller
signal skill_unlocked(skill_id: String)
signal skill_points_changed(points: int)
signal skills_updated()

# Available points for allocating
var available_skill_points: int = 2
var total_points_spent: int = 0

# Active class tracking and persistence
var current_class_id: String = Global.CLASS_WARRIOR

# Skill ranks per class: class_id -> { skill_id: rank }
var class_skill_ranks: Dictionary = {
	Global.CLASS_WARRIOR: {},
	Global.CLASS_ROGUE: {},
	Global.CLASS_MAGE: {}
}

# Active Q skill per class
var class_active_q: Dictionary = {
	Global.CLASS_WARRIOR: "holy_hammer",
	Global.CLASS_ROGUE: "rain_of_arrows",
	Global.CLASS_MAGE: "fireball"
}

# Current active skill ranks and Q skill pointer (synced with class_skill_ranks)
var skill_ranks: Dictionary = {}
var active_q_skill: String = "holy_hammer"

# Passive modifiers aggregated from active class allocated skills
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

# --- WARRIOR SKILL TREE ---
const WARRIOR_SKILLS: Dictionary = {
	# North: Holy Hammer
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
		"stat_desc": "+12 святого урона в секунду за ранг"
	},

	# East: Whirlwind
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

	# South: Thunder Slam
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
	"chain_shock": {
		"id": "chain_shock",
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

	# West: Iron Skin
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

	# Passives
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
		"desc": "Ускоряет естественное восполнение боевой ярости.",
		"stat_desc": "+6 ед. генерации ресурса в секунду за ранг"
	},
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

# --- ROGUE SKILL TREE ---
const ROGUE_SKILLS: Dictionary = {
	# North: Rain of Arrows
	"rain_of_arrows": {
		"id": "rain_of_arrows",
		"name": "Град Стрел",
		"type": "active",
		"shape": "square",
		"icon": "🏹",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(0, -140),
		"desc": "Выпускает веер из 5 смертоносных стрел в конусе перед собой, пронзающих всех врагов.",
		"stat_desc": "+22% к урону залпа за ранг"
	},
	"piercing_arrows": {
		"id": "piercing_arrows",
		"name": "Пробивающие Стрелы",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🗡️",
		"max_rank": 3,
		"prereq": "rain_of_arrows",
		"pos": Vector2(-70, -220),
		"desc": "Стрелы пробивают цели насквозь и игнорируют броню противника.",
		"stat_desc": "+12% игнорирования брони за ранг"
	},
	"arrow_flurry": {
		"id": "arrow_flurry",
		"name": "Шквал Стрел",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "✨",
		"max_rank": 1,
		"prereq": "rain_of_arrows",
		"pos": Vector2(0, -235),
		"desc": "Количество стрел в залпе увеличено с 5 до 7.",
		"stat_desc": "Выпускает 7 стрел вместо 5"
	},
	"crippling_shot": {
		"id": "crippling_shot",
		"name": "Калечащий Залп",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🕸️",
		"max_rank": 3,
		"prereq": "rain_of_arrows",
		"pos": Vector2(70, -220),
		"desc": "Стрелы ранят сухожилия, замедляя врагов при попадании.",
		"stat_desc": "Замедление на 40% на 2.5 сек"
	},

	# East: Shadowstep
	"shadowstep": {
		"id": "shadowstep",
		"name": "Теневой Шаг",
		"type": "active",
		"shape": "square",
		"icon": "👤",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(150, 0),
		"desc": "Мгновенный рывок сквозь тени в сторону прицела, наносящий сокрушительный удар кинжалом.",
		"stat_desc": "+25% к урону теневого удара за ранг"
	},
	"smoke_poof": {
		"id": "smoke_poof",
		"name": "Дымовая Завеса",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "💨",
		"max_rank": 1,
		"prereq": "shadowstep",
		"pos": Vector2(235, -50),
		"desc": "При скачке оставляет дымовое облако, дающее кратковременную невидимость.",
		"stat_desc": "Неуязвимость на 1.0 сек после скачка"
	},
	"assassin_reset": {
		"id": "assassin_reset",
		"name": "Смертельный Порыв",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🩸",
		"max_rank": 3,
		"prereq": "shadowstep",
		"pos": Vector2(235, 50),
		"desc": "Убийство врагов ускоряет восстановление энергии и умения.",
		"stat_desc": "+20 энергии при поражении цели"
	},

	# South: Poison Trap
	"poison_trap": {
		"id": "poison_trap",
		"name": "Ядовитая Ловушка",
		"type": "active",
		"shape": "square",
		"icon": "🧪",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(0, 140),
		"desc": "Устанавливает на землю мину, детонирующую ядовитым облаком при приближении врагов.",
		"stat_desc": "+20% к урону токсина за ранг"
	},
	"toxic_fumes": {
		"id": "toxic_fumes",
		"name": "Токсичные Испарения",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "☣️",
		"max_rank": 3,
		"prereq": "poison_trap",
		"pos": Vector2(-70, 220),
		"desc": "Увеличивает радиус поражения ядовитого облака.",
		"stat_desc": "+15% радиуса облака за ранг"
	},
	"paralyzing_toxin": {
		"id": "paralyzing_toxin",
		"name": "Парализующий Яд",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "⚡",
		"max_rank": 1,
		"prereq": "poison_trap",
		"pos": Vector2(0, 235),
		"desc": "Взрыв ловушки оглушает врагов в эпицентре на 1.5 секунды.",
		"stat_desc": "Оглушение эпицентра на 1.5 сек"
	},
	"corrosive_acid": {
		"id": "corrosive_acid",
		"name": "Едкая Кислота",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "💀",
		"max_rank": 3,
		"prereq": "poison_trap",
		"pos": Vector2(70, 220),
		"desc": "Яд разъедает броню чудовищ, ослабляя их защиту.",
		"stat_desc": "Снижение брони врагов в яде на 35%"
	},

	# West: Hunter's Focus
	"hunters_focus": {
		"id": "hunters_focus",
		"name": "Фокус Охотника",
		"type": "active",
		"shape": "square",
		"icon": "🦅",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(-150, 0),
		"desc": "Герой концентрируется на 5 сек: возрастает скорость стрельбы и вероятность критов.",
		"stat_desc": "+8% скорости атаки и +5% шанса крита за ранг"
	},
	"wind_runner": {
		"id": "wind_runner",
		"name": "Бегущий по Ветру",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "👟",
		"max_rank": 3,
		"prereq": "hunters_focus",
		"pos": Vector2(-235, -50),
		"desc": "Во время Фокуса скорость передвижения возрастает на 30%.",
		"stat_desc": "+10% скорости бега за ранг"
	},
	"sharpshooter": {
		"id": "sharpshooter",
		"name": "Снайпер",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🎯",
		"max_rank": 1,
		"prereq": "hunters_focus",
		"pos": Vector2(-235, 50),
		"desc": "Критические выстрелы во время фокуса наносят +50% дополнительного урона.",
		"stat_desc": "+50% критического урона во время фокуса"
	},

	# Passives
	"keen_eye": {
		"id": "keen_eye",
		"name": "Зоркий Глаз",
		"type": "passive",
		"shape": "circle",
		"icon": "👁️",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(95, -95),
		"desc": "Повышает меткость и базовый урон всех стрелковых и скрытных атак.",
		"stat_desc": "+8% урона оружия за ранг"
	},
	"fatal_precision": {
		"id": "fatal_precision",
		"name": "Смертоносная Точность",
		"type": "passive",
		"shape": "circle",
		"icon": "🎯",
		"max_rank": 3,
		"prereq": "keen_eye",
		"pos": Vector2(170, -165),
		"desc": "Стрелы поражают уязвимые точки со смертельной вероятностью.",
		"stat_desc": "+6% шанса крита и +25% крит. урона за ранг"
	},
	"vital_cut": {
		"id": "vital_cut",
		"name": "Вампирический Надрез",
		"type": "passive",
		"shape": "circle",
		"icon": "🩸",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(95, 95),
		"desc": "Критические попадания восстанавливают здоровье героя.",
		"stat_desc": "+4% вампиризма за ранг"
	},
	"swiftness": {
		"id": "swiftness",
		"name": "Неуловимость",
		"type": "passive",
		"shape": "circle",
		"icon": "⚡",
		"max_rank": 3,
		"prereq": "vital_cut",
		"pos": Vector2(170, 165),
		"desc": "Увеличивает темп стрельбы и скорость рывков.",
		"stat_desc": "+8% к скорости атаки за ранг"
	},
	"shadow_reflexes": {
		"id": "shadow_reflexes",
		"name": "Теневые Рефлексы",
		"type": "passive",
		"shape": "circle",
		"icon": "👟",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(-95, 95),
		"desc": "Ловкач двигается бесшумно и стремительно.",
		"stat_desc": "+7% скорости бега, -0.08с КД рывка за ранг"
	},
	"energy_surge": {
		"id": "energy_surge",
		"name": "Прилив Энергии",
		"type": "passive",
		"shape": "circle",
		"icon": "💧",
		"max_rank": 3,
		"prereq": "shadow_reflexes",
		"pos": Vector2(-170, 165),
		"desc": "Ускоряет базовую регенерацию энергии следопыта.",
		"stat_desc": "+5 ед. генерации энергии в сек за ранг"
	},
	"evasion": {
		"id": "evasion",
		"name": "Уклонение",
		"type": "passive",
		"shape": "circle",
		"icon": "🛡️",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(-95, -95),
		"desc": "Дарует дополнительную живучесть и уворотливость в пылу боя.",
		"stat_desc": "+25 HP за ранг"
	},
	"adrenalin": {
		"id": "adrenalin",
		"name": "Адреналин",
		"type": "passive",
		"shape": "circle",
		"icon": "🌿",
		"max_rank": 3,
		"prereq": "evasion",
		"pos": Vector2(-170, -165),
		"desc": "Постоянная регенерация здоровья благодаря адреналину.",
		"stat_desc": "+2.2 HP/сек регенерации за ранг"
	}
}

# --- MAGE SKILL TREE ---
const MAGE_SKILLS: Dictionary = {
	# North: Fireball
	"fireball": {
		"id": "fireball",
		"name": "Огненный Шар",
		"type": "active",
		"shape": "square",
		"icon": "🔥",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(0, -140),
		"desc": "Запускает гигантский шар пламени, детонирующий при контакте мощным взрывом по площади.",
		"stat_desc": "+25% к урону взрыва за ранг"
	},
	"ignite": {
		"id": "ignite",
		"name": "Воспламенение",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "💥",
		"max_rank": 3,
		"prereq": "fireball",
		"pos": Vector2(-70, -220),
		"desc": "Поджигает пораженных чудовищ, нанося периодический огонь на 3 сек.",
		"stat_desc": "+15 огненного урона в сек на 3 сек"
	},
	"mega_blast": {
		"id": "mega_blast",
		"name": "Колоссальный Взрыв",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🌋",
		"max_rank": 1,
		"prereq": "fireball",
		"pos": Vector2(0, -235),
		"desc": "Радиус детонации огненного шара увеличен на 45%.",
		"stat_desc": "Радиус взрыва: 6.0м"
	},
	"conflagration": {
		"id": "conflagration",
		"name": "Пожарище",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "☀️",
		"max_rank": 3,
		"prereq": "fireball",
		"pos": Vector2(70, -220),
		"desc": "Взрыв разбрасывает раскаленные угли, усиливающие урон по площади.",
		"stat_desc": "+20% к урону по раненым целям"
	},

	# East: Frost Nova
	"frost_nova": {
		"id": "frost_nova",
		"name": "Кольцо Льда",
		"type": "active",
		"shape": "square",
		"icon": "❄️",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(150, 0),
		"desc": "Извергает арктическую волну во все стороны, сковывающую льдом всех врагов вокруг мага.",
		"stat_desc": "+20% урона холодом и длительность заморозки"
	},
	"deep_freeze": {
		"id": "deep_freeze",
		"name": "Глубокая Заморозка",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🧊",
		"max_rank": 1,
		"prereq": "frost_nova",
		"pos": Vector2(235, -50),
		"desc": "Замороженные цели получают на 35% больше урона от любых последующих атак.",
		"stat_desc": "+35% получаемого урона замороженными"
	},
	"ice_shatter": {
		"id": "ice_shatter",
		"name": "Ледяные Осколки",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "💎",
		"max_rank": 3,
		"prereq": "frost_nova",
		"pos": Vector2(235, 50),
		"desc": "При раскалывании льда враги извергают острые ледяные шипы во все стороны.",
		"stat_desc": "+30 ед. осколочного урона"
	},

	# South: Chain Lightning
	"chain_lightning": {
		"id": "chain_lightning",
		"name": "Цепная Молния",
		"type": "active",
		"shape": "square",
		"icon": "⚡",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(0, 140),
		"desc": "Поражает цель мощным разрядом электричества, рикошетящим в 4 соседних врагов.",
		"stat_desc": "+22% к урону молний за ранг"
	},
	"high_voltage": {
		"id": "high_voltage",
		"name": "Высокое Напряжение",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🔋",
		"max_rank": 3,
		"prereq": "chain_lightning",
		"pos": Vector2(-70, 220),
		"desc": "Каждый последующий скачок разряда наносит на 20% больше урона.",
		"stat_desc": "+20% урона за каждый рикошет"
	},
	"static_stun": {
		"id": "static_stun",
		"name": "Статический Шок",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "✨",
		"max_rank": 1,
		"prereq": "chain_lightning",
		"pos": Vector2(0, 235),
		"desc": "Удар молнии парализует врагов на 1.2 секунды.",
		"stat_desc": "Оглушение целей на 1.2 сек"
	},
	"thunderstorm": {
		"id": "thunderstorm",
		"name": "Грозовой Шторм",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🌩️",
		"max_rank": 3,
		"prereq": "chain_lightning",
		"pos": Vector2(70, 220),
		"desc": "Увеличивает число поражаемых целей разрядом с 4 до 6.",
		"stat_desc": "Поражает до 6 противников"
	},

	# West: Arcane Blink
	"arcane_blink": {
		"id": "arcane_blink",
		"name": "Астральный Скачок",
		"type": "active",
		"shape": "square",
		"icon": "🔮",
		"max_rank": 5,
		"prereq": "",
		"pos": Vector2(-150, 0),
		"desc": "Мгновенно перемещает мага в точку прицела, создавая волну тайной энергии.",
		"stat_desc": "+20% урона волны и снижение КД"
	},
	"arcane_barrier": {
		"id": "arcane_barrier",
		"name": "Эфирный Барьер",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🛡️",
		"max_rank": 3,
		"prereq": "arcane_blink",
		"pos": Vector2(-235, -50),
		"desc": "После скачка маг получает щит, поглощающий урон на 3.5 секунды.",
		"stat_desc": "Поглощает до 60 ед. урона за ранг"
	},
	"space_rupture": {
		"id": "space_rupture",
		"name": "Разрыв Пространства",
		"type": "upgrade",
		"shape": "diamond",
		"icon": "🌀",
		"max_rank": 1,
		"prereq": "arcane_blink",
		"pos": Vector2(-235, 50),
		"desc": "На месте отправления и прибытия разрывается пространство, сбивая чудовищ с ног.",
		"stat_desc": "Сбивает окружающих врагов с ног"
	},

	# Passives
	"arcane_mind": {
		"id": "arcane_mind",
		"name": "Тайный Разум",
		"type": "passive",
		"shape": "circle",
		"icon": "📖",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(95, -95),
		"desc": "Раскрывает сокровенные тайны магии, увеличивая урон всех заклинаний.",
		"stat_desc": "+9% урона заклинаний за ранг"
	},
	"mystic_mastery": {
		"id": "mystic_mastery",
		"name": "Мистический Пробой",
		"type": "passive",
		"shape": "circle",
		"icon": "🎯",
		"max_rank": 3,
		"prereq": "arcane_mind",
		"pos": Vector2(170, -165),
		"desc": "Магические сферы и заклинания пробивают защиту врагов с критической силой.",
		"stat_desc": "+6% шанса крита и +25% крит. урона за ранг"
	},
	"mana_flow": {
		"id": "mana_flow",
		"name": "Поток Маны",
		"type": "passive",
		"shape": "circle",
		"icon": "💧",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(95, 95),
		"desc": "Ускоряет естественное восстановление запаса маны.",
		"stat_desc": "+8 ед. маны в сек за ранг"
	},
	"spell_power": {
		"id": "spell_power",
		"name": "Скорость Плетения",
		"type": "passive",
		"shape": "circle",
		"icon": "⚡",
		"max_rank": 3,
		"prereq": "mana_flow",
		"pos": Vector2(170, 165),
		"desc": "Увеличивает темп сотворения базовых магических зарядов.",
		"stat_desc": "+8% к скорости атаки за ранг"
	},
	"aether_stride": {
		"id": "aether_stride",
		"name": "Поступь Эфира",
		"type": "passive",
		"shape": "circle",
		"icon": "👟",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(-95, 95),
		"desc": "Тело мага становится легким как эфир, ускоряя перемещение.",
		"stat_desc": "+6% скорости бега, -0.06с КД рывка за ранг"
	},
	"elemental_ward": {
		"id": "elemental_ward",
		"name": "Стихийный Оплот",
		"type": "passive",
		"shape": "circle",
		"icon": "🛡️",
		"max_rank": 3,
		"prereq": "aether_stride",
		"pos": Vector2(-170, 165),
		"desc": "Стихийный покров увеличивает здоровье и выносливость мага.",
		"stat_desc": "+25 к максимальному здоровью за ранг"
	},
	"equilibrium": {
		"id": "equilibrium",
		"name": "Равновесие",
		"type": "passive",
		"shape": "circle",
		"icon": "🌿",
		"max_rank": 3,
		"prereq": "",
		"pos": Vector2(-95, -95),
		"desc": "Гармония стихий непрерывно залечивает раны мага.",
		"stat_desc": "+2.2 HP/сек пассивной регенерации за ранг"
	},
	"mana_shield": {
		"id": "mana_shield",
		"name": "Щит Маны",
		"type": "passive",
		"shape": "circle",
		"icon": "✨",
		"max_rank": 3,
		"prereq": "equilibrium",
		"pos": Vector2(-170, -165),
		"desc": "При критическом ударе часть урона обращается в здоровье.",
		"stat_desc": "+3.5% вампиризма за ранг"
	}
}

# Active skill database pointer (points to current class's skill dict)
var skill_defs: Dictionary = WARRIOR_SKILLS

func _ready() -> void:
	Global.player_xp_changed.connect(_on_xp_changed)
	Global.class_changed.connect(_on_class_changed)
	_load_class_skills(Global.current_class)

func _on_class_changed(new_c: String) -> void:
	_load_class_skills(new_c)

func _load_class_skills(c_id: String) -> void:
	# 1. Save previous state into previous class slot
	if current_class_id != "":
		class_skill_ranks[current_class_id] = skill_ranks.duplicate()
		class_active_q[current_class_id] = active_q_skill

	current_class_id = c_id

	# 2. Select appropriate skill definition database
	match current_class_id:
		Global.CLASS_ROGUE:
			skill_defs = ROGUE_SKILLS
		Global.CLASS_MAGE:
			skill_defs = MAGE_SKILLS
		_:
			skill_defs = WARRIOR_SKILLS

	# 3. Restore saved ranks for this class
	if not class_skill_ranks.has(current_class_id):
		class_skill_ranks[current_class_id] = {}

	skill_ranks = class_skill_ranks[current_class_id]
	active_q_skill = class_active_q.get(current_class_id, "")

	if active_q_skill == "":
		_auto_select_fallback_q_skill()

	recalculate_stats()
	skills_updated.emit()

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
	var prereq: String = def["prereq"]
	if prereq != "" and get_skill_rank(prereq) <= 0:
		return false
	return true

func can_refund_skill(id: String) -> bool:
	var current_rank: int = get_skill_rank(id)
	if current_rank <= 0:
		return false
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
		if active_q_skill == "":
			active_q_skill = id
			class_active_q[current_class_id] = id

	recalculate_stats()
	skill_points_changed.emit(available_skill_points)
	skill_unlocked.emit(id)
	skills_updated.emit()
	return true

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
	class_skill_ranks[current_class_id] = {}
	active_q_skill = ""
	class_active_q[current_class_id] = ""
	recalculate_stats()
	skill_points_changed.emit(available_skill_points)
	skills_updated.emit()

func set_active_q_skill(id: String) -> void:
	if get_skill_rank(id) > 0 and skill_defs.has(id) and skill_defs[id]["type"] == "active":
		active_q_skill = id
		class_active_q[current_class_id] = id
		skills_updated.emit()

func _auto_select_fallback_q_skill() -> void:
	active_q_skill = ""
	for id in skill_defs.keys():
		if skill_defs[id]["type"] == "active" and get_skill_rank(id) > 0:
			active_q_skill = id
			break
	class_active_q[current_class_id] = active_q_skill

func recalculate_stats() -> void:
	# Reset baseline
	bonus_max_hp = 0.0
	hp_regen_per_sec = 0.0
	lifesteal_percent = 0.0
	attack_damage_mult = 1.0
	attack_speed_mult = 1.0
	move_speed_mult = 1.0
	dash_cd_reduction = 0.0
	crit_chance_bonus = 0.0
	crit_damage_bonus = 0.0
	resource_regen_bonus = 0.0
	thorn_damage_percent = 0.0

	match current_class_id:
		Global.CLASS_WARRIOR:
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

		Global.CLASS_ROGUE:
			bonus_max_hp = 25.0 * get_skill_rank("evasion")
			hp_regen_per_sec = 2.2 * get_skill_rank("adrenalin")
			lifesteal_percent = 0.04 * get_skill_rank("vital_cut")
			attack_damage_mult = 1.0 + (0.08 * get_skill_rank("keen_eye"))
			attack_speed_mult = 1.0 + (0.08 * get_skill_rank("swiftness"))
			move_speed_mult = 1.0 + (0.07 * get_skill_rank("shadow_reflexes"))
			dash_cd_reduction = 0.08 * get_skill_rank("shadow_reflexes")
			crit_chance_bonus = 0.06 * get_skill_rank("fatal_precision")
			crit_damage_bonus = 0.25 * get_skill_rank("fatal_precision")
			resource_regen_bonus = 5.0 * get_skill_rank("energy_surge")

		Global.CLASS_MAGE:
			bonus_max_hp = 25.0 * get_skill_rank("elemental_ward")
			hp_regen_per_sec = 2.2 * get_skill_rank("equilibrium")
			lifesteal_percent = 0.035 * get_skill_rank("mana_shield")
			attack_damage_mult = 1.0 + (0.09 * get_skill_rank("arcane_mind"))
			attack_speed_mult = 1.0 + (0.08 * get_skill_rank("spell_power"))
			move_speed_mult = 1.0 + (0.06 * get_skill_rank("aether_stride"))
			dash_cd_reduction = 0.06 * get_skill_rank("aether_stride")
			crit_chance_bonus = 0.06 * get_skill_rank("mystic_mastery")
			crit_damage_bonus = 0.25 * get_skill_rank("mystic_mastery")
			resource_regen_bonus = 8.0 * get_skill_rank("mana_flow")

	_refresh_player_stats()

func _refresh_player_stats() -> void:
	var pc: PlayerController = Global.current_player as PlayerController
	if pc and is_instance_valid(pc):
		var info: Dictionary = Global.get_class_info(current_class_id)
		var class_base_hp: float = info.get("base_hp", 150.0) if not info.is_empty() else 150.0
		var new_max: float = class_base_hp + bonus_max_hp + InventoryManager.bonus_max_hp
		pc.max_health = new_max
		pc.health = minf(pc.health, new_max)
		var base_spd: float = info.get("speed", 6.8) if not info.is_empty() else 6.8
		pc.speed = base_spd * move_speed_mult
		pc.dash_cooldown = maxf(0.25, 0.65 - dash_cd_reduction)
		pc.attack_cooldown = maxf(0.2, 0.38 / attack_speed_mult)
		Global.player_health_changed.emit(pc.health, pc.max_health)

func get_save_data() -> Dictionary:
	return {
		"available_skill_points": available_skill_points,
		"total_points_spent": total_points_spent,
		"class_skill_ranks": class_skill_ranks.duplicate(true),
		"class_active_q": class_active_q.duplicate(true),
		"active_q_skill": active_q_skill
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("available_skill_points"):
		available_skill_points = int(data["available_skill_points"])
	if data.has("total_points_spent"):
		total_points_spent = int(data["total_points_spent"])
	if data.has("class_skill_ranks") and data["class_skill_ranks"] is Dictionary:
		class_skill_ranks = data["class_skill_ranks"]
	if data.has("class_active_q") and data["class_active_q"] is Dictionary:
		class_active_q = data["class_active_q"]
	_load_class_skills(current_class_id)
	if data.has("active_q_skill") and String(data["active_q_skill"]) != "":
		active_q_skill = String(data["active_q_skill"])
	recalculate_stats()
