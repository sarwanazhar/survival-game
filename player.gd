extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var run_speed: float = 7.5
@export var swim_speed: float = 3.6
@export var jump_velocity: float = 5.5
@export var rotation_speed: float = 12.0
@export var mouse_sensitivity: float = 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)

var is_swimming: bool = false
var water_surface_y: float = 0.0
var _was_in_water: bool = false
var _step_timer: float = 0.0
var _swim_sfx_timer: float = 0.0
var _peak_fall_speed: float = 0.0
var sfx: SFXManager = null

var is_mobile: bool = false
var mobile_controls: CanvasLayer = null
var touch_move_dir: Vector2 = Vector2.ZERO
var touch_jump_pressed: bool = false
var touch_sprint_active: bool = false
var touch_attack_held: bool = false

func set_swimming(active: bool, surface_y: float = 0.0) -> void:
	is_swimming = active
	water_surface_y = surface_y

@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
var anim_player: AnimationPlayer = null

# Clean Tools definitions (All 8 tools with Kenney preview icons)
const TOOLS: Array[Dictionary] = [
	{
		"slot": 1,
		"name": "Fists",
		"mesh": "",
		"anim": "Attack",
		"icon_path": ""
	},
	{
		"slot": 2,
		"name": "Axe",
		"mesh": "Tool_Axe",
		"anim": "Tool_Axe_Chop",
		"icon_path": "res://assets/kenney_survival-kit/Previews/tool-axe.png"
	},
	{
		"slot": 3,
		"name": "Pickaxe",
		"mesh": "Tool_Pickaxe",
		"anim": "Tool_Pickaxe_Mine",
		"icon_path": "res://assets/kenney_survival-kit/Previews/tool-pickaxe.png"
	},
	{
		"slot": 4,
		"name": "Shovel",
		"mesh": "Tool_Shovel",
		"anim": "Tool_Shovel_Dig",
		"icon_path": "res://assets/kenney_survival-kit/Previews/tool-shovel.png"
	},
	{
		"slot": 5,
		"name": "Hammer",
		"mesh": "Tool_Hammer",
		"anim": "Tool_Hammer_Strike",
		"icon_path": "res://assets/kenney_survival-kit/Previews/tool-hammer.png"
	},
	{
		"slot": 6,
		"name": "Hoe",
		"mesh": "Tool_Hoe",
		"anim": "Tool_Hoe_Till",
		"icon_path": "res://assets/kenney_survival-kit/Previews/tool-hoe.png"
	},
	{
		"slot": 7,
		"name": "Bucket",
		"mesh": "Item_Bucket",
		"anim": "Item_Bucket_Carry",
		"icon_path": "res://assets/kenney_survival-kit/Previews/bucket.png"
	},
	{
		"slot": 8,
		"name": "Bottle",
		"mesh": "Item_Bottle",
		"anim": "Item_Bottle_Drink",
		"icon_path": "res://assets/kenney_survival-kit/Previews/bottle.png"
	}
]

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

# Survival Inventory
var inventory: Dictionary = {
	"wood": 0,
	"stone": 0,
	"sapling": 0,
	"planks": 0,
	"torch": 0,
	"campfire": 0,
	"paddle": 0,
	"shelter": 0
}

# Crafting Recipes
const RECIPES: Array[Dictionary] = [
	{
		"id": "planks",
		"name": "Wooden Planks (x4)",
		"icon": "res://assets/kenney_survival-kit/Previews/resource-planks.png",
		"cost": {"wood": 1},
		"yield": {"planks": 4},
		"desc": "Processed wood planks for crafting and shelter"
	},
	{
		"id": "torch",
		"name": "Camp Torch",
		"icon": "res://assets/kenney_survival-kit/Previews/campfire-stand.png",
		"cost": {"wood": 1, "stone": 1},
		"yield": {"torch": 1},
		"desc": "Survival light source"
	},
	{
		"id": "campfire",
		"name": "Campfire Pit",
		"icon": "res://assets/kenney_survival-kit/Previews/campfire-pit.png",
		"cost": {"wood": 3, "stone": 2},
		"yield": {"campfire": 1},
		"desc": "Cooking & warmth fire pit"
	},
	{
		"id": "paddle",
		"name": "Rowboat Escape Paddle",
		"icon": "res://assets/kenney_survival-kit/Previews/tool-shovel.png",
		"cost": {"wood": 4, "planks": 2},
		"yield": {"paddle": 1},
		"desc": "Repairs beach rowboat to escape island!"
	},
	{
		"id": "shelter",
		"name": "Survival Shelter",
		"icon": "res://assets/kenney_survival-kit/Previews/tent.png",
		"cost": {"wood": 6, "planks": 4, "stone": 2},
		"yield": {"shelter": 1},
		"desc": "Island camp shelter"
	}
]

var current_tool_idx: int = 0
var tool_meshes: Dictionary = {}

var is_attacking: bool = false
var was_on_floor: bool = true
var is_landing: bool = false
var land_timer: float = 0.0

