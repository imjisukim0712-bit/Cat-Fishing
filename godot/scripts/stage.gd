extends "res://scripts/stage_draw.gd"
## Hybrid scene: imported paintings beneath live gameplay and a softened cat.
var backdrop: Sprite2D
var backdrop_mat: ShaderMaterial
var pier: Node2D
var cat: Node2D
var lit_cat: ShaderMaterial

## 구름: 하늘을 천천히 지나가며, 달을 가리면 달빛(물 반사·테두리 빛)이 약해진다
const MOON := Vector2(751, 111)
const MOON_R := 49.0
## 배경 그림에서 수평선(가운데) 높이: 이 줄이 무대의 WATER 에 맞춰진다
const BD_HORIZON := 553.0
const SEA_LINE := Color("#fff4d6")
const MOON_DASH := Color("#ffe066")
var waves: Array = []
var clouds: Array = []
var moon_light := 1.0

func _ready() -> void:
	init_brush()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# 배경 그림: 물 부분이 일렁이도록 셰이더를 건 스프라이트 (부모 그리기보다 뒤에 깔림)
	var bd_tex: Texture2D = load("res://assets/art/backdrop.png")
	backdrop = Sprite2D.new()
	backdrop.texture = bd_tex
	backdrop.centered = false
	backdrop.show_behind_parent = true
	backdrop.scale = Vector2(W / bd_tex.get_width(), WATER / BD_HORIZON)
	backdrop_mat = ShaderMaterial.new()
	backdrop_mat.shader = load("res://shaders/backdrop_water.gdshader")
	backdrop.material = backdrop_mat
	# 바다 굴절용 물결 노멀맵: 이음매 없는 노이즈 (런타임 생성, 별도 파일 불필요)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var wave := NoiseTexture2D.new()
	wave.width = 256; wave.height = 256
	wave.seamless = true
	wave.as_normal_map = true
	wave.bump_strength = 6.0
	wave.generate_mipmaps = true
	wave.noise = noise
	backdrop_mat.set_shader_parameter("wave_normal", wave)
	var blob := NoiseTexture2D.new()
	var bn := FastNoiseLite.new()
	bn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bn.frequency = 0.02
	blob.width = 128; blob.height = 128
	blob.seamless = true
	blob.generate_mipmaps = true
	blob.noise = bn
	backdrop_mat.set_shader_parameter("blob_noise", blob)
	backdrop_mat.set_shader_parameter("lantern_x", LANTERN.x / W)
	add_child(backdrop)
	pier = Node2D.new()
	pier.set_script(load("res://scripts/stage_pier.gd"))
	add_child(pier)

	var props := Node2D.new()
	props.set_script(load("res://scripts/stage_props.gd"))
	add_child(props)
	# 까미는 이제 그림 스프라이트라 별도 뷰포트·흐림 처리 없이 화면 해상도 그대로 그린다
	cat = Node2D.new()
	cat.set_script(load("res://scripts/stage_cat.gd"))
	lit_cat = ShaderMaterial.new()
	lit_cat.shader = load("res://shaders/lit_sprite.gdshader")
	# 까만 까미가 밤하늘에 묻히지 않게: 털을 살짝 보랏빛 숯색으로 밝히고, 밝은 라벤더 스티커 테두리
	lit_cat.set_shader_parameter("outline_px", 2.8)
	lit_cat.set_shader_parameter("line_col", Color("#c3b3f2"))
	lit_cat.set_shader_parameter("fur_shift", Vector3(0.10, 0.08, 0.17))
	cat.material = lit_cat
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 4:
		var blobs := []
		var n := rng.randi_range(3, 5)
		for j in n:
			var u := (j - (n - 1) / 2.0)
			blobs.append(Vector3(u * rng.randf_range(15, 20), -rng.randf_range(0, 12) * (1.0 - absf(u) / n * 1.4), rng.randf_range(13, 21) * (1.0 - absf(u) / n * 0.6)))
		clouds.append({"x": rng.randf_range(-100, 1000), "y": rng.randf_range(40, 175),
			"sp": rng.randf_range(4, 9), "a": 1.0, "blobs": blobs})
	# 바다 물결 낙서: 수평선 쪽에서 생겨 보는 쪽으로 밀려오며 오른쪽으로 조금씩 흘러감
	for i in 10:
		waves.append({"d0": float(i) / 10.0 + rng.randf_range(-0.02, 0.02), "x0": rng.randf_range(0, W + 240),
			"len": rng.randf_range(0.85, 1.15), "ph": rng.randf() * TAU})
	add_child(cat)
	# 랜턴 불빛·반딧불이: 빛을 '더하는' 레이어라 부두와 까미를 실제로 비춘다
	var light := Node2D.new()
	light.set_script(load("res://scripts/stage_light.gd"))
	add_child(light)
	var effects := Node2D.new()
	effects.set_script(load("res://scripts/stage_effects.gd"))
	add_child(effects)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_base = Vector2.ZERO
	if Game.shake > 0:
		_base = Vector2((randf() - .5) * Game.shake, (randf() - .5) * Game.shake)
	xf()
	# One texture draw: align source horizon y=548 to WATER. The extra six
	# pixels extend below the clipped stage, so no bottom patch/seam is needed.
	backdrop.position = _base
	var wk: String = Game.weather.key
	backdrop_mat.set_shader_parameter("strength", 1.7 if wk == "storm" else (1.35 if wk == "hightide" else 1.0))
	backdrop_mat.set_shader_parameter("lantern", lantern_flicker(Game.clock))
	update_lights()
	cat.position = _base
	draw_clouds(Game.clock)
	draw_water(Game.clock)

