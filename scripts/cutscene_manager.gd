extends CanvasLayer
class_name CutsceneManager

signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)

var is_playing: bool = false
var _current_id: String = ""
var _cut_cam: Camera3D = null
var _prev_cam: Camera3D = null
var _top_bar: ColorRect = null
var _bot_bar: ColorRect = null
var _fade_rect: ColorRect = null
var _sub_panel: PanelContainer = null
var _speaker_lbl: Label = null
var _text_lbl: Label = null
var _skip_btn: Button = null
var _skip_requested: bool = false
var _sfx: SFXManager = null

func _ready() -> void:
	layer = 30
	_build_ui()
	_sfx = SFXManager.new()
	add_child(_sfx)

func _build_ui() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	_top_bar = ColorRect.new()
	_top_bar.anchor_left = 0; _top_bar.anchor_right = 1; _top_bar.anchor_top = 0; _top_bar.anchor_bottom = 0
	_top_bar.offset_bottom = 0
	_top_bar.color = Color(0.02, 0.03, 0.05, 0.98)
	add_child(_top_bar)

	_bot_bar = ColorRect.new()
	_bot_bar.anchor_left = 0; _bot_bar.anchor_right = 1; _bot_bar.anchor_top = 1; _bot_bar.anchor_bottom = 1
	_bot_bar.offset_top = 0
	_bot_bar.color = Color(0.02, 0.03, 0.05, 0.98)
	add_child(_bot_bar)

	_sub_panel = PanelContainer.new()
	_sub_panel.anchor_left = 0.12; _sub_panel.anchor_right = 0.88
	_sub_panel.anchor_top = 0.77; _sub_panel.anchor_bottom = 0.94
	_sub_panel.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.06, 0.10, 0.86)
	st.border_color = Color(0.88, 0.72, 0.34, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(14)
	_sub_panel.add_theme_stylebox_override("panel", st)
	add_child(_sub_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_sub_panel.add_child(vb)

	_speaker_lbl = Label.new()
	_speaker_lbl.add_theme_font_size_override("font_size", 15)
	_speaker_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	vb.add_child(_speaker_lbl)

	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_size_override("font_size", 17)
	_text_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	vb.add_child(_text_lbl)

	_skip_btn = Button.new()
	_skip_btn.text = "SKIP ▶"
	_skip_btn.anchor_left = 0.84; _skip_btn.anchor_right = 0.97
	_skip_btn.anchor_top = 0.04; _skip_btn.anchor_bottom = 0.12
	_skip_btn.visible = false
	_skip_btn.add_theme_font_size_override("font_size", 15)
	_skip_btn.pressed.connect(func(): _skip_requested = true)
	add_child(_skip_btn)

func play_sequence(cutscene_id: String, shots: Array[Dictionary]) -> void:
	if is_playing:
		return
	is_playing = true
	_skip_requested = false
	_current_id = cutscene_id
	cutscene_started.emit(cutscene_id)

	var vp := get_viewport()
	_prev_cam = vp.get_camera_3d()
	_cut_cam = Camera3D.new()
	_cut_cam.fov = 62.0
	get_parent().add_child(_cut_cam)
	_cut_cam.current = true

	# Show letterbox & skip button
	_skip_btn.visible = true
	_sub_panel.visible = true
	var bar_tw := create_tween().set_parallel(true)
	bar_tw.tween_property(_top_bar, "offset_bottom", 62.0, 0.45)
	bar_tw.tween_property(_bot_bar, "offset_top", -62.0, 0.45)

	for shot in shots:
		if _skip_requested:
			break
		var from_pos: Vector3 = shot.get("from_pos", Vector3(0, 8, 20))
		var to_pos: Vector3 = shot.get("to_pos", from_pos)
		var look_at_pt: Vector3 = shot.get("look_at", Vector3.ZERO)
		var dur: float = shot.get("duration", 3.5)
		var speaker: String = shot.get("speaker", "CASTAWAY")
		var line: String = shot.get("text", "")
		var sfx_name: String = shot.get("sfx", "")

		_cut_cam.global_position = from_pos
		_cut_cam.look_at(look_at_pt, Vector3.UP)
		_speaker_lbl.text = speaker
		_text_lbl.text = line
		_text_lbl.visible_ratio = 0.0

		if sfx_name != "" and _sfx:
			_sfx.play(sfx_name, -2.0, 0.96, 1.04)

		var tw := create_tween().set_parallel(true)
		tw.tween_property(_cut_cam, "global_position", to_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_text_lbl, "visible_ratio", 1.0, minf(dur * 0.55, 1.8))

		var elapsed := 0.0
		while elapsed < dur and not _skip_requested:
			if is_instance_valid(_cut_cam):
				_cut_cam.look_at(look_at_pt, Vector3.UP)
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		if tw.is_valid():
			tw.kill()

	# Restore camera & hide letterbox
	_skip_btn.visible = false
	_sub_panel.visible = false
	var end_tw := create_tween().set_parallel(true)
	end_tw.tween_property(_top_bar, "offset_bottom", 0.0, 0.35)
	end_tw.tween_property(_bot_bar, "offset_top", 0.0, 0.35)
	await end_tw.finished

	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	if is_instance_valid(_cut_cam):
		_cut_cam.queue_free()

	is_playing = false
	cutscene_finished.emit(cutscene_id)
