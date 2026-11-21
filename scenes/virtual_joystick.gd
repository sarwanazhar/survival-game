class_name VirtualJoystick
extends Control

signal joystick_moved(dir: Vector2)

@export var base_radius: float = 78.0
@export var knob_radius: float = 34.0
@export var max_distance: float = 62.0

var touch_id: int = -1
var is_active: bool = false
var knob_offset: Vector2 = Vector2.ZERO
var output: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(base_radius * 2 + 20, base_radius * 2 + 20)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			var local_pos = event.position - size * 0.5
			if local_pos.length() <= base_radius + 20.0:
				touch_id = event.index
				is_active = true
				_update_knob(local_pos)
				accept_event()
		elif not event.pressed and event.index == touch_id:
			_reset_knob()
			accept_event()
	
	elif event is InputEventScreenDrag and event.index == touch_id:
		var local_pos = event.position - size * 0.5
		_update_knob(local_pos)
		accept_event()
	
	# Fallback for mouse if touch emulation is used
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and touch_id == -1:
				var local_pos = event.position - size * 0.5
				if local_pos.length() <= base_radius + 20.0:
					touch_id = 9999
					is_active = true
					_update_knob(local_pos)
					accept_event()
			elif not event.pressed and touch_id == 9999:
				_reset_knob()
				accept_event()
		accept_event()
	
	elif event is InputEventMouseMotion and touch_id == 9999:
		var local_pos = event.position - size * 0.5
		_update_knob(local_pos)
		accept_event()

func _update_knob(local_pos: Vector2) -> void:
	if local_pos.length() > max_distance:
		knob_offset = local_pos.normalized() * max_distance
	else:
		knob_offset = local_pos
	
	output = knob_offset / max_distance
	joystick_moved.emit(output)
	queue_redraw()

func _reset_knob() -> void:
	touch_id = -1
	is_active = false
	knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	joystick_moved.emit(Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	
	# Outer glow / base
	var base_bg := Color(0.08, 0.12, 0.18, 0.55 if is_active else 0.38)
	var base_border := Color(0.25, 0.7, 1.0, 0.85 if is_active else 0.5)
	
	draw_circle(center, base_radius, base_bg)
	draw_arc(center, base_radius, 0.0, TAU, 48, base_border, 2.5, true)
	
	# Inner directional ticks (North, South, East, West)
	var tick_color := Color(1.0, 1.0, 1.0, 0.25)
	draw_line(center + Vector2(0, -base_radius + 4), center + Vector2(0, -base_radius + 14), tick_color, 2.0)
	draw_line(center + Vector2(0, base_radius - 14), center + Vector2(0, base_radius - 4), tick_color, 2.0)
	draw_line(center + Vector2(-base_radius + 4, 0), center + Vector2(-base_radius + 14, 0), tick_color, 2.0)
	draw_line(center + Vector2(base_radius - 14, 0), center + Vector2(base_radius - 4, 0), tick_color, 2.0)
	
	# Knob
	var knob_center = center + knob_offset
	var knob_bg := Color(0.18, 0.65, 0.95, 0.85 if is_active else 0.65)
	var knob_core := Color(1.0, 1.0, 1.0, 0.9 if is_active else 0.7)
	
	draw_circle(knob_center, knob_radius, knob_bg)
	draw_circle(knob_center, knob_radius * 0.45, knob_core)
	draw_arc(knob_center, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0, true)
