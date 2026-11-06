class_name Sfx
extends RefCounted
## Fire-and-forget sound effects. Sfx.play(&"hit") plays res://assets/sfx/hit.wav
## with a little random pitch, and skips repeats of the same sound within 35 ms.

const DIR := "res://assets/sfx/"
const VOLUME_DB := -6.0
const RANDOM_PITCH := 0.07
const MIN_GAP_MS := 35
const POOL_SIZE := 12

static var _cache := {}
static var _last := {}
static var _pool: Array[AudioStreamPlayer] = []
static var _next := 0


static func play(sound: StringName, volume_db := VOLUME_DB) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound, -1000)) < MIN_GAP_MS:
		return
	_last[sound] = now
	var stream: AudioStream = _cache.get(sound)
	if stream == null:
		var path := DIR + String(sound) + ".wav"
		if not ResourceLoader.exists(path):
			return
		stream = load(path)
		_cache[sound] = stream
	var p := _player()
	if p == null:
		return
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-RANDOM_PITCH, RANDOM_PITCH)
	p.play()


static func _player() -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			tree.root.add_child.call_deferred(p)
			_pool.append(p)
	_next = (_next + 1) % _pool.size()
	var player := _pool[_next]
	return player if player.is_inside_tree() else null
