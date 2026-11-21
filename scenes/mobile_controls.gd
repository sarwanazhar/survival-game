extends CanvasLayer

signal joystick_moved(dir: Vector2)
signal camera_dragged(relative: Vector2)
signal attack_pressed()
signal attack_released()
signal jump_pressed()
signal jump_released()
signal sprint_changed(is_sprinting: bool)
signal craft_pressed()
signal plant_pressed()

@export var style_sprint_normal: StyleBox = null
@export var style_sprint_active: StyleBox = null

var camera_touch_id: int = -1
var camera_sensitivity: float = 0.005

const VirtualJoystickScript = preload("res://scenes/virtual_joystick.gd")

@onready var joystick: Control = $Control/JoystickContainer/VirtualJoystick
@onready var btn_attack: Button = $Control/ButtonsContainer/AttackButton
@onready var btn_jump: Button = $Control/ButtonsContainer/JumpButton
@onready var btn_sprint: Button = $Control/ButtonsContainer/SprintButton
@onready var btn_craft: Button = $Control/ButtonsContainer/CraftButton
@onready var btn_plant: Button = $Control/ButtonsContainer/PlantButton
@onready var touch_camera_area: Control = $Control/TouchCameraArea

var is_sprint_locked: bool = false
var attack_is_active: bool = false
var jump_is_active: bool = false

var last_craft_time: int = 0
var last_plant_time: int = 0
var last_sprint_time: int = 0

func _ready() -> void:
	if joystick:
		joystick.joystick_moved.connect(func(dir: Vector2):
			joystick_moved.emit(dir)
		)
	
	# Attack button: instant attack on press down, continuous if held
	if btn_attack:
		btn_attack.button_down.connect(func(): _set_attack(true))
		btn_attack.button_up.connect(func(): _set_attack(false))
		btn_attack.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch:
				_set_attack(event.pressed)
				btn_attack.accept_event()
		)
	
	# Jump button: instant jump on press down
	if btn_jump:
		btn_jump.button_down.connect(func(): _set_jump(true))
		btn_jump.button_up.connect(func(): _set_jump(false))
		btn_jump.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch:
				_set_jump(event.pressed)
				btn_jump.accept_event()
		)
	
	# Sprint button: instant toggle on press
	if btn_sprint:
		btn_sprint.pressed.connect(_on_sprint_toggle)
		btn_sprint.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.pressed:
				_on_sprint_toggle()
				btn_sprint.accept_event()
		)
	
	# Craft button: instant open/close crafting modal on press
	if btn_craft:
		btn_craft.pressed.connect(_on_craft_click)
		btn_craft.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.pressed:
				_on_craft_click()
				btn_craft.accept_event()
		)
	
	# Plant button: instant plant on press
	if btn_plant:
		btn_plant.pressed.connect(_on_plant_click)
		btn_plant.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.pressed:
				_on_plant_click()
				btn_plant.accept_event()
		)
	
	if touch_camera_area:
		touch_camera_area.gui_input.connect(_on_camera_area_input)

func set_plant_button_visible(p_visible: bool) -> void:
	if btn_plant:
		btn_plant.visible = p_visible

func _set_attack(active: bool) -> void:
	if attack_is_active == active:
		return
	attack_is_active = active
	if active:
		attack_pressed.emit()
	else:
		attack_released.emit()

func _set_jump(active: bool) -> void:
	if jump_is_active == active:
		return
	jump_is_active = active
	if active:
		jump_pressed.emit()
	else:
		jump_released.emit()

func _on_sprint_toggle() -> void:
	var now := Time.get_ticks_msec()
	if now - last_sprint_time < 280:
		return
	last_sprint_time = now
	is_sprint_locked = !is_sprint_locked
	_update_sprint_state()

func _update_sprint_state() -> void:
	sprint_changed.emit(is_sprint_locked)
	if btn_sprint:
		if is_sprint_locked:
			btn_sprint.text = "SPRINT"
			if style_sprint_active:
				btn_sprint.add_theme_stylebox_override("normal", style_sprint_active)
				btn_sprint.add_theme_stylebox_override("hover", style_sprint_active)
				btn_sprint.add_theme_stylebox_override("pressed", style_sprint_active)
		else:
			btn_sprint.text = "RUN"
			if style_sprint_normal:
				btn_sprint.add_theme_stylebox_override("normal", style_sprint_normal)
				btn_sprint.add_theme_stylebox_override("hover", style_sprint_normal)
				btn_sprint.add_theme_stylebox_override("pressed", style_sprint_normal)

func _on_craft_click() -> void:
	var now := Time.get_ticks_msec()
	if now - last_craft_time < 300:
		return
	last_craft_time = now
	craft_pressed.emit()

func _on_plant_click() -> void:
	var now := Time.get_ticks_msec()
	if now - last_plant_time < 300:
		return
	last_plant_time = now
	plant_pressed.emit()

func _on_camera_area_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and camera_touch_id == -1:
			camera_touch_id = event.index
			touch_camera_area.accept_event()
		elif not event.pressed and event.index == camera_touch_id:
			camera_touch_id = -1
			touch_camera_area.accept_event()
	
	elif event is InputEventScreenDrag and event.index == camera_touch_id:
		camera_dragged.emit(event.relative * camera_sensitivity)
		touch_camera_area.accept_event()
	
	elif event is InputEventMouseButton:
		touch_camera_area.accept_event()
