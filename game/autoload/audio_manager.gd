extends Node
## SFX/music by name; missing files are ignored silently so the game never depends
## on an asset being present. Counters double as spies so audio is testable headless.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

var peep_count := 0
var sfx_count := 0
var last_sfx := ""
var muffled := false : set = _set_muffled

var _music: AudioStreamPlayer
var _peep_stream: AudioStreamWAV
var _cache: Dictionary = {}

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	_peep_stream = _make_peep_stream()

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	sfx_count += 1
	last_sfx = sfx_name
	var stream := _load(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	_spawn_player(stream, volume_db, pitch)

func play_sfx_at(sfx_name: String, position: Vector3, pitch: float = 1.0) -> void:
	sfx_count += 1
	last_sfx = sfx_name
	var stream := _load(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	_spawn_player_3d(stream, position, pitch)

## A duckling's voice: one placeholder blip, pitched per temperament. Cheapest way to
## make six ducklings sound like six ducklings.
func peep(position: Vector3, pitch: float = 1.0) -> void:
	peep_count += 1
	if _peep_stream != null:
		_spawn_player_3d(_peep_stream, position, pitch, -8.0)

func play_music(music_name: String) -> void:
	var stream := _load(MUSIC_DIR + music_name + ".wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music.stream = stream
	_music.volume_db = -12.0
	_music.play()

func stop_music() -> void:
	_music.stop()

func _set_muffled(v: bool) -> void:
	muffled = v
	# A plain volume drop is enough to sell "head under water" (5.5).
	AudioServer.set_bus_volume_db(0, -9.0 if v else 0.0)

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	_cache[path] = stream
	return stream

func _spawn_player(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _spawn_player_3d(stream: AudioStream, position: Vector3, pitch: float, volume_db: float = 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.max_distance = 30.0
	add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()

func _make_peep_stream() -> AudioStreamWAV:
	# Procedural placeholder: a short chirp sweeping upward, so it reads as "small bird".
	var rate := 22050
	var seconds := 0.12
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var f := 1800.0 + 900.0 * (t / seconds)
		var env := sin(PI * t / seconds)
		var s := int(sin(TAU * f * t) * env * 12000.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
