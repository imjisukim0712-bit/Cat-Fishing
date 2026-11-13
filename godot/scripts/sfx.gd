extends Node
## 원본의 WebAudio 합성음(tone/noise)을 같은 파형·엔벨로프로 PCM 렌더링해서 재생.
## AudioStreamWAV 로 미리 굽기 때문에 웹 익스포트(샘플 재생 모드)에서도 그대로 동작한다.

const RATE := 22050
const POOL := 16

var enabled := true
var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _next := 0

func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = -2.0
		add_child(p)
		_players.append(p)

## voices: [{f, dur, type, vol, delay}] 또는 {noise:true, dur, vol, delay}
func play(key: String, voices: Array) -> void:
	if not enabled: return
	var stream: AudioStreamWAV = _cache.get(key)
	if stream == null:
		stream = _render(voices)
		_cache[key] = stream
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.play()

func tone(freq: float, dur := 0.12, type := "sine", vol := 0.16, delay := 0.0) -> void:
	var f := roundf(freq / 10.0) * 10.0   # 캐시 키를 줄이기 위해 10Hz 단위로 정리
	play("t:%d:%.2f:%s:%.2f:%.2f" % [f, dur, type, vol, delay], [{"f": f, "dur": dur, "type": type, "vol": vol, "delay": delay}])

func noise(dur := 0.25, vol := 0.13) -> void:
	play("n:%.2f:%.2f" % [dur, vol], [{"noise": true, "dur": dur, "vol": vol, "delay": 0.0}])

# ---- 원본 SFX 세트 ----
func cast() -> void:
	play("cast", [{"f": 320.0, "dur": .08, "type": "triangle", "vol": .10, "delay": 0.0}, {"noise": true, "dur": .2, "vol": .1, "delay": 0.0}])
func bite() -> void:
	play("bite", [{"f": 880.0, "dur": .09, "type": "square", "vol": .14, "delay": 0.0}, {"f": 1180.0, "dur": .09, "type": "square", "vol": .12, "delay": .09}])
func hit(i: int) -> void:
	tone(520 + i * 130, .10, "triangle", .15)
func miss() -> void:
	tone(180, .16, "sawtooth", .11)
func catch_s() -> void:
	var v := []
	for i in 3: v.append({"f": [523.0, 659.0, 784.0][i], "dur": .16, "type": "triangle", "vol": .15, "delay": i * 0.07})
	play("catch", v)
func escape() -> void:
	var v := []
	for i in 3: v.append({"f": [400.0, 330.0, 247.0][i], "dur": .18, "type": "sine", "vol": .12, "delay": i * 0.09})
	play("escape", v)
func coin() -> void:
	play("coin", [{"f": 1046.0, "dur": .07, "type": "square", "vol": .11, "delay": 0.0}, {"f": 1568.0, "dur": .09, "type": "square", "vol": .10, "delay": .06}])
func meow() -> void:
	play("meow", [{"f": 660.0, "dur": .18, "type": "sine", "vol": .13, "delay": 0.0}, {"f": 520.0, "dur": .22, "type": "sine", "vol": .12, "delay": .14}])
func fanfare() -> void:
	var m := [523.0, 659.0, 784.0, 1046.0, 1318.0, 1046.0, 1318.0, 1568.0]
	var v := []
	for i in m.size():
		v.append({"f": m[i], "dur": .30, "type": "triangle", "vol": .17, "delay": i * 0.11})
		v.append({"f": m[i] / 2.0, "dur": .30, "type": "sine", "vol": .09, "delay": i * 0.11})
	v.append({"noise": true, "dur": .3, "vol": .15, "delay": 0.0})   # 원본: noise(.3,.06) × 6
	play("fanfare", v)

# ---- 렌더러 ----
func _osc(type: String, phase: float) -> float:
	var x := phase - floorf(phase)
	match type:
		"square":   return 1.0 if x < 0.5 else -1.0
		"triangle": return 4.0 * absf(x - 0.5) - 1.0
		"sawtooth": return 2.0 * x - 1.0
	return sin(TAU * x)

func _render(voices: Array) -> AudioStreamWAV:
	var total := 0.0
	for v in voices: total = maxf(total, v.delay + v.dur + 0.03)
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for v in voices:
		var start := int(v.delay * RATE)
		var ln := int(v.dur * RATE)
		if v.get("noise", false):
			# 랜덤 노이즈 × 선형 감쇠 → 1400Hz 1차 로우패스
			var a := 1.0 - exp(-TAU * 1400.0 / RATE)
			var y := 0.0
			for i in ln:
				if start + i >= n: break
				var s := randf_range(-1.0, 1.0) * (1.0 - float(i) / ln)
				y += a * (s - y)
				buf[start + i] += y * v.vol
		else:
			var attack := 0.012
			for i in ln + int(0.02 * RATE):
				if start + i >= n: break
				var t := float(i) / RATE
				var g: float
				if t < attack: g = v.vol * t / attack
				elif t < v.dur: g = v.vol * pow(0.0001 / v.vol, (t - attack) / maxf(0.001, v.dur - attack))
				else: g = 0.0
				buf[start + i] += _osc(v.type, v.f * t) * g
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
