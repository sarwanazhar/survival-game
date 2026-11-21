extends Node3D

@export var water_level: float = 0.0
@export var beacon_rotation_speed: float = 0.55

@onready var lighthouse_beacon: Node3D = get_node_or_null("LighthouseRuins/BeaconPivot")
@onready var campfire_light: OmniLight3D = get_node_or_null("BeachAndCamp/CampfireLight")

var _time: float = 0.0

func _ready() -> void:
	_setup_prop_collisions()

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
	
	if "tree" in file_name or "palm" in file_name:
		var cyl := CylinderShape3D.new()
		# Optimized trunk cylinder (blocks trunk, leaves canopy free)
		var trunk_r: float = min(aabb.size.x, aabb.size.z) * 0.11
		var trunk_h: float = aabb.size.y
		cyl.radius = max(0.08, trunk_r)
		cyl.height = trunk_h
		col.shape = cyl
		col.position = Vector3(aabb.get_center().x, aabb.position.y + trunk_h * 0.5, aabb.get_center().z)
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