# UI References
var ui_hud_layer: CanvasLayer = null
var ui_active_label: Label = null
var ui_slot_panels: Array[PanelContainer] = []
var ui_wood_label: Label = null
var ui_stone_label: Label = null
var ui_sapling_label: Label = null
var ui_planks_label: Label = null

var ui_crafting_modal: PanelContainer = null
var ui_crafting_recipe_box: VBoxContainer = null
var ui_notification_label: Label = null
var ui_notification_tween: Tween = null

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
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.35
	sfx = SFXManager.new()
	sfx.name = "SFXManager"
	add_child(sfx)
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	
	anim_player = find_child("AnimationPlayer", true, false)
	if anim_player:
		for anim_name in ["Idle", "Walk", "Run", "Fall", "Item_Bucket_Carry", "Swim_Idle", "Swim_Forward"]:
			if anim_player.has_animation(anim_name):
				anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play("Idle")
	
	_cache_tool_meshes()
	_create_survival_ui()
	_update_active_tool()
	_update_resource_hud()
	_setup_mobile_controls()
	
	if camera_pivot and visuals:
		var cam_basis: Basis = camera_pivot.global_transform.basis if is_inside_tree() else camera_pivot.transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.001:
			var local_fwd := global_transform.basis.inverse() * forward.normalized() if is_inside_tree() else forward.normalized()
			visuals.rotation.y = atan2(local_fwd.x, local_fwd.z)

func _setup_mobile_controls() -> void:
	var scene = load("res://scenes/mobile_controls.tscn")
	if scene:
		mobile_controls = scene.instantiate()
		add_child(mobile_controls)
		
		mobile_controls.joystick_moved.connect(func(dir: Vector2):
			touch_move_dir = dir
		)
		mobile_controls.camera_dragged.connect(func(relative: Vector2):
			if camera_pivot:
				camera_pivot.rotate_y(-relative.x * 2.5)
				var spring_arm: SpringArm3D = camera_pivot.get_node_or_null("SpringArm3D")
				if spring_arm:
					spring_arm.rotate_x(-relative.y * 2.5)
					spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60.0), deg_to_rad(45.0))
		)
		mobile_controls.attack_pressed.connect(func():
			touch_attack_held = true
			if not is_attacking:
				start_action()
		)
		mobile_controls.attack_released.connect(func():
			touch_attack_held = false
		)
		mobile_controls.jump_pressed.connect(func():
			touch_jump_pressed = true
			if not is_swimming and is_on_floor() and not is_attacking:
				velocity.y = jump_velocity
				is_landing = false
				play_anim("Jump", 0.1)
				if sfx: sfx.play("jump", -5.0, 0.94, 1.08)
		)
		mobile_controls.jump_released.connect(func():
			touch_jump_pressed = false
		)
		mobile_controls.sprint_changed.connect(func(active: bool):
			touch_sprint_active = active
		)
		mobile_controls.craft_pressed.connect(func():
			if ui_crafting_modal and ui_crafting_modal.visible:
				close_crafting()
			else:
				open_crafting()
		)
		mobile_controls.plant_pressed.connect(func():
			plant_sapling()
		)
		
		# Set initial plant button state
		if mobile_controls.has_method("set_plant_button_visible"):
			mobile_controls.set_plant_button_visible(inventory.get("sapling", 0) > 0)

func _cache_tool_meshes() -> void:
	var all_hand_items := [
		"SwordAndLantern",
		"Tool_Axe", "Tool_Axe_Upgraded",
		"Tool_Pickaxe", "Tool_Pickaxe_Upgraded",
		"Tool_Shovel", "Tool_Shovel_Upgraded",
		"Tool_Hammer", "Tool_Hammer_Upgraded",
		"Tool_Hoe", "Tool_Hoe_Upgraded",
		"Item_Bucket",
		"Item_Bottle", "Item_Bottle_Large"
	]
	for t_name in all_hand_items:
		var node = find_child(t_name, true, false)
		if node is MeshInstance3D:
			tool_meshes[t_name] = node
			node.visible = false

# -------------------------------------------------------------
# Survival UI: Minecraft Hotbar (Bottom) + Resource Tracker (Top) + Crafting
# -------------------------------------------------------------
func _create_survival_ui() -> void:
	ui_hud_layer = CanvasLayer.new()
	ui_hud_layer.name = "SurvivalHUD"
	ui_hud_layer.layer = 10
	add_child(ui_hud_layer)
	
	_create_resource_tracker(ui_hud_layer)
	_create_minecraft_hotbar(ui_hud_layer)
	_create_crafting_modal(ui_hud_layer)
	_create_notification_label(ui_hud_layer)