func draw_water(tm: float) -> void:
	# 너울 줄무늬·반짝이는 backdrop_water 셰이더, 물결 낙서와 달빛 점선은 여기서 그린다
	draw_moon_path(tm)
	draw_waves(tm)
	# 물속 물고기 그림자 (대기 중)
	if Game.mode == "wait" and Game.fish:
		var prog := minf(1.0, Game.t / maxf(.1, Game.bite_at))
		var sx := Game.fx + (1 - prog) * (180.0 if Game.fx > W / 2 else -180.0) * cos(Game.t * 1.6)
		var sy := Game.surf + 44 - prog * 30
		var r: String = Game.fish.r
		var col: Color
		match r:
			"trans": col = Color(1, 1, 1, .95)
			"myth": col = rgba(255, 45, 58, .95)
			"legend": col = rgba(255, 190, 90, .9)
			"epic": col = rgba(180, 120, 255, .85)
			_: col = Color(0, 0, 0, 1)
		col.a *= .40 + prog * 0.40
		var sc := 0.6 + Data.RORDER.find(r) * 0.22
		fill_ell(sx, sy, 26 * sc, 10 * sc, col, sin(Game.t * 2) * 0.14)
		draw_colored_polygon(PackedVector2Array([Vector2(sx + 24 * sc, sy), Vector2(sx + 38 * sc, sy - 9 * sc), Vector2(sx + 38 * sc, sy + 9 * sc)]), col)

	# 파문: 크림색 두들 고리
	for w in Game.ripples:
		stroke_ell(w.x, w.y, w.r, w.r * 0.30, Color(SEA_LINE, minf(1.0, w.a * 1.6)), 2.2)

## 하늘을 지나가는 구름 (달 쪽 가장자리는 달빛을 받아 밝게)
func cloud_pos(cl: Dictionary, t: float) -> float:
	return fmod(cl.x + t * cl.sp + 150.0, W + 300.0) - 150.0

func draw_clouds(t: float) -> void:
	# 두들 구름: 진한 보라 테두리 원을 먼저, 그 위에 채움 원을 겹쳐 하나의 윤곽선이 되게
	var wk: String = Game.weather.key
	var dark := wk == "storm" or wk == "rain"
	var fill := c("#4a3f7a") if dark else c("#6b5bb2")
	var hi := c("#5a4f8e") if dark else c("#8574c9")
	var edge := c("#2b1f4c")
	for cl in clouds:
		var cx := cloud_pos(cl, t)
		var bob := sin(t * 0.4 + cl.y) * 2.0
		for b in cl.blobs:
			circle(cx + b.x, cl.y + b.y + bob, b.z + 2.6, edge)
		for b in cl.blobs:
			circle(cx + b.x, cl.y + b.y + bob, b.z, fill)
		for b in cl.blobs:
			circle(cx + b.x - b.z * 0.25, cl.y + b.y + bob - b.z * 0.3, b.z * 0.42, hi)

