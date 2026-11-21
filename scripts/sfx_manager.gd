extends Node
class_name SFXManager

const SFX_DIR := "res://assets/audio/sfx/"

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _fall_wind_player: AudioStreamPlayer = null

func _ready() -> void:
	# Mobile-friendly pooled 2D SFX players
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

	_fall_wind_player = AudioStreamPlayer.new()
	_fall_wind_player.bus = "Master"
	var wind_stream := _get_stream("fall_wind", true)
	if wind_stream:
		_fall_wind_player.stream = wind_stream
		_fall_wind_player.volume_db = -40.0
	add_child(_fall_wind_player)

func _get_stream(sfx_name: String, loop: bool = false) -> AudioStream:
	var key := sfx_name + ("_loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var path := SFX_DIR + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path)
	if stream is AudioStreamWAV and loop:
		var dup: AudioStreamWAV = stream.duplicate()
		dup.loop_mode = AudioStreamWAV.LOOP_FORWARD
		dup.loop_begin = 0
		dup.loop_end = int(dup.get_length() * dup.mix_rate)
		stream = dup
	_cache[key] = stream
	return stream

func play(sfx_name: String, volume_db: float = -4.0, pitch_min: float = 0.92, pitch_max: float = 1.08) -> void:
	var stream := _get_stream(sfx_name, false)
	if not stream or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.play()

func update_fall_wind(fall_speed: float, delta: float) -> void:
	if not _fall_wind_player or not _fall_wind_player.stream:
		return
	if fall_speed > 6.5:
		if not _fall_wind_player.playing:
			_fall_wind_player.play()
		var target_db: float = clampf(lerpf(-28.0, -6.0, (fall_speed - 6.5) / 14.0), -28.0, -6.0)
		_fall_wind_player.volume_db = lerpf(_fall_wind_player.volume_db, target_db, 6.0 * delta)
	else:
		if _fall_wind_player.playing:
			_fall_wind_player.volume_db = lerpf(_fall_wind_player.volume_db, -45.0, 10.0 * delta)
			if _fall_wind_player.volume_db < -38.0:
				_fall_wind_player.stop()

static func create_looping_3d_player(sfx_name: String, volume_db: float = -4.0, max_distance: float = 24.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var path := SFX_DIR + sfx_name + ".wav"
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStreamWAV:
			var dup: AudioStreamWAV = stream.duplicate()
			dup.loop_mode = AudioStreamWAV.LOOP_FORWARD
			dup.loop_begin = 0
			dup.loop_end = int(dup.get_length() * dup.mix_rate)
			stream = dup
		p.stream = stream
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.autoplay = true
	return p

static func create_looping_2d_player(sfx_name: String, volume_db: float = -12.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := SFX_DIR + sfx_name + ".wav"
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStreamWAV:
			var dup: AudioStreamWAV = stream.duplicate()
			dup.loop_mode = AudioStreamWAV.LOOP_FORWARD
			dup.loop_begin = 0
			dup.loop_end = int(dup.get_length() * dup.mix_rate)
			stream = dup
		p.stream = stream
	p.volume_db = volume_db
	p.autoplay = true
	return p
