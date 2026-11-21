extends CharacterBody3D

@export var patrol_center: Vector3 = Vector3(16.0, 4.2, -10.0)
@export var patrol_radius: float = 14.0
@export var patrol_speed: float = 2.1
@export var chase_speed: float = 4.6
@export var detect_range: float = 16.0
@export var campfire_safe_pos: Vector3 = Vector3(-25.5, 1.2, 34.0)
@export var safe_zone_radius: float = 11.0

var gravity: float = 14.0
var _patrol_target: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer = null
var _player: CharacterBody3D = null
var _sfx: SFXManager = null
var _hb_timer: float = 0.0
var _roar_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _was_chasing: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
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
	if not _player:
		_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if not is_on_floor():
		velocity.y -= gravity * delta

	_roar_cooldown = maxf(0.0, _roar_cooldown - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	# Pause AI during cutscenes
	var story := get_parent().get_node_or_null("StoryManager")
	if story and story.get("is_in_cutscene"):
		velocity.x = 0; velocity.z = 0
		move_and_slide()
		return

	var chasing := false
	if _player:
		var dist_p := global_position.distance_to(_player.global_position)
		var player_near_fire := _player.global_position.distance_to(campfire_safe_pos) < safe_zone_radius
		if dist_p < detect_range and not player_near_fire:
			chasing = true
			# Proximity heartbeat SFX!
			_hb_timer -= delta
			if _hb_timer <= 0.0 and _sfx:
				var vol := lerpf(-16.0, -2.0, clampf(1.0 - dist_p / detect_range, 0.0, 1.0))
				_sfx.play("heartbeat", vol, 0.96, 1.04)
				_hb_timer = lerpf(0.95, 0.42, clampf(1.0 - dist_p / detect_range, 0.0, 1.0))

			if not _was_chasing and _roar_cooldown <= 0.0 and _sfx:
				_sfx.play("keeper_roar", -3.0, 0.92, 1.06)
				_roar_cooldown = 8.0

			if dist_p < 2.2 and _attack_cooldown <= 0.0:
				_attack_cooldown = 2.0
				if _anim and _anim.has_animation("Attack"):
					_anim.play("Attack", 0.1)
				if _sfx:
					_sfx.play("keeper_roar", -1.0, 0.85, 0.95)
				var push := (_player.global_position - global_position).normalized()
				_player.velocity = push * 7.5 + Vector3(0, 3.5, 0)
				if _player.has_method("_show_floating_text"):
					_player._show_floating_text("👁️ The Hollow Keeper struck you! Run to the Campfire!", Color(1.0, 0.3, 0.25), 2.5)
				if OS.has_feature("mobile"):
					Input.vibrate_handheld(120)

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
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 7.0 * delta)
	else:
		velocity.x = 0.0; velocity.z = 0.0

	move_and_slide()
	if _anim and _attack_cooldown < 1.3:
		var want := "Chase_Run" if chasing else "Patrol_Walk"
		if _anim.current_animation != want and _anim.has_animation(want):
			_anim.play(want, 0.2)
