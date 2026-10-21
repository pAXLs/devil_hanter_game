extends Node

# Procedural SFX Audio Manager & Sound Synthesizer
# Generates responsive ARPG audio in-memory without external dependencies

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 12

var master_volume_offset: float = -6.0
var audio_pool: Array[AudioStreamPlayer] = []
var pool_index: int = 0

# Cached audio streams
var sfx_slash: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_crit: AudioStreamWAV
var sfx_dash: AudioStreamWAV
var sfx_gold: AudioStreamWAV
var sfx_potion: AudioStreamWAV
var sfx_chest: AudioStreamWAV
var sfx_bone_crunch: AudioStreamWAV
var sfx_bow_shot: AudioStreamWAV
var sfx_toxic_burst: AudioStreamWAV
var sfx_hammer: AudioStreamWAV
var sfx_slam: AudioStreamWAV
var sfx_ui_click: AudioStreamWAV
var sfx_equip: AudioStreamWAV
var sfx_portal_spawn: AudioStreamWAV
var sfx_portal_enter: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create polyphonic player pool
	for i in range(POOL_SIZE):
		var asp := AudioStreamPlayer.new()
		asp.bus = "Master"
		add_child(asp)
		audio_pool.append(asp)

	_generate_all_sfx()

func _play_stream(stream: AudioStreamWAV, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not stream:
		return
	var player := audio_pool[pool_index]
	pool_index = (pool_index + 1) % POOL_SIZE

	player.stream = stream
	player.volume_db = volume_db + master_volume_offset
	player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	player.play()

# Public API for gameplay sounds (soft, non-fatiguing ARPG volume mix)
func play_slash() -> void:
	_play_stream(sfx_slash, -5.0, 0.12)

func play_hit() -> void:
	_play_stream(sfx_hit, -3.0, 0.08)

func play_crit() -> void:
	_play_stream(sfx_crit, -1.0, 0.05)

func play_dash() -> void:
	_play_stream(sfx_dash, -5.0, 0.10)

func play_gold() -> void:
	_play_stream(sfx_gold, -4.0, 0.15)

func play_potion() -> void:
	_play_stream(sfx_potion, -2.0, 0.06)

func play_chest() -> void:
	_play_stream(sfx_chest, -1.0, 0.05)

func play_bone_crunch() -> void:
	_play_stream(sfx_bone_crunch, -3.0, 0.10)

func play_bow_shot() -> void:
	_play_stream(sfx_bow_shot, -4.0, 0.08)

func play_toxic_burst() -> void:
	_play_stream(sfx_toxic_burst, -2.0, 0.08)

func play_hammer() -> void:
	_play_stream(sfx_hammer, -3.0, 0.06)

func play_slam() -> void:
	_play_stream(sfx_slam, -1.0, 0.06)

func play_ui_click() -> void:
	_play_stream(sfx_ui_click, -6.0, 0.05)

func play_equip() -> void:
	_play_stream(sfx_equip, -4.0, 0.08)

func play_portal_spawn() -> void:
	_play_stream(sfx_portal_spawn, -1.0, 0.04)

func play_portal_enter() -> void:
	_play_stream(sfx_portal_enter, 0.0, 0.02)

# --- Waveform Synthesizers ---

func _generate_all_sfx() -> void:
	sfx_slash = _synth_slash()
	sfx_hit = _synth_hit()
	sfx_crit = _synth_crit()
	sfx_dash = _synth_dash()
	sfx_gold = _synth_gold()
	sfx_potion = _synth_potion()
	sfx_chest = _synth_chest()
	sfx_bone_crunch = _synth_bone_crunch()
	sfx_bow_shot = _synth_bow_shot()
	sfx_toxic_burst = _synth_toxic_burst()
	sfx_hammer = _synth_hammer()
	sfx_slam = _synth_slam()
	sfx_ui_click = _synth_ui_click()
	sfx_equip = _synth_equip()
	sfx_portal_spawn = _synth_portal_spawn()
	sfx_portal_enter = _synth_portal_enter()

func _create_wav(byte_data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = byte_data
	return wav

# Sword slash: whoosh noise sweep (0.16s)
func _synth_slash() -> AudioStreamWAV:
	var duration := 0.16
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var last_noise := 0.0
	for i in range(count):
		var t := float(i) / count
		var env := sin(t * PI) # Bell curve envelope
		var raw_noise := randf_range(-1.0, 1.0)
		# Lowpass filtered noise sweep from 900Hz to 300Hz
		var cutoff := lerpf(0.45, 0.15, t)
		last_noise = lerpf(last_noise, raw_noise, cutoff)
		var s := clampf(last_noise * env * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Impact hit: solid punch click + mid low body (0.14s)
func _synth_hit() -> AudioStreamWAV:
	var duration := 0.14
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 28.0) # Sharp decay
		var freq := lerpf(220.0, 65.0, minf(1.0, t * 15.0))
		var tone := sin(TAU * freq * t)
		var noise := randf_range(-0.4, 0.4) * exp(-t * 50.0)
		var s := clampf((tone * 0.75 + noise) * env, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Critical Hit: metallic heavy strike with high ping (0.24s)
func _synth_crit() -> AudioStreamWAV:
	var duration := 0.24
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 14.0)
		var chime := (sin(TAU * 1250.0 * t) * 0.5 + sin(TAU * 1880.0 * t) * 0.35) * exp(-t * 20.0)
		var bass := sin(TAU * 95.0 * t) * 0.6 * exp(-t * 10.0)
		var noise := randf_range(-0.5, 0.5) * exp(-t * 40.0)
		var s := clampf((chime + bass + noise) * env, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Dash roll: quick wind gust (0.20s)
func _synth_dash() -> AudioStreamWAV:
	var duration := 0.20
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var last_val := 0.0
	for i in range(count):
		var t := float(i) / count
		var env := sin(t * PI)
		var n := randf_range(-1.0, 1.0)
		var cutoff := lerpf(0.12, 0.35, sin(t * PI))
		last_val = lerpf(last_val, n, cutoff)
		var s := clampf(last_val * env * 0.85, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Gold coin pickup: clear dual bell chime (0.22s)
func _synth_gold() -> AudioStreamWAV:
	var duration := 0.22
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		# Two bright musical tones (E6 1318Hz + B6 1975Hz)
		var bell1 := sin(TAU * 1318.0 * t) * 0.6 * exp(-t * 18.0)
		var bell2 := sin(TAU * 1975.0 * t) * 0.4 * exp(-t * 22.0)
		var s := clampf((bell1 + bell2), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Potion drinking: soothing liquid chime (0.28s)
func _synth_potion() -> AudioStreamWAV:
	var duration := 0.28
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var mod := sin(TAU * 8.0 * t) * 40.0
		var tone := sin(TAU * (520.0 + mod) * t) * 0.55 * exp(-t * 8.0)
		var high := sin(TAU * 880.0 * t) * 0.35 * exp(-t * 12.0)
		var s := clampf((tone + high), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Chest open: deep wooden creak and pop (0.35s)
func _synth_chest() -> AudioStreamWAV:
	var duration := 0.35
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var creak := sin(TAU * (140.0 + sin(t * 40.0) * 30.0) * t) * 0.6 * exp(-t * 6.0)
		var pop := sin(TAU * 380.0 * t) * 0.5 * exp(-t * 30.0)
		var s := clampf(creak + pop, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Bone crunch / Skeleton death: crunchy shattering noise (0.25s)
func _synth_bone_crunch() -> AudioStreamWAV:
	var duration := 0.25
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 12.0)
		var snap := randf_range(-0.7, 0.7) * exp(-t * 35.0)
		var thud := sin(TAU * 85.0 * t) * 0.5 * exp(-t * 10.0)
		var s := clampf((snap + thud) * env, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Bow shot: string twang & release (0.18s)
func _synth_bow_shot() -> AudioStreamWAV:
	var duration := 0.18
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var twang := sin(TAU * 420.0 * exp(-t * 20.0) * t) * 0.7 * exp(-t * 16.0)
		var whoosh := randf_range(-0.3, 0.3) * sin(float(i) / count * PI)
		var s := clampf(twang + whoosh, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Toxic burst / Poison cloud: boiling sizzle explosion (0.35s)
func _synth_toxic_burst() -> AudioStreamWAV:
	var duration := 0.35
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var last := 0.0
	for i in range(count):
		var t := float(i) / count
		var env := sin(t * PI)
		var n := randf_range(-1.0, 1.0)
		var sizzle := sin(TAU * 350.0 * float(i) / SAMPLE_RATE) * 0.3
		last = lerpf(last, n, 0.25)
		var s := clampf((last * 0.7 + sizzle) * env, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Holy hammer: radiant resonant bell (0.32s)
func _synth_hammer() -> AudioStreamWAV:
	var duration := 0.32
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var hum := sin(TAU * 440.0 * t) * 0.5 * exp(-t * 7.0)
		var holy := sin(TAU * 880.0 * t) * 0.35 * exp(-t * 9.0)
		var deep := sin(TAU * 110.0 * t) * 0.4 * exp(-t * 8.0)
		var s := clampf(hum + holy + deep, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Thunder slam / Earthquake: heavy bass rumble (0.40s)
func _synth_slam() -> AudioStreamWAV:
	var duration := 0.40
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var sub := sin(TAU * (75.0 - t * 40.0) * t) * 0.8 * exp(-t * 5.0)
		var noise := randf_range(-0.4, 0.4) * exp(-t * 12.0)
		var s := clampf(sub + noise, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# UI click: subtle parchment tap (0.05s)
func _synth_ui_click() -> AudioStreamWAV:
	var duration := 0.05
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var click := sin(TAU * 800.0 * t) * exp(-t * 60.0)
		var s := clampf(click * 0.6, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Equip item: metallic armor rustle (0.12s)
func _synth_equip() -> AudioStreamWAV:
	var duration := 0.12
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var snap := sin(TAU * 650.0 * t) * 0.5 * exp(-t * 25.0)
		var clang := sin(TAU * 1200.0 * t) * 0.3 * exp(-t * 30.0)
		var s := clampf(snap + clang, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Portal spawn: mystical resonant chime + choir swell (0.45s)
func _synth_portal_spawn() -> AudioStreamWAV:
	var duration := 0.45
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var choir1 := sin(TAU * 261.63 * t) * 0.35 # C4
		var choir2 := sin(TAU * 392.00 * t) * 0.30 # G4
		var choir3 := sin(TAU * 523.25 * t) * 0.25 # C5
		var chime := sin(TAU * (1046.5 + t * 400.0) * t) * 0.25 * exp(-t * 6.0)
		var envelope := (1.0 - exp(-t * 15.0)) * exp(-t * 4.5)
		var s := clampf((choir1 + choir2 + choir3 + chime) * envelope, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)

# Portal enter: deep vortex warp & descending-to-ascending frequency whoosh (0.55s)
func _synth_portal_enter() -> AudioStreamWAV:
	var duration := 0.55
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var freq := 80.0 + sin(t * 12.0) * 40.0 + (t * 220.0)
		var sub := sin(TAU * freq * t) * 0.7 * (1.0 - exp(-t * 20.0)) * exp(-t * 3.5)
		var rush := randf_range(-0.25, 0.25) * sin(PI * (t / duration))
		var chime := sin(TAU * 880.0 * t) * 0.2 * exp(-t * 8.0)
		var s := clampf(sub + rush + chime, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))

	return _create_wav(bytes)
