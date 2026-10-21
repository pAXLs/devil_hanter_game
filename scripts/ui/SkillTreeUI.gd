class_name SkillTreeUI
extends Control

@onready var points_label: Label = $Panel/PointsLabel
@onready var close_btn: Button = $Panel/CloseButton

# Paladin buttons
@onready var btn_pal_1: Button = $Panel/HBox/PaladinColumn/Skill1/Button
@onready var btn_pal_2: Button = $Panel/HBox/PaladinColumn/Skill2/Button
@onready var btn_pal_3: Button = $Panel/HBox/PaladinColumn/Skill3/Button

# Berserker buttons
@onready var btn_ber_1: Button = $Panel/HBox/BerserkerColumn/Skill1/Button
@onready var btn_ber_2: Button = $Panel/HBox/BerserkerColumn/Skill2/Button
@onready var btn_ber_3: Button = $Panel/HBox/BerserkerColumn/Skill3/Button

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Process input even when tree is paused

	if close_btn:
		close_btn.pressed.connect(toggle_visibility)

	SkillManager.skill_points_changed.connect(_on_points_changed)
	SkillManager.skill_unlocked.connect(func(_id): _refresh_ui())

	_setup_button_clicks()
	_refresh_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("skill_tree"):
		toggle_visibility()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and visible:
		toggle_visibility()

func toggle_visibility() -> void:
	visible = !visible
	get_tree().paused = visible
	if visible:
		_refresh_ui()

func _on_points_changed(_pts: int) -> void:
	_refresh_ui()

func _setup_button_clicks() -> void:
	btn_pal_1.pressed.connect(func(): SkillManager.unlock_skill("paladin_resilience"))
	btn_pal_2.pressed.connect(func(): SkillManager.unlock_skill("holy_hammer"))
	btn_pal_3.pressed.connect(func(): SkillManager.unlock_skill("retribution_aura"))

	btn_ber_1.pressed.connect(func(): SkillManager.unlock_skill("bloodthirst"))
	btn_ber_2.pressed.connect(func(): SkillManager.unlock_skill("whirlwind"))
	btn_ber_3.pressed.connect(func(): SkillManager.unlock_skill("furious_charge"))

func _refresh_ui() -> void:
	if points_label:
		points_label.text = "Доступно очков: %d" % SkillManager.available_skill_points

	var pts := SkillManager.available_skill_points

	# Paladin Tree
	var p1 := SkillManager.is_skill_unlocked("paladin_resilience")
	var p2 := SkillManager.is_skill_unlocked("holy_hammer")
	var p3 := SkillManager.is_skill_unlocked("retribution_aura")

	_update_skill_btn(btn_pal_1, p1, true, pts)
	_update_skill_btn(btn_pal_2, p2, p1, pts)
	_update_skill_btn(btn_pal_3, p3, p2, pts)

	# Berserker Tree
	var b1 := SkillManager.is_skill_unlocked("bloodthirst")
	var b2 := SkillManager.is_skill_unlocked("whirlwind")
	var b3 := SkillManager.is_skill_unlocked("furious_charge")

	_update_skill_btn(btn_ber_1, b1, true, pts)
	_update_skill_btn(btn_ber_2, b2, b1, pts)
	_update_skill_btn(btn_ber_3, b3, b2, pts)

func _update_skill_btn(btn: Button, is_unlocked: bool, prereq_met: bool, available_pts: int) -> void:
	if is_unlocked:
		btn.disabled = true
		btn.text = "✓ ИЗУЧЕНО"
		btn.modulate = Color(0.4, 0.9, 0.4) # Green
	elif not prereq_met:
		btn.disabled = true
		btn.text = "Заблокировано"
		btn.modulate = Color(0.6, 0.6, 0.6) # Grey
	elif available_pts > 0:
		btn.disabled = false
		btn.text = "Изучить (1 очко)"
		btn.modulate = Color(1.0, 0.85, 0.25) # Gold clickable
	else:
		btn.disabled = true
		btn.text = "Нет очков"
		btn.modulate = Color(0.7, 0.7, 0.7)
