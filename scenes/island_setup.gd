extends Node3D

@export var water_level: float = 0.0
@export var beacon_rotation_speed: float = 0.55

@onready var lighthouse_beacon: Node3D = get_node_or_null("LighthouseRuins/BeaconPivot")
@onready var campfire_light: OmniLight3D = get_node_or_null("BeachAndCamp/CampfireLight")

var _time: float = 0.0
var _ocean_audio: AudioStreamPlayer = null

func _ready() -> void:
	_spawn_lighthouse_stones()
	_setup_prop_collisions()
	_setup_ambience_and_atmosphere()

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
	
	var positions := [
		Vector3(18.0, 6.2, -15.0),
		Vector3(22.0, 6.5, -20.0),
		Vector3(25.0, 7.0, -12.0),
		Vector3(28.0, 7.5, -28.0),
		Vector3(32.0, 7.8, -16.0),
		Vector3(35.0, 7.2, -26.0),
		Vector3(38.0, 6.8, -10.0),
		Vector3(26.0, 6.4, -6.0),
		Vector3(33.0, 6.5, -2.0),
		Vector3(20.0, 6.6, -10.0),
		Vector3(36.0, 7.0, -20.0),
		Vector3(40.0, 5.8, -16.0)
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
	if lighthouse_beacon:
		lighthouse_beacon.rotate_y(beacon_rotation_speed * delta)
	if campfire_light:
		campfire_light.light_energy = 2.6 + 0.35 * sin(_time * 7.5) + 0.2 * cos(_time * 13.0)

func _setup_prop_collisions() -> void:
	var groups := ["BeachAndCamp", "Jungle", "LighthouseRuins"]
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
	
	if "beacon" in name_lower:
		return
	
	if prop.has_node("StaticBody3D"):
		return
	
	# Bushes are soft foliage, allow walking through
	if "bush" in file_name or "bush" in name_lower:
		return
	
	var aabb := _get_node_aabb(prop)
	if aabb.size.length_squared() < 0.001:
		return
	
	var sb := StaticBody3D.new()
	sb.name = "StaticBody3D"
	sb.collision_layer = 1
	sb.collision_mask = 0
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	
	if "tree" in file_name or "palm" in file_name or "tree" in name_lower or "palm" in name_lower:
		prop.add_to_group("choppable_trees")
		prop.set_meta("health", 3)
		prop.set_meta("max_health", 3)
		var cyl := CylinderShape3D.new()
		# Optimized trunk cylinder (blocks trunk, leaves canopy free)
		var trunk_r: float = min(aabb.size.x, aabb.size.z) * 0.12
		var trunk_h: float = aabb.size.y
		cyl.radius = max(0.12, trunk_r)
		cyl.height = trunk_h
		col.shape = cyl
		col.position = Vector3(aabb.get_center().x, aabb.position.y + trunk_h * 0.5, aabb.get_center().z)
	elif "rock" in file_name or "stone" in file_name or "rock" in name_lower or "stone" in name_lower:
		prop.add_to_group("mineable_stones")
		prop.set_meta("health", 3)
		prop.set_meta("max_health", 3)
		var box := BoxShape3D.new()
		box.size = aabb.size * 0.95
		col.shape = box
		col.position = aabb.get_center()
	elif "workbench" in file_name or "workbench" in name_lower:
		prop.add_to_group("workbenches")
		var box := BoxShape3D.new()
		box.size = aabb.size
		col.shape = box
		col.position = aabb.get_center()
	elif "barrel" in file_name:
		var cyl := CylinderShape3D.new()
		cyl.radius = aabb.size.x * 0.5
		cyl.height = aabb.size.y
		col.shape = cyl
		col.position = aabb.get_center()
	elif "campfire" in file_name:
		var cyl := CylinderShape3D.new()
		cyl.radius = aabb.size.x * 0.5
		cyl.height = aabb.size.y
		col.shape = cyl
		col.position = aabb.get_center()
	elif "lighthouse" in file_name or "lighthouse" in name_lower:
		var cyl := CylinderShape3D.new()
		cyl.radius = 2.8
		cyl.height = 18.0
		col.shape = cyl
		col.position = Vector3(0, 9.0, 0)
	elif "rowboat" in file_name:
		var box := BoxShape3D.new()
		box.size = Vector3(aabb.size.x * 0.9, aabb.size.y * 0.65, aabb.size.z * 0.95)
		col.shape = box
		col.position = Vector3(aabb.get_center().x, aabb.position.y + box.size.y * 0.5, aabb.get_center().z)
	else:
		# Box shape for tent, crate, workbench, bedroll, docks, rocks, resources
		var box := BoxShape3D.new()
		box.size = aabb.size
		col.shape = box
		col.position = aabb.get_center()
	
	sb.add_child(col)
	prop.add_child(sb)

func _get_node_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)
	for m in meshes:
		if m.mesh:
			var m_aabb := m.mesh.get_aabb()
			if first:
				aabb = m_aabb
				first = false
			else:
				aabb = aabb.merge(m_aabb)
	return aabb

func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)

func _on_ocean_swim_zone_body_entered(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(true, water_level)

func _on_ocean_swim_zone_body_exited(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(false, water_level)

func _setup_ambience_and_atmosphere() -> void:
	# 1. Dynamic Ocean Waves ambience
	_ocean_audio = SFXManager.create_looping_2d_player("ambience_ocean", -14.0)
	_ocean_audio.name = "OceanAmbience"
	add_child(_ocean_audio)

	# 2. Eerie Zelda-horror island night wind ambience
	var wind_audio := SFXManager.create_looping_2d_player("ambience_night_wind", -18.0)
	wind_audio.name = "NightWindAmbience"
	add_child(wind_audio)

	# 3. 3D Spatial Campfire Crackle + warm ember particles
	var campfire := get_node_or_null("BeachAndCamp/CampfirePit")
	if campfire:
		var fire_sfx := SFXManager.create_looping_3d_player("campfire_crackle", -2.0, 22.0)
		fire_sfx.name = "CampfireCrackleSFX"
		campfire.add_child(fire_sfx)
		_add_fire_embers(campfire)

	# 4. Floating glowing fireflies in the Jungle & near Lighthouse (lightweight for mobile)
	_add_fireflies("Fireflies_Jungle", Vector3(-18.0, 3.6, 4.0), Vector3(24.0, 3.5, 22.0), 28)
	_add_fireflies("Fireflies_Cliffs", Vector3(28.0, 9.2, -18.0), Vector3(14.0, 3.5, 14.0), 16)

func _add_fire_embers(parent_node: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.name = "CampfireEmbers"
	p.position = Vector3(0, 0.25, 0)
	p.amount = 16
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0, 1, 0)
	p.spread = 22.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	var m := BoxMesh.new()
	m.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.65, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	parent_node.add_child(p)

func _add_fireflies(p_name: String, center: Vector3, extents: Vector3, count: int) -> void:
	var p := CPUParticles3D.new()
	p.name = p_name
	p.position = center
	p.amount = count
	p.lifetime = 5.0
	p.preprocess = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.gravity = Vector3(0, 0.02, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.35
	var m := BoxMesh.new()
	m.size = Vector3(0.11, 0.11, 0.11)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.78, 1.0, 0.38)
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	add_child(p)
