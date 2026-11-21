extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var run_speed: float = 7.5
@export var jump_velocity: float = 5.5
@export var rotation_speed: float = 12.0
@export var mouse_sensitivity: float = 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)

@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
var anim_player: AnimationPlayer = null

# Tool definitions
const TOOLS: Array[Dictionary] = [
	{
		"slot": 1,
		"name": "Fists",
		"mesh": "",
		"mesh_upgraded": "",
		"anim": "Attack",
		"icon": "[1] Fists"
	},
	{
		"slot": 2,
		"name": "Axe",
		"mesh": "Tool_Axe",
		"mesh_upgraded": "Tool_Axe_Upgraded",
		"anim": "Tool_Axe_Chop",
		"icon": "[2] Axe"
	},
	{
		"slot": 3,
		"name": "Pickaxe",
		"mesh": "Tool_Pickaxe",
		"mesh_upgraded": "Tool_Pickaxe_Upgraded",
		"anim": "Tool_Pickaxe_Mine",
		"icon": "[3] Pickaxe"
	},
	{
		"slot": 4,
		"name": "Shovel",
		"mesh": "Tool_Shovel",
		"mesh_upgraded": "Tool_Shovel_Upgraded",
		"anim": "Tool_Shovel_Dig",
		"icon": "[4] Shovel"
	},
	{
		"slot": 5,
		"name": "Hammer",
		"mesh": "Tool_Hammer",
		"mesh_upgraded": "Tool_Hammer_Upgraded",
		"anim": "Tool_Hammer_Strike",
		"icon": "[5] Hammer"
	},
	{
		"slot": 6,
		"name": "Hoe",
		"mesh": "Tool_Hoe",
		"mesh_upgraded": "Tool_Hoe_Upgraded",
		"anim": "Tool_Hoe_Till",
		"icon": "[6] Hoe"
	},
	{
		"slot": 7,
		"name": "Bucket",
		"mesh": "Item_Bucket",
		"mesh_upgraded": "Item_Bucket",
		"anim": "Item_Bucket_Carry",
		"icon": "[7] Bucket"
	},
	{
		"slot": 8,
		"name": "Bottle",
		"mesh": "Item_Bottle",
		"mesh_upgraded": "Item_Bottle_Large",
		"anim": "Item_Bottle_Drink",
		"icon": "[8] Bottle"
	}
]

# Action animation names for complete state tracking
const ACTION_ANIMS: Array[String] = [
	"Attack",
	"Tool_Axe_Chop",
	"Tool_Pickaxe_Mine",
	"Tool_Shovel_Dig",
	"Tool_Hammer_Strike",
	"Tool_Hoe_Till",
	"Item_Bucket_Carry",
	"Item_Bottle_Drink"
]

var current_tool_idx: int = 0
var is_upgraded: bool = false
var tool_meshes: Dictionary = {}

var is_attacking: bool = false
var was_on_floor: bool = true
var is_landing: bool = false
var land_timer: float = 0.0

# UI References
var ui_active_label: Label = null
var ui_slot_panels: Array[PanelContainer] = []
var ui_slot_labels: Array[Label] = []

func _setup_input_actions() -> void:
	var key_mappings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
	}
	for action in key_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in key_mappings[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)
	
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)

func _ready() -> void:
	_setup_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	anim_player = find_child("AnimationPlayer", true, false)
	if anim_player:
		for anim_name in ["Idle", "Walk", "Run"]:
			if anim_player.has_animation(anim_name):
				anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		
		anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play("Idle")
	
	_cache_tool_meshes()
	_create_top_ui()
	_update_active_tool()

