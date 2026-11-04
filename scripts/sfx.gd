extends Node
## Autoload. Tiny procedural audio: pickup blips (pitch per type), coin jingle, ambient waves. No asset files.
## API: Sfx.pickup(id), Sfx.tick(), Sfx.bloob(step), Sfx.coin(), Sfx.chime(). Wired to GameState.sold / bag_full / milestone_reached.

const Catalog := preload("res://scripts/catalog.gd")
const RATE := 22050
const BLOOB_STEPS := [0, 2, 4, 7, 9, 12]  # semitones (pentatonic); the pitch stops rising at the last one
var _blips: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _bloob: AudioStreamWAV
var _tick: AudioStreamWAV
var _bloop_pool: Array[AudioStreamPlayer] = []
var _bloop_next := 0
var _coin: AudioStreamWAV
var _chime: AudioStreamWAV
var _full: AudioStreamWAV
var _steps: Array[AudioStreamWAV] = []
var _last_step := -1
var _splashes: Array[AudioStreamWAV] = []  # 0-3 shallow, 4-7 deep wading
var _net_splash: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for t in Catalog.ITEMS:  # bigger item = lower blip
		_blips[t] = _tone([[880.0 * pow(2.0, -float(Catalog.ITEMS[t].space) * 0.25), 0.0]], 0.11, 14.0, 1.35)
	for i in 6:
		var bp := AudioStreamPlayer.new()
		add_child(bp)
		_bloop_pool.append(bp)
	_bloob = _tone([[300.0, 0.0]], 0.16, 17.0, 1.6)
	_tick = _tone([[2093.0, 0.0]], 0.05, 45.0, 1.0)
	_coin = _tone([[1318.5, 0.0], [1760.0, 0.07]], 0.5, 7.0, 1.0)
	_chime = _tone([[523.3, 0.0], [659.3, 0.12], [784.0, 0.24], [1046.5, 0.36]], 1.1, 3.5, 1.0)
	_full = _tone([[180.0, 0.0]], 0.14, 16.0, 0.8)
	for i in 6:
		_steps.append(_crunch(i))
	for i in 8:
		_splashes.append(_splash(i, i >= 4))
	_net_splash = _splash(20, true, 0.45)
	var amb := AudioStreamPlayer.new()
	amb.stream = _waves()
	amb.volume_db = -17.0
	add_child(amb)
	amb.play()
	GameState.sold.connect(func(_n): coin())
	GameState.bag_full.connect(func(): _play(_full, -12.0))
	GameState.milestone_reached.connect(func(_id): chime())

func pickup(id: String) -> void:
	_play(_blips.get(id, _blips["cap"]), -11.0, randf_range(0.97, 1.04))

## Tiny coin tick for loose change.
func tick() -> void:
	_play(_tick, -16.0, randf_range(0.97, 1.05))

## Soft "bloob" of an item landing in a bin; `step` = how many came before (pitch rises, capped).
func bloob(step: int) -> void:
	var semis: int = BLOOB_STEPS[mini(step, BLOOB_STEPS.size() - 1)]
	var p := _bloop_pool[_bloop_next]
	_bloop_next = (_bloop_next + 1) % _bloop_pool.size()
	p.stream = _bloob
	p.volume_db = -19.0 + randf_range(-1.0, 1.0)
	p.pitch_scale = pow(2.0, semis / 12.0)
	p.play()

## One soft sand footstep: a random variant, quiet, with pitch/volume jitter. Player calls it from the bob cadence.
func step() -> void:
	var i := randi() % _steps.size()
	if i == _last_step:
		i = (i + 1) % _steps.size()
	_last_step = i
	_play(_steps[i], randf_range(-31.0, -25.0), randf_range(0.82, 1.22))

## One soft wading step: faint splash, duller and longer the deeper the water (depth 0..1 m). Varied every time.
func splash(depth: float) -> void:
	var deep := depth > 0.45
	var i := randi() % 4 + (4 if deep else 0)
	_play(_splashes[i], randf_range(-35.0, -28.0) + 3.0 * depth, randf_range(0.85, 1.2))