func _create_resource_tracker(canvas: CanvasLayer) -> void:
	var tracker_panel := PanelContainer.new()
	tracker_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tracker_panel.offset_left = 16.0
	tracker_panel.offset_top = 16.0
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.6, 0.9, 0.85)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tracker_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(tracker_panel)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	tracker_panel.add_child(hbox)
	
	ui_wood_label = _create_resource_item(hbox, "res://assets/kenney_survival-kit/Previews/resource-wood.png", "0", Color(0.95, 0.75, 0.4), "Wood")
	ui_stone_label = _create_resource_item(hbox, "res://assets/kenney_survival-kit/Previews/resource-stone.png", "0", Color(0.7, 0.85, 1.0), "Stone")
	ui_sapling_label = _create_resource_item(hbox, "res://assets/kenney_survival-kit/Previews/tree.png", "0", Color(0.4, 0.95, 0.5), "Saplings")
	ui_planks_label = _create_resource_item(hbox, "res://assets/kenney_survival-kit/Previews/resource-planks.png", "0", Color(1.0, 0.85, 0.55), "Planks")

func _create_resource_item(parent: HBoxContainer, icon_path: String, default_val: String, val_color: Color, tip_text: String = "") -> Label:
	var item_box := HBoxContainer.new()
	item_box.add_theme_constant_override("separation", 6)
	parent.add_child(item_box)
	
	if ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_box.add_child(icon_rect)
	
	var lbl := Label.new()
	lbl.text = default_val
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", val_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	item_box.add_child(lbl)
	return lbl

func _create_minecraft_hotbar(canvas: CanvasLayer) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.offset_left = -275.0
	root.offset_right = 275.0
	root.offset_bottom = -14.0
	root.offset_top = -105.0
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 4)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	
	# Floating tool name banner
	ui_active_label = Label.new()
	ui_active_label.text = "[ 1 ] FISTS"
	ui_active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_active_label.add_theme_font_size_override("font_size", 16)
	ui_active_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	ui_active_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ui_active_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(ui_active_label)
	
	# Minecraft-style 8-slot row
	var hotbar_hbox := HBoxContainer.new()
	hotbar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_hbox.add_theme_constant_override("separation", 5)
	hotbar_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hotbar_hbox)
	
	ui_slot_panels = []
	
	for i in range(TOOLS.size()):
		var t_info = TOOLS[i]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(62, 62)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.28, 0.32, 0.38, 0.8)
		style.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", style)
		
		# Center icon margin
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(margin)
		
		if t_info.icon_path != "" and ResourceLoader.exists(t_info.icon_path):
			var tex_rect := TextureRect.new()
			tex_rect.texture = load(t_info.icon_path)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(46, 46)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(tex_rect)
		else:
			# Fists fallback
			var fist_lbl := Label.new()
			fist_lbl.text = "👊"
			fist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fist_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fist_lbl.add_theme_font_size_override("font_size", 28)
			fist_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(fist_lbl)
		
		# Slot number overlay in top-left
		var num_lbl := Label.new()
		num_lbl.text = str(t_info.slot)
		num_lbl.add_theme_font_size_override("font_size", 12)
		num_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num_lbl)
		
		var tool_idx := i
		slot.gui_input.connect(func(event: InputEvent):
			if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
				if current_tool_idx != tool_idx:
					current_tool_idx = tool_idx
					_update_active_tool()
				slot.accept_event()
		)
		
		hotbar_hbox.add_child(slot)
		ui_slot_panels.append(slot)

func _create_crafting_modal(canvas: CanvasLayer) -> void:
	ui_crafting_modal = PanelContainer.new()
	ui_crafting_modal.anchor_left = 0.12
	ui_crafting_modal.anchor_right = 0.88
	ui_crafting_modal.anchor_top = 0.08
	ui_crafting_modal.anchor_bottom = 0.92
	ui_crafting_modal.offset_left = 0
	ui_crafting_modal.offset_right = 0
	ui_crafting_modal.offset_top = 0
	ui_crafting_modal.offset_bottom = 0
	ui_crafting_modal.visible = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.7, 1.0, 0.95)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	ui_crafting_modal.add_theme_stylebox_override("panel", style)
	canvas.add_child(ui_crafting_modal)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	ui_crafting_modal.add_child(vbox)
	
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "🔨 SURVIVAL WORKBENCH & CRAFTING"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(48, 42)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(close_crafting)
	header.add_child(close_btn)
	vbox.add_child(header)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)
	
	ui_crafting_recipe_box = VBoxContainer.new()
	ui_crafting_recipe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_crafting_recipe_box.add_theme_constant_override("separation", 8)
	ui_crafting_recipe_box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(ui_crafting_recipe_box)

func _create_notification_label(canvas: CanvasLayer) -> void:
	ui_notification_label = Label.new()
	ui_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ui_notification_label.offset_top = 65.0
	ui_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_notification_label.add_theme_font_size_override("font_size", 17)
	ui_notification_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	ui_notification_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ui_notification_label.add_theme_constant_override("shadow_offset_y", 2)
	ui_notification_label.modulate.a = 0.0
	canvas.add_child(ui_notification_label)