func _cache_tool_meshes() -> void:
	var all_tool_names := [
		"Tool_Axe", "Tool_Axe_Upgraded",
		"Tool_Pickaxe", "Tool_Pickaxe_Upgraded",
		"Tool_Shovel", "Tool_Shovel_Upgraded",
		"Tool_Hammer", "Tool_Hammer_Upgraded",
		"Tool_Hoe", "Tool_Hoe_Upgraded",
		"Item_Bucket", "Item_Bottle", "Item_Bottle_Large"
	]
	for t_name in all_tool_names:
		var node = find_child(t_name, true, false)
		if node is MeshInstance3D:
			tool_meshes[t_name] = node
			node.visible = false

func _create_top_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	
	# Root container anchored at top center
	var root_box := VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root_box.offset_top = 12.0
	root_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_box.add_theme_constant_override("separation", 6)
	canvas.add_child(root_box)
	
	# Top active banner
	var top_panel := PanelContainer.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.1, 0.14, 0.88)
	top_style.set_corner_radius_all(8)
	top_style.border_width_left = 2
	top_style.border_width_right = 2
	top_style.border_width_top = 2
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.2, 0.65, 1.0, 0.9)
	top_style.content_margin_left = 20
	top_style.content_margin_right = 20
	top_style.content_margin_top = 6
	top_style.content_margin_bottom = 6
	top_panel.add_theme_stylebox_override("panel", top_style)
	top_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_box.add_child(top_panel)
	
	ui_active_label = Label.new()
	ui_active_label.text = "ACTIVE TOOL: [ 1 ] FISTS"
	ui_active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_active_label.add_theme_font_size_override("font_size", 18)
	ui_active_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	ui_active_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	ui_active_label.add_theme_constant_override("shadow_offset_y", 1)
	top_panel.add_child(ui_active_label)
	
	# Hotbar Row
	var hotbar_hbox := HBoxContainer.new()
	hotbar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_hbox.add_theme_constant_override("separation", 6)
	hotbar_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_box.add_child(hotbar_hbox)
	
	ui_slot_panels = []
	ui_slot_labels = []
	
	for i in range(TOOLS.size()):
		var t_info = TOOLS[i]
		var slot_panel := PanelContainer.new()
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.14, 0.18, 0.75)
		slot_style.set_corner_radius_all(6)
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.35, 0.4, 0.45, 0.6)
		slot_style.content_margin_left = 10
		slot_style.content_margin_right = 10
		slot_style.content_margin_top = 4
		slot_style.content_margin_bottom = 4
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		
		var slot_label := Label.new()
		slot_label.text = t_info.icon
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 13)
		slot_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		slot_panel.add_child(slot_label)
		
		hotbar_hbox.add_child(slot_panel)
		ui_slot_panels.append(slot_panel)
		ui_slot_labels.append(slot_label)
	
	# Hint Row
	var hint_label := Label.new()
	hint_label.text = "Keys 1-8 / Scroll Wheel: Switch Tool  |  Left-Click: Use  |  [U]: Toggle Upgrade  |  [Esc]: Mouse Cursor"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8, 0.85))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	root_box.add_child(hint_label)

