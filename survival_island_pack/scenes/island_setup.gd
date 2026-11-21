extends Node3D

@export var water_level: float = 0.0
@export var beacon_rotation_speed: float = 0.55

@onready var lighthouse_beacon: Node3D = get_node_or_null("LighthouseRuins/BeaconPivot")
@onready var campfire_light: OmniLight3D = get_node_or_null("BeachAndCamp/CampfireLight")

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	if lighthouse_beacon:
		lighthouse_beacon.rotate_y(beacon_rotation_speed * delta)
	if campfire_light:
		campfire_light.light_energy = 2.6 + 0.35 * sin(_time * 7.5) + 0.2 * cos(_time * 13.0)

func _on_ocean_swim_zone_body_entered(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(true, water_level)

func _on_ocean_swim_zone_body_exited(body: Node3D) -> void:
	if body.has_method("set_swimming"):
		body.set_swimming(false, water_level)
