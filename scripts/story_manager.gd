extends Node
class_name StoryManager

var is_in_cutscene: bool = false
var shrines_found: int = 0
var lighthouse_awakened: bool = false
var escaped: bool = false

var _cutscene: CutsceneManager = null
var _sfx: SFXManager = null
var _hud: CanvasLayer = null
var _interact_hud: CanvasLayer = null
var _lore_hud: CanvasLayer = null
var _obj_panel: PanelContainer = null
var _obj_label: Label = null
var _interact_btn: Button = null
var _lore_panel: PanelContainer = null
var _lore_title: Label = null
var _lore_body: Label = null
var _active_interact_target: Dictionary = {}

const SHRINE_LOGS: Array[Dictionary] = [
	{
		"node": "Shrine_Bridge",
		"title": "RELIC I — THE MIST",
		"body": "We wrecked against the reef three nights ago. The fog never lifts from Hollow Isle, and the Lighthouse on the northeastern cliffs died the moment we washed ashore."
	},
	{
		"node": "Shrine_Jungle",
		"title": "RELIC II — THE HOLLOW KEEPER",
		"body": "Something tall stalks the cliffs and deep jungle. It fears the warmth of the Campfire. Climb the dirt trail to the Lighthouse, but stay out of its crimson gaze."
	},
	{
		"node": "Shrine_Lighthouse",
		"title": "RELIC III — THE ESCAPE",
		"body": "The beacon is lit once more! Return to your Beach Camp, craft the Rowboat Escape Paddle (4 Wood + 2 Planks), and head to the Rowboat on the southwest shore to escape."
	}
]
var _collected_shrines: Dictionary = {}

func _ready() -> void:
	_cutscene = CutsceneManager.new()
	_cutscene.name = "CutsceneManager"
	add_child(_cutscene)
	_cutscene.cutscene_started.connect(func(_id): is_in_cutscene = true; _set_hud_visible(false))
	_cutscene.cutscene_finished.connect(func(_id): is_in_cutscene = false; _set_hud_visible(true))

	_sfx = SFXManager.new()
	add_child(_sfx)
	_build_story_hud()
	_update_objective()

	# Play Intro Cutscene shortly after scene loads
	await get_tree().create_timer(0.35).timeout
	play_intro_cutscene()

