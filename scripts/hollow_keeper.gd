extends CharacterBody3D

@export var patrol_center: Vector3 = Vector3(14.0, 4.8, -10.0)
@export var patrol_radius: float = 14.0
@export var patrol_speed: float = 2.2
@export var chase_speed: float = 4.9
@export var detect_range: float = 22.0
@export var catch_distance: float = 1.65
@export var campfire_pos: Vector3 = Vector3(-25.5, 1.1, 34.0)
@export var campfire_vaporize_radius: float = 5.2
@export var respawn_delay: float = 60.0

var gravity: float = 14.0
var _spawn_pos: Vector3 = Vector3.ZERO
var _patrol_target: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer = null
var _player: CharacterBody3D = null
var _sfx: SFXManager = null
var _hb_timer: float = 0.0
var _roar_cooldown: float = 0.0
var _was_chasing: bool = false
var _is_vaporized: bool = false
var _game_over_triggered: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_spawn_pos = global_position
	_patrol_target = patrol_center
	_anim = find_child("AnimationPlayer", true, false)
	if _anim:
		for a in ["Idle", "Patrol_Walk", "Chase_Run"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("Patrol_Walk")
	_sfx = SFXManager.new()
	add_child(_sfx)

func _physics_process(delta: float) -> void:
	if _is_vaporized or _game_over_triggered:
		return
	if not _player:
		_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if not is_on_floor():
		velocity.y -= gravity * delta

	_roar_cooldown = maxf(0.0, _roar_cooldown - delta)

	# Pause AI during cutscenes
	var story := get_parent().get_node_or_null("StoryManager")
	if story and story.get("is_in_cutscene"):
		velocity.x = 0; velocity.z = 0
		move_and_slide()
		return

	# Check Campfire Vaporize Trap!
	var cf_node := get_parent().get_node_or_null("BeachAndCamp/CampfirePit") as Node3D
	var fire_p := cf_node.global_position if cf_node else campfire_pos
	if Vector2(global_position.x - fire_p.x, global_position.z - fire_p.z).length() < campfire_vaporize_radius:
		_vaporize_in_campfire()
		return

	var chasing := false
	if _player:
		var dist_p := global_position.distance_to(_player.global_position)
		if dist_p < detect_range:
			chasing = true
			_hb_timer -= delta
			if _hb_timer <= 0.0 and _sfx:
				var vol := lerpf(-16.0, -2.0, clampf(1.0 - dist_p / detect_range, 0.0, 1.0))
				_sfx.play("heartbeat", vol, 0.96, 1.04)
				_hb_timer = lerpf(0.95, 0.40, clampf(1.0 - dist_p / detect_range, 0.0, 1.0))

			if not _was_chasing and _roar_cooldown <= 0.0 and _sfx:
				_sfx.play("keeper_roar", -3.0, 0.92, 1.06)
				_roar_cooldown = 8.0

			# Monster touched player -> YOU LOSE!
			if dist_p <= catch_distance:
				_trigger_player_death()
				return

	_was_chasing = chasing

	var target_pos := _player.global_position if chasing and _player else _patrol_target
	var to_t := target_pos - global_position
	to_t.y = 0.0
	if not chasing and to_t.length() < 2.0:
		var ang := randf_range(0, TAU)
		_patrol_target = patrol_center + Vector3(cos(ang) * patrol_radius, 0.0, sin(ang) * patrol_radius)

	var spd := chase_speed if chasing else patrol_speed
	if to_t.length_squared() > 0.05:
		var dir := to_t.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 7.5 * delta)
	else:
		velocity.x = 0.0; velocity.z = 0.0

	move_and_slide()
	if _anim:
		var want := "Chase_Run" if chasing else "Patrol_Walk"
		if _anim.current_animation != want and _anim.has_animation(want):
			_anim.play(want, 0.18)

func _vaporize_in_campfire() -> void:
	_is_vaporized = true
	velocity = Vector3.ZERO
	if _sfx:
		_sfx.play("keeper_roar", -1.0, 1.25, 1.40)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(100)
	if _player and _player.has_method("_show_floating_text"):
		_player._show_floating_text("🔥 Monster vaporized by Campfire! Returns in 60s...", Color(1.0, 0.65, 0.25), 3.5)

	_spawn_vaporize_burst(global_position + Vector3(0, 1.2, 0))
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col: col.set_deferred("disabled", true)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.45).set_trans(Tween.TRANS_BACK)
	await tw.finished
	visible = false

	# Respawn 1 minute (60s) later at exact original spawn spot!
	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(self) or _game_over_triggered:
		return
	global_position = _spawn_pos
	scale = Vector3.ONE
	visible = true
	if col: col.set_deferred("disabled", false)
	_is_vaporized = false
	_was_chasing = false
	if _sfx:
		_sfx.play("keeper_roar", -5.0, 0.85, 0.95)
	if _player and _player.has_method("_show_floating_text"):
		_player._show_floating_text("👁️ The Hollow Keeper has returned to the cliffs...", Color(1.0, 0.35, 0.3), 3.0)

func _spawn_vaporize_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos; p.emitting = true; p.one_shot = true; p.explosiveness = 0.9
	p.amount = 42; p.lifetime = 1.1; p.direction = Vector3(0, 1, 0); p.spread = 85.0
	p.initial_velocity_min = 2.0; p.initial_velocity_max = 6.0
	var m := BoxMesh.new(); m.size = Vector3(0.22, 0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.12)
	mat.emission_enabled = true; mat.emission = Color(1.0, 0.38, 0.10); mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.mesh = m
	get_parent().add_child(p)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _trigger_player_death() -> void:
	_game_over_triggered = true
	velocity = Vector3.ZERO
	if _anim and _anim.has_animation("Attack"):
		_anim.play("Attack", 0.08)
	if _sfx:
		_sfx.play("keeper_roar", 0.0, 0.80, 0.90)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(220)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Freeze player controls
	var story := get_parent().get_node_or_null("StoryManager")
	if story:
		story.set("is_in_cutscene", true)

	# Show clean YOU LOSE overlay with Restart button
	var layer := CanvasLayer.new()
	layer.layer = 50
	get_parent().add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.14, 0.01, 0.02, 0.84)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	var title := Label.new()
	title.text = "YOU LOSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.18))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "The Hollow Keeper caught you in the mist.
Tip: Lure it into the Campfire to vaporize it!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.95, 0.90, 0.86))
	vb.add_child(sub)

	var btn := Button.new()
	btn.text = "↻ TRY AGAIN"
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	vb.add_child(btn)