func _show_floating_text(msg: String, color: Color = Color(1, 1, 1), duration: float = 2.0) -> void:
	if not ui_notification_label:
		return
	ui_notification_label.text = msg
	ui_notification_label.add_theme_color_override("font_color", color)
	
	if ui_notification_tween and ui_notification_tween.is_valid():
		ui_notification_tween.kill()
	
	ui_notification_label.modulate.a = 1.0
	ui_notification_tween = create_tween()
	ui_notification_tween.tween_interval(duration * 0.6)
	ui_notification_tween.tween_property(ui_notification_label, "modulate:a", 0.0, duration * 0.4)

func open_crafting() -> void:
	if ui_crafting_modal:
		ui_crafting_modal.visible = true
		if sfx: sfx.play("ui_click", -6.0, 0.95, 1.05)
		_refresh_crafting_ui()

func close_crafting() -> void:
	if ui_crafting_modal:
		ui_crafting_modal.visible = false
		if sfx: sfx.play("ui_click", -8.0, 0.85, 0.95)

func _refresh_crafting_ui() -> void:
	if not ui_crafting_recipe_box:
		return
	
	for child in ui_crafting_recipe_box.get_children():
		child.queue_free()
	
	for recipe in RECIPES:
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.12, 0.16, 0.22, 0.85)
		row_style.border_width_left = 1
		row_style.border_width_right = 1
		row_style.border_width_top = 1
		row_style.border_width_bottom = 1
		row_style.border_color = Color(0.28, 0.38, 0.5, 0.7)
		row_style.set_corner_radius_all(8)
		row_style.content_margin_left = 12
		row_style.content_margin_right = 12
		row_style.content_margin_top = 8
		row_style.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", row_style)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(hbox)
		
		# Icon
		if ResourceLoader.exists(recipe.icon):
			var icon_rect := TextureRect.new()
			icon_rect.texture = load(recipe.icon)
			icon_rect.custom_minimum_size = Vector2(40, 40)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
			hbox.add_child(icon_rect)
		
		# Name & cost info
		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_child(info_box)
		
		var name_lbl := Label.new()
		name_lbl.text = recipe.name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		info_box.add_child(name_lbl)
		
		# Cost string & verification
		var cost_strs := []
		var can_craft := true
		for mat in recipe.cost:
			var req_count: int = recipe.cost[mat]
			var cur_count: int = inventory.get(mat, 0)
			if cur_count < req_count:
				can_craft = false
				cost_strs.append("%s: %d/%d (Need %d)" % [mat.capitalize(), cur_count, req_count, req_count - cur_count])
			else:
				cost_strs.append("%s: %d/%d" % [mat.capitalize(), cur_count, req_count])
		
		var cost_lbl := Label.new()
		cost_lbl.text = "Cost: " + ", ".join(cost_strs)
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if can_craft else Color(0.95, 0.45, 0.4))
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		info_box.add_child(cost_lbl)
		
		# Craft Button
		var craft_btn := Button.new()
		craft_btn.text = "CRAFT"
		craft_btn.disabled = not can_craft
		craft_btn.custom_minimum_size = Vector2(95, 42)
		craft_btn.add_theme_font_size_override("font_size", 15)
		craft_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		craft_btn.pressed.connect(func():
			craft_item(recipe)
		)
		hbox.add_child(craft_btn)
		
		ui_crafting_recipe_box.add_child(row)

func craft_item(recipe: Dictionary) -> void:
	for mat in recipe.cost:
		if inventory.get(mat, 0) < recipe.cost[mat]:
			_show_floating_text("❌ Need more %s to craft %s!" % [mat.capitalize(), recipe.name], Color(1, 0.4, 0.4))
			return
	
	# Deduct cost
	for mat in recipe.cost:
		inventory[mat] -= recipe.cost[mat]
	
	# Add yield
	for mat in recipe.yield:
		inventory[mat] = inventory.get(mat, 0) + recipe.yield[mat]
	
	_update_resource_hud()
	_refresh_crafting_ui()
	if sfx: sfx.play("craft_success", -3.0, 0.96, 1.05)
	if is_mobile: Input.vibrate_handheld(45)
	_show_floating_text("✨ Crafted: %s!" % recipe.name, Color(1.0, 0.88, 0.3), 2.5)
	
	if recipe.id == "paddle":
		_show_floating_text("🚣 ESCAPE PADDLE CRAFTED! Rowboat repaired, you can escape!", Color(0.2, 0.9, 1.0), 5.0)

func _update_resource_hud() -> void:
	if ui_wood_label:
		ui_wood_label.text = str(inventory.get("wood", 0))
	if ui_stone_label:
		ui_stone_label.text = str(inventory.get("stone", 0))
	if ui_sapling_label:
		ui_sapling_label.text = str(inventory.get("sapling", 0))
	if ui_planks_label:
		ui_planks_label.text = str(inventory.get("planks", 0))
	
	if mobile_controls and mobile_controls.has_method("set_plant_button_visible"):
		mobile_controls.set_plant_button_visible(inventory.get("sapling", 0) > 0)