func _update_active_tool() -> void:
	# If player was in middle of an action when switching tools, cancel it immediately
	if is_attacking:
		is_attacking = false
		if anim_player:
			var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
			update_animation(is_running)

	# Hide all tool meshes
	for t_mesh in tool_meshes.values():
		t_mesh.visible = false
	
	var cur = TOOLS[current_tool_idx]
	var mesh_to_show: String = cur.mesh_upgraded if (is_upgraded and cur.mesh_upgraded != "") else cur.mesh
	
	if mesh_to_show != "" and tool_meshes.has(mesh_to_show):
		tool_meshes[mesh_to_show].visible = true
	
	# Update UI banner
	if ui_active_label:
		var up_suffix = " (UPGRADED)" if (is_upgraded and cur.mesh_upgraded != "" and cur.mesh_upgraded != cur.mesh) else ""
		ui_active_label.text = "ACTIVE TOOL: [ %d ] %s%s" % [cur.slot, cur.name.to_upper(), up_suffix]
	
	# Update Hotbar slot highlights
	if ui_slot_panels and ui_slot_panels.size() == TOOLS.size():
		for i in range(TOOLS.size()):
			var p = ui_slot_panels[i]
			var l = ui_slot_labels[i]
			var style: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
			if i == current_tool_idx:
				style.bg_color = Color(0.18, 0.38, 0.62, 0.95)
				style.border_color = Color(1.0, 0.85, 0.25, 1.0)
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_top = 2
				style.border_width_bottom = 2
				l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			else:
				style.bg_color = Color(0.1, 0.12, 0.15, 0.75)
				style.border_color = Color(0.28, 0.32, 0.38, 0.5)
				style.border_width_left = 1
				style.border_width_right = 1
				style.border_width_top = 1
				style.border_width_bottom = 1
				l.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
			p.add_theme_stylebox_override("panel", style)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
		if spring_arm:
			spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60.0), deg_to_rad(45.0))
	
	# Toggle mouse capture with Escape
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Number keys 1-8 to switch tools
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			var target_idx = event.keycode - KEY_1
			if target_idx != current_tool_idx:
				current_tool_idx = target_idx
				_update_active_tool()
		elif event.keycode == KEY_U:
			is_upgraded = !is_upgraded
			_update_active_tool()
	
	# Mouse scroll wheel to cycle tools
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_tool_idx = (current_tool_idx - 1 + TOOLS.size()) % TOOLS.size()
			_update_active_tool()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_tool_idx = (current_tool_idx + 1) % TOOLS.size()
			_update_active_tool()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif not is_attacking:
				start_action()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if not was_on_floor and is_on_floor():
		if velocity.y <= 0:
			trigger_land()
	was_on_floor = is_on_floor()
	
	if is_landing:
		land_timer -= delta
		if land_timer <= 0.0:
			is_landing = false
	
	# Watchdog: if is_attacking is true but anim is no longer playing an action, clear lock
	if is_attacking:
		if not anim_player or not anim_player.is_playing() or not (anim_player.current_animation in ACTION_ANIMS):
			is_attacking = false
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_attacking and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		start_action()
	
	var jump_pressed := Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE)
	if jump_pressed and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity
		is_landing = false
		play_anim("Jump", 0.1)
	
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_back") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	input_dir = input_dir.normalized()
	
	var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
	var speed := run_speed if is_running else walk_speed
	
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	
	var move_dir := (forward * -input_dir.y + right * input_dir.x).normalized()
	
	if is_attacking:
		speed *= 0.25
	
	if move_dir.length_squared() > 0.001:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		
		var target_angle := atan2(move_dir.x, move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)
	
	move_and_slide()
	update_animation(is_running)

func update_animation(is_running: bool) -> void:
	if not anim_player or is_attacking:
		return
	
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	
	if not is_on_floor():
		if velocity.y > 0.5:
			play_anim("Jump", 0.15)
		else:
			play_anim("Fall", 0.2)
	elif is_landing:
		play_anim("Land", 0.1)
	else:
		if horizontal_speed > 0.5:
			if is_running:
				play_anim("Run", 0.2)
			else:
				play_anim("Walk", 0.2)
		else:
			play_anim("Idle", 0.25)

func play_anim(anim_name: String, blend: float = 0.2) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name, blend)

func start_action() -> void:
	if not anim_player or is_attacking:
		return
	is_attacking = true
	is_landing = false
	var anim_to_play: String = TOOLS[current_tool_idx].anim
	if anim_player.has_animation(anim_to_play):
		anim_player.play(anim_to_play, 0.1)
	else:
		is_attacking = false

func trigger_land() -> void:
	if anim_player and anim_player.has_animation("Land") and not is_attacking:
		is_landing = true
		land_timer = 0.3
		play_anim("Land", 0.1)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name in ACTION_ANIMS:
		is_attacking = false
		var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
		update_animation(is_running)
	elif anim_name == "Land":
		is_landing = false
		var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)
		update_animation(is_running)