## The casting net hitting the water (a bit bigger, still soft).
func net_splash() -> void:
	_play(_net_splash, -17.0, randf_range(0.9, 1.1))

func coin() -> void:
	_play(_coin, -10.0)

func chime() -> void:
	_play(_chime, -9.0)

func _play(s: AudioStream, db: float, pitch: float = 1.0) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

## Sum of decaying sine notes [[freq, start_s], ...]; `bend` multiplies the pitch over the note (blip rises).
func _tone(notes: Array, dur: float, decay: float, bend: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for note in notes:
		var f0: float = note[0]
		var t0: int = int(float(note[1]) * RATE)
		var ph := 0.0
		for i in range(t0, n):
			var t := float(i - t0) / RATE
			ph += TAU * f0 * lerpf(1.0, bend, minf(t * 12.0, 1.0)) / RATE
			var env := exp(-t * decay) * minf(t * 400.0, 1.0)
			buf[i] += (sin(ph) + 0.25 * sin(ph * 2.0)) * env * 0.5
	return _wav(buf, false)

## Sand crunch variant: 2-4 tiny grains of low-passed noise (different brightness/decay per variant).
func _crunch(seed_: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + seed_
	var n := int(0.16 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var c := rng.randf_range(0.12, 0.45)  # lower = duller, softer
	for g in rng.randi_range(2, 4):
		var t0 := 0 if g == 0 else int(rng.randf_range(0.01, 0.08) * RATE)
		var rate := rng.randf_range(35.0, 90.0)
		var amp := 1.0 if g == 0 else rng.randf_range(0.3, 0.7)
		var lp := 0.0
		for i in range(t0, n):
			lp += (rng.randf_range(-1.0, 1.0) - lp) * c
			buf[i] += lp * exp(-float(i - t0) / RATE * rate) * amp * 1.6
	return _wav(buf, false)

## Soft water splash: band-ish noise with a quick attack and a swishy tail (`deep` = duller and longer).
func _splash(seed_: int, deep: bool, secs := 0.0) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + seed_
	var dur := secs if secs > 0.0 else (rng.randf_range(0.34, 0.5) if deep else rng.randf_range(0.2, 0.3))
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var c := rng.randf_range(0.07, 0.14) if deep else rng.randf_range(0.16, 0.3)
	var decay := rng.randf_range(7.0, 10.0) if deep else rng.randf_range(12.0, 18.0)
	var bf := rng.randf_range(30.0, 50.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * c
		lp2 += (lp - lp2) * 0.5
		var burble := 0.6 + 0.4 * sin(t * bf)  # little bubbles in the tail
		buf[i] = (lp - 0.5 * lp2) * exp(-t * decay) * minf(t * 120.0, 1.0) * burble * 2.2
	return _wav(buf, false)

## 8 s seamless loop: low-passed noise with a slow swell (two incommensurate-ish periods that divide 8 s).
func _waves() -> AudioStreamWAV:
	var secs := 8.0
	var n := int(secs * 11025)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	var lp2 := 0.0
	for pass_i in 2:  # second pass starts with a warmed-up filter, so the loop point is seamless
		for i in n:
			var w := rng.randf_range(-1.0, 1.0)
			lp += (w - lp) * 0.06
			lp2 += (lp - lp2) * 0.25
			if pass_i == 1:
				var t := float(i) / n
				var swell := 0.5 + 0.5 * sin(TAU * t * 1.0 - 1.2)
				var swell2 := 0.5 + 0.5 * sin(TAU * t * 3.0 + 0.6)
				buf[i] = lp2 * (0.25 + 0.75 * swell * (0.6 + 0.4 * swell2)) * 2.2
	var s := _wav(buf, true)
	s.mix_rate = 11025
	return s

func _wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = buf.size()
	return w