func _update_active_tool() -> void:
	# Hide all tool meshes
	for t_mesh in tool_meshes.values():
		t_mesh.visible = false
	
	var cur = TOOLS[current_tool_idx]
	if cur.mesh != "" and tool_meshes.has(cur.mesh):
		tool_meshes[cur.mesh].visible = true
	
	# Update active banner label
	if sfx and is_inside_tree(): sfx.play("ui_click", -9.0, 0.92, 1.12)
	if ui_active_label:
		ui_active_label.text = "[ %d ] %s" % [cur.slot, cur.name.to_upper()]
	
	# Update Minecraft hotbar slot highlights
	for i in range(ui_slot_panels.size()):
		var p: PanelContainer = ui_slot_panels[i]
		var style: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
		if i == current_tool_idx:
			style.bg_color = Color(0.18, 0.28, 0.42, 0.95)
			style.border_color = Color(1.0, 0.88, 0.25, 1.0)
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		else:
			style.bg_color = Color(0.1, 0.12, 0.16, 0.85)
			style.border_color = Color(0.28, 0.32, 0.38, 0.7)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		p.add_theme_stylebox_override("panel", style)

# -------------------------------------------------------------
# Input Handling
# -------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if is_mobile:
		return

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
		elif event.keycode == KEY_P:
			plant_sapling()
		elif event.keycode == KEY_C or event.keycode == KEY_E:
			if ui_crafting_modal and ui_crafting_modal.visible:
				close_crafting()
			else:
				open_crafting()
	
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

# -------------------------------------------------------------
# Physics Process & Movement
# -------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var sm := get_parent().get_node_or_null("StoryManager") if get_parent() else null
	if sm and sm.get("is_in_cutscene"):
		velocity.x = 0.0; velocity.z = 0.0
		play_anim("Idle", 0.2)
		return
	var cur_y: float = global_position.y if is_inside_tree() else position.y
	var in_water: bool = is_swimming and (cur_y <= water_surface_y - 0.6)
	
	if in_water:
		is_landing = false
		var target_vy: float = (water_surface_y - 0.85 - cur_y) * 5.0
		velocity.y = move_toward(velocity.y, target_vy, 14.0 * delta)
		
		if Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed:
			velocity.y = jump_velocity * 0.85
	else:
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
	
	if is_attacking:
		if not anim_player or not anim_player.is_playing() or not (anim_player.current_animation in ACTION_ANIMS):
			is_attacking = false
	
	if not is_mobile and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_attacking:
			start_action()
	elif is_mobile:
		if touch_attack_held and not is_attacking:
			start_action()
	
	var jump_pressed := Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or touch_jump_pressed
	if jump_pressed and not in_water and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity
		is_landing = false
		play_anim("Jump", 0.1)
		if sfx: sfx.play("jump", -5.0, 0.94, 1.08)
	
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_back") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	
	var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT) or touch_sprint_active
	if touch_move_dir.length_squared() > 0.001:
		input_dir = touch_move_dir
	else:
		input_dir = input_dir.normalized()
	
	var speed: float = walk_speed
	if in_water:
		speed = swim_speed
	elif is_running:
		speed = run_speed
	
	var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
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
		
		var local_move_dir := global_transform.basis.inverse() * move_dir
		var target_angle := atan2(local_move_dir.x, local_move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
	else:
		var decel: float = 4.0 if in_water else 8.0
		velocity.x = move_toward(velocity.x, 0.0, speed * decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * decel * delta)
	
	if not is_on_floor() and not in_water and velocity.y < 0.0:
		_peak_fall_speed = maxf(_peak_fall_speed, -velocity.y)
	else:
		if is_on_floor() or in_water:
			_peak_fall_speed = 0.0
	if sfx:
		sfx.update_fall_wind(0.0 if (is_on_floor() or in_water) else maxf(0.0, -velocity.y), delta)

	# Water entry / exit splash SFX
	if in_water and not _was_in_water:
		if sfx: sfx.play("water_splash_in", -3.0, 0.9, 1.1)
		if is_mobile: Input.vibrate_handheld(30)
	elif not in_water and _was_in_water:
		if sfx: sfx.play("water_splash_out", -5.0, 0.92, 1.08)
	_was_in_water = in_water

	move_and_slide()
	_update_locomotion_sfx(delta, is_running, in_water)
	update_animation(is_running)

func update_animation(is_running: bool) -> void:
	if not anim_player or is_attacking:
		return
	
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var cur_y: float = global_position.y if is_inside_tree() else position.y
	var in_water: bool = is_swimming and (cur_y <= water_surface_y - 0.6)
	
	if in_water:
		if horizontal_speed > 0.3:
			play_anim("Swim_Forward", 0.25)
		else:
			play_anim("Swim_Idle", 0.25)
		return
	
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

func trigger_land() -> void:
	if sfx:
		if _peak_fall_speed > 9.0:
			sfx.play("land_heavy", -2.5, 0.9, 1.05)
			if is_mobile: Input.vibrate_handheld(55)
		else:
			sfx.play("land_soft", -5.5, 0.92, 1.1)
	if anim_player and anim_player.has_animation("Land") and not is_attacking:
		is_landing = true
		land_timer = 0.3
		play_anim("Land", 0.1)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name in ACTION_ANIMS:
		is_attacking = false
		var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT) or touch_sprint_active
		update_animation(is_running)
	elif anim_name == "Land":
		is_landing = false
		var is_running := Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT) or touch_sprint_active
		update_animation(is_running)