## 달빛 길: 노란 점선이 줄마다 다른 박자로 늘었다 줄었다, 좌우로 살랑
func draw_moon_path(t: float) -> void:
	var k := clampf(0.35 + 0.65 * moon_light, 0.0, 1.0)
	var col := Color(MOON_DASH, k)
	for i in 7:
		var y := WATER + 10.0 + i * 11.0
		var base := (46.0 - i * 2.0) * (0.6 + 0.4 * sin(t * 1.9 + i * 1.37))
		var sway := sin(t * 1.15 + i * 0.83) * (3.0 + i * 0.8)
		var pairs := 2 if i % 2 == 1 else 1
		for j in pairs:
			var off := 0.0 if pairs == 1 else (-1.0 if j == 0 else 1.0) * (20.0 + i * 1.2)
			var cx := MOON.x + sway + off
			var half := base * (0.6 if pairs == 2 else 1.0) * 0.5
			if half < 1.0: continue
			line(Vector2(cx - half, y), Vector2(cx + half, y), col, 3.6, true)

## 물결 낙서: 깊이 d(0 수평선 → 1 화면 아래)를 따라 보는 쪽으로 밀려오며 커지고, 출렁이며 오른쪽으로 흐름
func draw_waves(t: float) -> void:
	var sp := 1.6 if Game.weather.key == "storm" else (1.3 if Game.weather.key == "hightide" else 1.0)
	for w in waves:
		var d: float = fmod(w.d0 + t * 0.028 * sp, 1.0)
		var sc := 0.35 + 0.95 * d
		var y := WATER + 6.0 + (H - WATER + 10.0) * d * d
		var x: float = fmod(w.x0 + t * 9.0 * sp * sc, W + 240.0) - 120.0
		var a := smoothstep(0.0, 0.08, d) * (1.0 - smoothstep(0.88, 1.0, d))
		if a <= 0.02: continue
		var length: float = 78.0 * sc * w.len
		var amp := 4.2 * sc
		var pts := PackedVector2Array()
		for i in 13:
			var u := i / 12.0
			pts.append(Vector2(x + (u - 0.5) * length, y + sin(u * TAU * 1.25 + w.ph + t * 2.4 * sp) * amp))
		draw_polyline(pts, Color(SEA_LINE, a), 1.8 + 2.4 * sc, true)

## 광원 상태 계산 → 바다·까미·부두 셰이더에 전달
func update_lights() -> void:
	var t := Game.clock
	var cover := 0.0
	for cl in clouds:
		var cx := cloud_pos(cl, t)
		for b in cl.blobs:
			var d := Vector2(cx + b.x, cl.y + b.y).distance_to(MOON)
			cover += 0.9 * clampf(1.0 - d / (b.z + MOON_R), 0.0, 1.0)
	var wk: String = Game.weather.key
	var weather_k := {"storm": 0.3, "rain": 0.55, "fog": 0.7}.get(wk, 1.0) as float
	var target := clampf(1.0 - cover, 0.35, 1.0) * weather_k
	moon_light = lerpf(moon_light, target, 0.05)
	var flick := lantern_flicker(t)
	var flash := Game.lightning if wk == "storm" else 0.0
	backdrop_mat.set_shader_parameter("moon_light", moon_light)
	var lpos := get_global_transform() * LANTERN
	for m in [lit_cat]:
		m.set_shader_parameter("lantern_pos", lpos)
		m.set_shader_parameter("lantern", flick)
		m.set_shader_parameter("moon_light", moon_light)
		m.set_shader_parameter("lightning", clampf(flash, 0.0, 1.0))
		m.set_shader_parameter("ambient", Vector3.ONE * lerpf(0.86, 1.0, moon_light))
