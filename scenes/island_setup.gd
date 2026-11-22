extends Node3D

@export var water_level: float = 0.0

@onready var campfire_light: OmniLight3D = get_node_or_null("BeachAndCamp/CampfireLight")

var _time: float = 0.0
var _ocean_audio: AudioStreamPlayer = null

func _ready() -> void:
	_spawn_lighthouse_stones()
	_setup_prop_collisions()
	_setup_ambience_and_atmosphere()
	_setup_story_and_enemy()

func _spawn_lighthouse_stones() -> void:
	var ruins := get_node_or_null("LighthouseRuins")
	if not ruins:
		return
	var stone_scenes := [
		load("res://assets/kenney_survival-kit/Models/GLB format/resource-stone.glb"),
		load("res://assets/kenney_survival-kit/Models/GLB format/resource-stone-large.glb"),
		load("res://assets/kenney_survival-kit/Models/GLB format/rock-a.glb"),
		load("res://assets/kenney_survival-kit/Models/GLB format/rock-b.glb"),
		load("res://assets/kenney_survival-kit/Models/GLB format/rock-c.glb")
	]
	# Placed cleanly on the new walkable 5.2m cliff plateau
	var positions := [
		Vector3(20.0, 4.9, -15.0),
		Vector3(23.0, 5.1, -24.0),
		Vector3(26.0, 5.0, -12.0),
		Vector3(34.0, 5.1, -27.0),
		Vector3(37.0, 5.0, -17.0),
		Vector3(38.0, 4.6, -10.0),
		Vector3(27.0, 4.4, -6.0),
		Vector3(33.0, 4.2, -3.0),
		Vector3(21.0, 4.5, -10.0),
		Vector3(36.0, 5.0, -21.0),
	]
	for i in range(positions.size()):
		var scene: PackedScene = stone_scenes[i % stone_scenes.size()]
		if not scene:
			continue
		var stone_inst = scene.instantiate()
		stone_inst.name = "MineableStone_%02d" % i
		stone_inst.position = positions[i]
		stone_inst.scale = Vector3(3.2, 3.2, 3.2)
		stone_inst.rotation.y = randf_range(0, TAU)
		ruins.add_child(stone_inst)

func _process(delta: float) -> void:
	_time += delta
	if campfire_light:
		campfire_light.light_energy = 2.8 + 0.35 * sin(_time * 7.5) + 0.2 * cos(_time * 13.0)

func _setup_prop_collisions() -> void:
	var groups := ["BeachAndCamp", "Jungle", "LighthouseRuins", "StoryShrines"]
	for g_name in groups:
		var group = get_node_or_null(g_name)
		if not group:
			continue
		for child in group.get_children():
			if child is Node3D and not (child is Light3D):
				_create_prop_collision(child)

func _create_prop_collision(prop: Node3D) -> void:
	var name_lower := prop.name.to_lower()
	var file_name := prop.scene_file_path.get_file().to_lower()

	if "beacon" in name_lower or "bush" in file_name or "bush" in name_lower:
		return

	# Trees: solid trunk cylinder (can't walk through trunk, canopy stays clear)
	if "tree" in file_name or "palm" in file_name or "tree" in name_lower or "palm" in name_lower:
		prop.add_to_group("choppable_trees")
		prop.set_meta("health", 3.0)
		prop.set_meta("max_health", 3.0)
		var aabb := _get_node_aabb(prop)
		var sb := StaticBody3D.new()
		sb.name = "StaticBody3D"
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(0.18, minf(aabb.size.x, aabb.size.z) * 0.16)
		cyl.height = maxf(1.2, aabb.size.y)
		col.shape = cyl
		col.position = Vector3(aabb.get_center().x, aabb.position.y + cyl.height * 0.5, aabb.get_center().z)
		sb.add_child(col)
		prop.add_child(sb)
		return

	# Mineable stones / workbenches group tags
	if "rock" in file_name or "stone" in file_name or "rock" in name_lower or "stone" in name_lower:
		prop.add_to_group("mineable_stones")
		prop.set_meta("health", 3.0)
		prop.set_meta("max_health", 3.0)
	elif "workbench" in file_name or "workbench" in name_lower:
		prop.add_to_group("workbenches")

	# PERFECT EXACT MESH TRIMESH COLLISION on Lighthouse (platform, stairs, walls),
	# Rowboat, Docks, Bridges, Tent, Workbench, Barrels, Rocks, Shrines!
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(prop, meshes)
	for m in meshes:
		if m.mesh and not m.has_node("_col"):
			m.create_trimesh_collision()