# -------------------------------------------------------------
# Survival Harvesting: Tree Chopping & Stone Mining
# -------------------------------------------------------------
func start_action() -> void:
	if not anim_player or is_attacking:
		return
	is_attacking = true
	is_landing = false
	var cur_tool_name: String = TOOLS[current_tool_idx].name
	var anim_to_play: String = TOOLS[current_tool_idx].anim
	if anim_player.has_animation(anim_to_play):
		anim_player.play(anim_to_play, 0.1)
	_play_tool_use_sfx(cur_tool_name)
	_perform_harvest_hit()

func _perform_harvest_hit() -> void:
	var cur_tool: Dictionary = TOOLS[current_tool_idx]
	var tool_name: String = cur_tool.name
	
	var target_prop: Node = null
	var is_tree := false
	var is_stone := false
	var closest_dist: float = 3.2
	
	# 1. Check closest choppable tree or mineable stone in 2.8m radius around player
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.8
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 1.0, 0))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results := space_state.intersect_shape(query, 32)
	for res in results:
		var col: CollisionObject3D = res.collider
		var p: Node = col.get_parent()
		if not p:
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist < closest_dist:
			if p.is_in_group("choppable_trees"):
				closest_dist = dist
				target_prop = p
				is_tree = true
				is_stone = false
			elif p.is_in_group("mineable_stones"):
				closest_dist = dist
				target_prop = p
				is_stone = true
				is_tree = false
	
	# 2. Direct proximity check fallback (finds nearest node in group within 2.8m)
	if not target_prop and is_inside_tree():
		for t in get_tree().get_nodes_in_group("choppable_trees"):
			if is_instance_valid(t) and t is Node3D:
				var d: float = global_position.distance_to(t.global_position)
				if d < closest_dist:
					closest_dist = d
					target_prop = t
					is_tree = true
					is_stone = false
		for s in get_tree().get_nodes_in_group("mineable_stones"):
			if is_instance_valid(s) and s is Node3D:
				var d: float = global_position.distance_to(s.global_position)
				if d < closest_dist:
					closest_dist = d
					target_prop = s
					is_stone = true
					is_tree = false
	
	# 3. Camera raycast fallback (aiming at a tree/rock further away up to 4.8m)
	if not target_prop and camera:
		var cam_pos: Vector3 = camera.global_position
		var cam_dir: Vector3 = -camera.global_transform.basis.z
		var ray_q := PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + cam_dir * 4.8)
		var ray_res := space_state.intersect_ray(ray_q)
		if ray_res and ray_res.collider:
			var p: Node = ray_res.collider.get_parent()
			if p and p.is_in_group("choppable_trees"):
				target_prop = p
				is_tree = true
			elif p and p.is_in_group("mineable_stones"):
				target_prop = p
				is_stone = true
	
	if not target_prop:
		return
	
	# Shake effect on hit
	var orig_pos = target_prop.position
	var tw = create_tween()
	tw.tween_property(target_prop, "position", orig_pos + Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08)), 0.04)
	tw.tween_property(target_prop, "position", orig_pos, 0.04)
	
	if is_tree:
		if tool_name != "Axe":
			if sfx: sfx.play("error_buzz", -6.0, 0.95, 1.05)
			_show_floating_text("⚠️ Use Axe to chop trees!", Color(1.0, 0.45, 0.4), 2.0)
			return
		
		var dmg: float = 1.0
		var hp: float = target_prop.get_meta("health", 3.0) - dmg
		target_prop.set_meta("health", hp)
		if sfx: sfx.play("axe_chop_hit", -2.0, 0.88, 1.12)
		if is_mobile: Input.vibrate_handheld(35)
		_spawn_felled_effect(target_prop.global_position + Vector3(0, 1.2, 0), Color(0.45, 0.3, 0.15))
		
		if hp > 0.0:
			_show_floating_text("🪓 Chopping Tree... (%.1f/3)" % max(0, hp), Color(0.95, 0.8, 0.3))
		else:
			# Tree Felled!
			var wood_gain = randi_range(3, 5)
			var sapling_gain = randi_range(1, 2)
			inventory["wood"] += wood_gain
			inventory["sapling"] += sapling_gain
			_update_resource_hud()
			if sfx: sfx.play("tree_fall", -1.5, 0.92, 1.06)
			if is_mobile: Input.vibrate_handheld(75)
			_show_floating_text("🪓 Tree Chopped! +%d Wood, +%d Sapling" % [wood_gain, sapling_gain], Color(0.35, 1.0, 0.45), 2.2)
			_spawn_felled_effect(target_prop.global_position + Vector3(0, 1.8, 0), Color(0.25, 0.75, 0.3), 32)
			
			var fade_tw = create_tween()
			fade_tw.tween_property(target_prop, "scale", Vector3(0.01, 0.01, 0.01), 0.22)
			fade_tw.tween_callback(target_prop.queue_free)
	
	elif is_stone:
		if tool_name != "Pickaxe":
			if sfx: sfx.play("error_buzz", -6.0, 0.95, 1.05)
			_show_floating_text("⚠️ Use Pickaxe to mine stone!", Color(1.0, 0.45, 0.4), 2.0)
			return
		
		var dmg: float = 1.0
		var hp: float = target_prop.get_meta("health", 3.0) - dmg
		target_prop.set_meta("health", hp)
		if sfx: sfx.play("pickaxe_mine_hit", -2.5, 0.90, 1.14)
		if is_mobile: Input.vibrate_handheld(40)
		_spawn_felled_effect(target_prop.global_position + Vector3(0, 0.8, 0), Color(0.65, 0.65, 0.7))
		
		if hp > 0.0:
			_show_floating_text("⛏️ Mining Stone... (%.1f/3)" % max(0, hp), Color(0.8, 0.88, 1.0))
		else:
			# Stone Broken!
			var stone_gain = randi_range(3, 5)
			inventory["stone"] += stone_gain
			_update_resource_hud()
			if sfx: sfx.play("stone_break", -1.5, 0.90, 1.08)
			if is_mobile: Input.vibrate_handheld(75)
			_show_floating_text("🪨 Stone Mined! +%d Stone" % stone_gain, Color(0.65, 0.85, 1.0), 2.2)
			_spawn_felled_effect(target_prop.global_position + Vector3(0, 1.0, 0), Color(0.7, 0.7, 0.75), 32)
			_respawn_stone_after_delay(target_prop, 10.0)

