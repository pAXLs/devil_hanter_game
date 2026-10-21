class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $BottomBar/HBox/HealthContainer/HealthBar
@onready var health_label: Label = $BottomBar/HBox/HealthContainer/HealthLabel
@onready var resource_bar: ProgressBar = $BottomBar/HBox/ResourceContainer/ResourceBar
@onready var resource_label: Label = $BottomBar/HBox/ResourceContainer/ResourceLabel
@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var level_label: Label = $TopBar/LevelLabel

func _ready() -> void:
	Global.player_health_changed.connect(_on_health_changed)
	Global.player_resource_changed.connect(_on_resource_changed)
	Global.player_xp_changed.connect(_on_xp_changed)

func _process(_delta: float) -> void:
	if gold_label:
		gold_label.text = "💰 " + str(Global.player_gold)

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_resource_changed(current: float, max_val: float) -> void:
	if resource_bar:
		resource_bar.max_value = max_val
		resource_bar.value = current
	if resource_label:
		resource_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_xp_changed(_current: int, _needed: int, level: int) -> void:
	if level_label:
		level_label.text = "Lv. %d - %s" % [level, Global.player_class]
