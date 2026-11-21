extends CanvasLayer

signal joystick_moved(dir: Vector2)
signal camera_dragged(relative: Vector2)
signal attack_pressed()
signal attack_released()
signal jump_pressed()
signal jump_released()
signal upgrade_pressed()

var camera_touch_id: int = -1
var camera_sensitivity: float = 0.005

const VirtualJoystickScript = preload("res://scenes/virtual_joystick.gd")

@onready var joystick: Control = $Control/JoystickContainer/VirtualJoystick
@onready var btn_attack: Button = $Control/ButtonsContainer/AttackButton
@onready var btn_jump: Button = $Control/ButtonsContainer/JumpButton
@onready var btn_upgrade: Button = $Control/ButtonsContainer/UpgradeButton
@onready var touch_camera_area: Control = $Control/TouchCameraArea

func _ready() -> void:
	if joystick:
		joystick.joystick_moved.connect(func(dir: Vector2):
			joystick_moved.emit(dir)
		)
	
	if btn_attack:
		btn_attack.button_down.connect(func(): attack_pressed.emit())
		btn_attack.button_up.connect(func(): attack_released.emit())
	
	if btn_jump:
		btn_jump.button_down.connect(func(): jump_pressed.emit())
		btn_jump.button_up.connect(func(): jump_released.emit())
	
	if btn_upgrade:
		btn_upgrade.pressed.connect(func(): upgrade_pressed.emit())
	
	if touch_camera_area:
		touch_camera_area.gui_input.connect(_on_camera_area_input)

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