func _build_story_hud() -> void:
	# 1. Background Objective Tracker HUD (Layer 3 - strictly behind all other UI and controls)
	_hud = CanvasLayer.new()
	_hud.name = "StoryObjectiveHUD"
	_hud.layer = 3
	add_child(_hud)

	# Compact Top-Right Objective Tracker (Mobile-friendly, non-blocking)
	_obj_panel = PanelContainer.new()
	_obj_panel.name = "ObjectivePanel"
	_obj_panel.anchor_left = 0.66; _obj_panel.anchor_right = 0.985
	_obj_panel.anchor_top = 0.02; _obj_panel.anchor_bottom = 0.14
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_panel.z_index = -1
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.09, 0.14, 0.85)
	st.border_color = Color(0.92, 0.76, 0.34, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	_obj_panel.add_theme_stylebox_override("panel", st)
	_hud.add_child(_obj_panel)

	_obj_label = Label.new()
	_obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_label.add_theme_font_size_override("font_size", 13)
	_obj_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	_obj_panel.add_child(_obj_label)

	# 2. Floating Interact Button (Layer 8 - above camera touch area, below modals)
	_interact_hud = CanvasLayer.new()
	_interact_hud.name = "StoryInteractHUD"
	_interact_hud.layer = 8
	add_child(_interact_hud)

	_interact_btn = Button.new()
	_interact_btn.text = "✨ INSPECT RELIC [F]"
	_interact_btn.anchor_left = 0.36; _interact_btn.anchor_right = 0.64
	_interact_btn.anchor_top = 0.68; _interact_btn.anchor_bottom = 0.76
	_interact_btn.visible = false
	_interact_btn.add_theme_font_size_override("font_size", 16)
	_interact_btn.pressed.connect(_on_interact_pressed)
	_interact_hud.add_child(_interact_btn)

	# 3. Lore Note Popup Dialog (Layer 22 - high popup layer so it displays on top of everything)
	_lore_hud = CanvasLayer.new()
	_lore_hud.name = "StoryLoreHUD"
	_lore_hud.layer = 22
	add_child(_lore_hud)

	_lore_panel = PanelContainer.new()
	_lore_panel.anchor_left = 0.18; _lore_panel.anchor_right = 0.82
	_lore_panel.anchor_top = 0.22; _lore_panel.anchor_bottom = 0.74
	_lore_panel.visible = false
	var lst := StyleBoxFlat.new()
	lst.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	lst.border_color = Color(1.0, 0.80, 0.32, 0.95)
	lst.set_border_width_all(3)
	lst.set_corner_radius_all(12)
	lst.set_content_margin_all(18)
	_lore_panel.add_theme_stylebox_override("panel", lst)
	_lore_hud.add_child(_lore_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_lore_panel.add_child(vb)

	_lore_title = Label.new()
	_lore_title.add_theme_font_size_override("font_size", 18)
	_lore_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	vb.add_child(_lore_title)

	_lore_body = Label.new()
	_lore_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_body.add_theme_font_size_override("font_size", 16)
	_lore_body.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
	vb.add_child(_lore_body)

	var ok_btn := Button.new()
	ok_btn.text = "CLOSE"
	ok_btn.custom_minimum_size = Vector2(120, 42)
	ok_btn.pressed.connect(func(): _lore_panel.visible = false)
	vb.add_child(ok_btn)

func _set_hud_visible(vis: bool) -> void:
	if _hud:
		_hud.visible = vis
	if _interact_hud:
		_interact_hud.visible = vis

func set_objective_visible(vis: bool) -> void:
	if _hud:
		_hud.visible = vis

func _unhandled_input(event: InputEvent) -> void:
	if is_in_cutscene:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if _interact_btn and _interact_btn.visible:
			_on_interact_pressed()

func _process(_delta: float) -> void:
	if is_in_cutscene or escaped:
		return
	var player := get_parent().get_node_or_null("Player") as CharacterBody3D
	if not player:
		return

	_active_interact_target = {}
	# Check proximity to uncollected Shrines
	for log_data in SHRINE_LOGS:
		var nname: String = log_data["node"]
		if _collected_shrines.get(nname, false):
			continue
		var shrine := get_parent().get_node_or_null("StoryShrines/" + nname) as Node3D
		if shrine and player.global_position.distance_to(shrine.global_position) < 4.0:
			_active_interact_target = {"type": "shrine", "data": log_data}
			_interact_btn.text = "✨ INSPECT %s [F]" % log_data["title"]
			_interact_btn.visible = true
			return

	# Check proximity to Rowboat for Escape Ending!
	var boat := get_parent().get_node_or_null("BeachAndCamp/CastawayRowboat") as Node3D
	if boat and player.global_position.distance_to(boat.global_position) < 6.0:
		var has_paddle: bool = player.inventory.get("paddle", 0) > 0
		_active_interact_target = {"type": "boat", "has_paddle": has_paddle}
		_interact_btn.text = "🚣 ESCAPE ISLAND [F]" if has_paddle else "🚣 ROWBOAT (Craft Paddle First)"
		_interact_btn.visible = true
		return

	_interact_btn.visible = false

func _on_interact_pressed() -> void:
	if _active_interact_target.is_empty():
		return
	if _active_interact_target["type"] == "shrine":
		var d: Dictionary = _active_interact_target["data"]
		_collected_shrines[d["node"]] = true
		shrines_found += 1
		if _sfx: _sfx.play("shrine_chime", -2.0)
		_lore_title.text = d["title"]
		_lore_body.text = d["body"]
		_lore_panel.visible = true
		_update_objective()
		if d["node"] == "Shrine_Lighthouse" and not lighthouse_awakened:
			lighthouse_awakened = true
			_lore_panel.visible = false
			play_lighthouse_cutscene()
	elif _active_interact_target["type"] == "boat":
		if _active_interact_target.get("has_paddle", false):
			escaped = true
			_interact_btn.visible = false
			play_escape_cutscene()
		else:
			if _sfx: _sfx.play("error_buzz", -4.0)

func _update_objective() -> void:
	if not _obj_label:
		return
	if escaped:
		_obj_label.text = "STORY COMPLETE\nYou escaped Hollow Isle!"
	elif shrines_found < 3:
		_obj_label.text = "OBJECTIVE (%d/3 Relics)\nFind glowing Shrines (Bridge, Jungle, Lighthouse) & gather Wood/Stone." % shrines_found
	else:
		_obj_label.text = "FINAL OBJECTIVE\nCraft Escape Paddle & reach the Rowboat on SW Beach!"

func play_intro_cutscene() -> void:
	var shots: Array[Dictionary] = [
		{
			"from_pos": Vector3(-56, 5.5, 56), "to_pos": Vector3(-36, 4.0, 42),
			"look_at": Vector3(-44, 0.5, 43), "duration": 3.2,
			"speaker": "THE BEACON OF HOLLOW ISLE",
			"text": "The storm shattered your vessel... leaving you stranded on a mist-choked island.",
			"sfx": "cutscene_horn"
		},
		{
			"from_pos": Vector3(-16, 4.5, 39), "to_pos": Vector3(-20, 3.2, 34),
			"look_at": Vector3(-25, 1.8, 31), "duration": 3.2,
			"speaker": "CASTAWAY",
			"text": "An abandoned camp... My tools are here, and glowing relics pulse in the jungle."
		},
		{
			"from_pos": Vector3(10, 10.0, 2), "to_pos": Vector3(18, 14.0, -8),
			"look_at": Vector3(30, 14.0, -22), "duration": 3.4,
			"speaker": "CASTAWAY",
			"text": "That Lighthouse on the cliffs... something is moving up there. Find the 3 Relics and craft a Paddle to escape!",
			"sfx": "keeper_roar"
		}
	]
	_cutscene.play_sequence("intro", shots)

func play_lighthouse_cutscene() -> void:
	var shots: Array[Dictionary] = [
		{
			"from_pos": Vector3(14, 9.5, -10), "to_pos": Vector3(16, 22.0, -8),
			"look_at": Vector3(30, 19.0, -22), "duration": 4.0,
			"speaker": "LIGHTHOUSE AWAKENED",
			"text": "The ancient beacon flares against the curse! Now craft the Escape Paddle and run for the Rowboat!",
			"sfx": "shrine_chime"
		}
	]
	_cutscene.play_sequence("lighthouse", shots)

func play_escape_cutscene() -> void:
	var boat := get_parent().get_node_or_null("BeachAndCamp/CastawayRowboat") as Node3D
	if boat:
		var tw := create_tween()
		tw.tween_property(boat, "position", Vector3(-86, -0.06, 74), 5.5).set_trans(Tween.TRANS_SINE)
	var shots: Array[Dictionary] = [
		{
			"from_pos": Vector3(-34, 4.0, 48), "to_pos": Vector3(-62, 7.0, 62),
			"look_at": Vector3(-56, 1.0, 54), "duration": 4.5,
			"speaker": "ESCAPED HOLLOW ISLE",
			"text": "With the paddle crafted, you push out beyond the reef as the Hollow Keeper watches from the cliffs...",
			"sfx": "cutscene_horn"
		}
	]
	_cutscene.play_sequence("escape", shots)
	_update_objective()
