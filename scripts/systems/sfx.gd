class_name Sfx
extends RefCounted
## Audio controller. Sfx.play(&"hit") plays the AudioItem named "hit" from
## res://resources/audio/audio_library.tres (volume, random volume, min time between calls,
## random pitch, clip list). Falls back to res://assets/sfx/<name>.wav if no item exists.
## Sfx.music(&"music_street") loops a music item; Sfx.music(&"") stops it.

const LIBRARY := "res://resources/audio/audio_library.tres"
const FALLBACK_DIR := "res://assets/sfx/"
const POOL_SIZE := 14

static var _items := {}
static var _loaded := false
static var _last := {}
static var _pool: Array[AudioStreamPlayer] = []
static var _next := 0
static var _music: AudioStreamPlayer
static var _music_name := &""
static var muted := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(LIBRARY):
		var lib: AudioLibrary = load(LIBRARY)
		for it in lib.items:
			_items[it.item_name] = it


static func play(sound: StringName, volume_db_offset := 0.0) -> void:
	_load()
	if muted:
		return
	var item: AudioItem = _items.get(sound)
	var now := Time.get_ticks_msec() / 1000.0
	var gap := item.min_time_between_calls if item else 0.035
	if now - float(_last.get(sound, -10.0)) < gap:
		return
	_last[sound] = now
	var stream: AudioStream
	var vol := 0.5
	var pitch := 0.07
	if item and not item.clips.is_empty():
		stream = item.clips[Game.fx_rng.randi() % item.clips.size()]
		vol = clampf(item.volume + Game.fx_rng.randf_range(-item.random_volume, item.random_volume), 0.0, 1.0)
		pitch = item.random_pitch
	else:
		var path := FALLBACK_DIR + String(sound) + ".wav"
		if not ResourceLoader.exists(path):
			return
		stream = load(path)
	var p := _player()
	if p == null:
		return
	p.stream = stream
	p.volume_db = linear_to_db(maxf(vol, 0.001)) + volume_db_offset
	p.pitch_scale = 1.0 + Game.fx_rng.randf_range(-pitch, pitch)
	p.play()


static func music(name: StringName) -> void:
	_load()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _music == null or not is_instance_valid(_music):
		_music = AudioStreamPlayer.new()
		_music.bus = &"Music"
		_music.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(_music)
	if name == _music_name and _music.playing:
		return
	_music_name = name
	var item: AudioItem = _items.get(name)
	if item == null or item.clips.is_empty():
		_music.stop.call_deferred()
		return
	var st := item.clips[0]
	if st is AudioStreamWAV and item.loop:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		@warning_ignore("integer_division")
		w.loop_end = w.data.size() / 2
	_music.stream = st
	_music.volume_db = linear_to_db(maxf(item.volume, 0.001))
	_music.play.call_deferred()


static func _player() -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.bus = &"SFX"
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			tree.root.add_child.call_deferred(p)
			_pool.append(p)
	_next = (_next + 1) % _pool.size()
	var player := _pool[_next]
	return player if player.is_inside_tree() else null