func _get_node_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	for m in meshes:
		if m.mesh:
			var m_aabb := m.mesh.get_aabb()
			aabb = m_aabb if first else aabb.merge(m_aabb)
			first = false
	return aabb

func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)

func _setup_ambience_and_atmosphere() -> void:
	_ocean_audio = SFXManager.create_looping_2d_player("ambience_ocean", -14.0)
	_ocean_audio.name = "OceanAmbience"
	add_child(_ocean_audio)

	var wind_audio := SFXManager.create_looping_2d_player("ambience_night_wind", -18.0)
	wind_audio.name = "NightWindAmbience"
	add_child(wind_audio)

	var campfire := get_node_or_null("BeachAndCamp/CampfirePit")
	if campfire:
		var fire_sfx := SFXManager.create_looping_3d_player("campfire_crackle", -2.0, 22.0)
		fire_sfx.name = "CampfireCrackleSFX"
		campfire.add_child(fire_sfx)
		_add_fire_embers(campfire)

	_add_fireflies(Vector3(-18.0, 3.4, 4.0), Vector3(24.0, 3.2, 22.0), 28)
	_add_fireflies(Vector3(28.0, 7.0, -18.0), Vector3(14.0, 3.2, 14.0), 16)

func _setup_story_and_enemy() -> void:
	# StoryManager (Intro / Lighthouse / Escape Cutscenes + Objective Tracker + Shrine Lore)
	if not has_node("StoryManager"):
		var sm := StoryManager.new()
		sm.name = "StoryManager"
		add_child(sm)

	# Spawn The Hollow Keeper horror stalker near the Rocky Cliffs / Trail
	if not has_node("HollowKeeperEnemy") and ResourceLoader.exists("res://assets/models/hollow_keeper.glb"):
		var keeper := CharacterBody3D.new()
		keeper.name = "HollowKeeperEnemy"
		keeper.set_script(load("res://scripts/hollow_keeper.gd"))
		keeper.position = Vector3(14.0, 4.8, -10.0)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.45; cap.height = 2.1
		col.shape = cap; col.position = Vector3(0, 1.05, 0)
		keeper.add_child(col)
		var vis: Node3D = load("res://assets/models/hollow_keeper.glb").instantiate()
		keeper.add_child(vis)
		add_child(keeper)

func _add_fire_embers(parent_node: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 0.25, 0)
	p.amount = 16; p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 1, 0); p.spread = 22.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.4; p.initial_velocity_max = 0.9
	var m := BoxMesh.new(); m.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.65, 0.2)
	mat.emission_enabled = true; mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 2.5; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.mesh = m
	parent_node.add_child(p)

func _add_fireflies(center: Vector3, extents: Vector3, count: int) -> void:
	var p := CPUParticles3D.new()
	p.position = center; p.amount = count; p.lifetime = 5.0; p.preprocess = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.gravity = Vector3(0, 0.02, 0); p.direction = Vector3(0, 1, 0); p.spread = 180.0
	p.initial_velocity_min = 0.12; p.initial_velocity_max = 0.35
	var m := BoxMesh.new(); m.size = Vector3(0.11, 0.11, 0.11)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 1.0, 0.45)
	mat.emission_enabled = true; mat.emission = Color(0.78, 1.0, 0.38)
	mat.emission_energy_multiplier = 2.2; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.mesh = m
	add_child(p)

func _on_ocean_swim_zone_body_entered(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(true, water_level)

func _on_ocean_swim_zone_body_exited(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(false, water_level)