func _respawn_stone_after_delay(stone_node: Node3D, delay: float = 10.0) -> void:
	if not is_instance_valid(stone_node):
		return
	if stone_node.get_meta("is_respawning", false):
		return
	stone_node.set_meta("is_respawning", true)
	
	# Cache original scale once
	if not stone_node.has_meta("orig_scale"):
		stone_node.set_meta("orig_scale", stone_node.scale)
	var orig_scale: Vector3 = stone_node.get_meta("orig_scale")
	
	# Immediately take out of targetable group so it cannot be hit while regenerating
	stone_node.remove_from_group("mineable_stones")
	
	# Disable all collision shapes within this stone
	var col_shapes: Array = []
	for col in stone_node.find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D:
			col.set_deferred("disabled", true)
			col_shapes.append(col)
	
	# Play break shrink tween
	var fade_tw = create_tween()
	fade_tw.tween_property(stone_node, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	await fade_tw.finished
	
	if not is_instance_valid(stone_node):
		return
	stone_node.visible = false
	
	# Wait for stone regeneration at exact same position (default 10s)
	await get_tree().create_timer(delay).timeout
	
	if not is_instance_valid(stone_node):
		return
	
	# Reset health, visibility & respawning flag
	stone_node.set_meta("health", 3.0)
	stone_node.set_meta("is_respawning", false)
	stone_node.visible = true
	stone_node.add_to_group("mineable_stones")
	
	for col in col_shapes:
		if is_instance_valid(col):
			col.set_deferred("disabled", false)
	
	# Elastic pop-in animation at exact same position
	var grow_tw = create_tween()
	grow_tw.tween_property(stone_node, "scale", orig_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_felled_effect(stone_node.global_position + Vector3(0, 0.8, 0), Color(0.7, 0.7, 0.75), 24)
	
	if is_inside_tree() and global_position.distance_to(stone_node.global_position) < 18.0:
		_show_floating_text("🪨 Stone has regenerated!", Color(0.7, 0.85, 1.0), 2.2)

func _spawn_felled_effect(pos: Vector3, color: Color, count: int = 18) -> void:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = count
	particles.lifetime = 0.7
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 70.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 5.0
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	particles.mesh = mesh
	
	get_parent().add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

# -------------------------------------------------------------
# Sapling Planting & 5-Second Tree Growth
# -------------------------------------------------------------
func plant_sapling() -> void:
	if inventory.get("sapling", 0) <= 0:
		_show_floating_text("❌ No saplings! Chop trees to get saplings.", Color(1.0, 0.4, 0.4))
		return
	
	inventory["sapling"] -= 1
	_update_resource_hud()
	
	var fwd := -visuals.global_transform.basis.z.normalized()
	var target_pos := global_position + fwd * 2.2
	
	var space_state := get_world_3d().direct_space_state
	var ray_q := PhysicsRayQueryParameters3D.create(target_pos + Vector3(0, 4, 0), target_pos + Vector3(0, -10, 0))
	var ray_hit := space_state.intersect_ray(ray_q)
	if ray_hit:
		target_pos.y = ray_hit.position.y
	else:
		target_pos.y = global_position.y
	
	if sfx: sfx.play("sapling_plant", -3.0, 0.92, 1.08)
	_show_floating_text("🌱 Sapling planted! Growing in 5 seconds...", Color(0.4, 1.0, 0.5), 2.5)
	
	var tree_scene = load("res://assets/kenney_survival-kit/Models/GLB format/tree.glb")
	if not tree_scene:
		tree_scene = load("res://assets/kenney_nature-kit/Models/GLTF format/tree_detailed.glb")
	var new_tree: Node3D = tree_scene.instantiate()
	new_tree.position = target_pos
	new_tree.scale = Vector3(0.2, 0.2, 0.2)
	get_parent().add_child(new_tree)
	
	var label_3d := Label3D.new()
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.font_size = 28
	label_3d.modulate = Color(1.0, 0.95, 0.3)
	label_3d.outline_size = 6
	label_3d.outline_modulate = Color(0, 0, 0, 0.9)
	label_3d.position = Vector3(0, 1.4, 0)
	label_3d.text = "🌱 Growing (5s)..."
	new_tree.add_child(label_3d)
	
	_spawn_felled_effect(target_pos + Vector3(0, 0.4, 0), Color(0.3, 0.85, 0.35))
	
	# Countdown over 5 seconds
	for sec_left in [4, 3, 2, 1]:
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(label_3d):
			label_3d.text = "🌱 Growing (%ds)..." % sec_left
	
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(new_tree):
		return
	
	if is_instance_valid(label_3d):
		label_3d.text = "🌳 FULLY GROWN!"
		label_3d.modulate = Color(0.3, 1.0, 0.4)
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(label_3d):
				label_3d.queue_free()
		)
	
	var grow_tw := create_tween()
	grow_tw.tween_property(new_tree, "scale", Vector3(3.6, 3.6, 3.6), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_felled_effect(target_pos + Vector3(0, 2.0, 0), Color(0.25, 0.85, 0.35), 36)
	
	new_tree.add_to_group("choppable_trees")
	new_tree.set_meta("health", 3.0)
	new_tree.set_meta("max_health", 3.0)
	
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.4
	cyl.height = 4.2
	col.shape = cyl
	col.position = Vector3(0, 2.1, 0)
	sb.add_child(col)
	new_tree.add_child(sb)
	
	if sfx: sfx.play("tree_grow_pop", -3.0, 0.95, 1.08)
	_show_floating_text("🌳 Tree is now fully grown & ready to harvest!", Color(0.3, 1.0, 0.4), 2.5)

# -------------------------------------------------------------
# Surface-Aware Footsteps, Swim SFX & Tool Swing SFX
# -------------------------------------------------------------
func _get_ground_surface_sfx(is_running: bool) -> String:
	if is_running:
		return "footstep_run"
	var pos := global_position
	if pos.y > 4.6 and pos.x > 8.0 and pos.z < 5.0:
		return "footstep_rock"
	elif pos.y < 1.85:
		return "footstep_sand"
	return "footstep_grass"

func _update_locomotion_sfx(delta: float, is_running: bool, in_water: bool) -> void:
	if not sfx:
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if in_water:
		_swim_sfx_timer -= delta
		if _swim_sfx_timer <= 0.0:
			if h_speed > 0.35:
				sfx.play("swim_stroke", -6.0, 0.90, 1.12)
				_swim_sfx_timer = 0.62
			else:
				sfx.play("swim_tread", -11.0, 0.88, 1.08)
				_swim_sfx_timer = 1.05
		return

	if is_on_floor() and h_speed > 0.65:
		_step_timer -= delta
		if _step_timer <= 0.0:
			var step_sfx := _get_ground_surface_sfx(is_running)
			sfx.play(step_sfx, -7.5 if not is_running else -5.5, 0.88, 1.14)
			_step_timer = 0.29 if is_running else 0.46
	else:
		_step_timer = minf(_step_timer, 0.08)

func _play_tool_use_sfx(tool_name: String) -> void:
	if not sfx:
		return
	match tool_name:
		"Fists":
			sfx.play("fist_whoosh", -5.0, 0.92, 1.15)
		"Axe":
			sfx.play("axe_swing", -5.0, 0.90, 1.10)
		"Pickaxe":
			sfx.play("axe_swing", -5.5, 0.82, 0.96)
		"Shovel":
			sfx.play("shovel_dig", -4.0, 0.92, 1.08)
		"Hammer":
			sfx.play("hammer_strike", -4.0, 0.92, 1.10)
		"Hoe":
			sfx.play("hoe_till", -4.5, 0.92, 1.10)
		"Bottle":
			sfx.play("bottle_drink", -3.0, 0.96, 1.05)
		"Bucket":
			sfx.play("bucket_slosh", -4.5, 0.92, 1.08)
