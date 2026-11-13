extends "res://scripts/stage_draw.gd"
## Hybrid scene: imported paintings beneath live gameplay and a softened cat.
var backdrop: Sprite2D
var backdrop_mat: ShaderMaterial
var pier: Sprite2D
var cat: Node2D
var lit_cat: ShaderMaterial
var lit_pier: ShaderMaterial

## 구름: 하늘을 천천히 지나가며, 달을 가리면 달빛(물 반사·테두리 빛)이 약해진다
const MOON := Vector2(762, 110)
const MOON_R := 40.0
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
	backdrop.scale = Vector2(W / bd_tex.get_width(), (941.0 * WATER / 548.0) / bd_tex.get_height())
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
	pier = Sprite2D.new()
	pier.texture = load("res://assets/art/pier.png")
	pier.centered = false
	pier.scale = Vector2.ONE * PIER_SCALE
	pier.region_enabled = true
	pier.region_rect = Rect2(PIER_CUT, 0, 1869 - PIER_CUT, 740)
	lit_pier = ShaderMaterial.new()
	lit_pier.shader = load("res://shaders/lit_sprite.gdshader")
	lit_pier.set_shader_parameter("submerge", (WATER - PIER_TOP) / (740 * PIER_SCALE))
	lit_pier.set_shader_parameter("rim_px", 4.0)
	pier.material = lit_pier
	add_child(pier)

	var props := Node2D.new()
	props.set_script(load("res://scripts/stage_props.gd"))
	add_child(props)
	# 까미는 이제 그림 스프라이트라 별도 뷰포트·흐림 처리 없이 화면 해상도 그대로 그린다
	cat = Node2D.new()
	cat.set_script(load("res://scripts/stage_cat.gd"))
	lit_cat = ShaderMaterial.new()
	lit_cat.shader = load("res://shaders/lit_sprite.gdshader")
	cat.material = lit_cat
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 5:
		var blobs := []
		for j in 6:
			blobs.append(Vector3(rng.randf_range(-90, 90), rng.randf_range(-10, 10), rng.randf_range(28, 60)))
		clouds.append({"x": rng.randf_range(-200, 1100), "y": rng.randf_range(55, 200),
			"sp": rng.randf_range(5, 11), "a": rng.randf_range(.22, .34), "blobs": blobs})
	add_child(cat)
	# 랜턴 불빛·반딧불이: 빛을 '더하는' 레이어라 부두와 까미를 실제로 비춘다
	var light := Node2D.new()
	light.set_script(load("res://scripts/stage_light.gd"))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = add
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
	pier.position = _base + Vector2(0, PIER_TOP)
	cat.position = _base
	draw_clouds(Game.clock)
	draw_water(Game.clock)

func draw_water(tm: float) -> void:
	# 물결 움직임은 전부 backdrop_water 셰이더가 그림 자체를 흘려서 표현한다 (덧그리는 빛 조각 없음)
	# 물속 물고기 그림자 (대기 중)
	if Game.mode == "wait" and Game.fish:
		var prog := minf(1.0, Game.t / maxf(.1, Game.bite_at))
		var sx := Game.fx + (1 - prog) * (180.0 if Game.fx > W / 2 else -180.0) * cos(Game.t * 1.6)
		var sy := WATER + 70 - prog * 40
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

	# 파문
	for w in Game.ripples:
		stroke_ell(w.x, w.y, w.r, w.r * 0.30, c("#12dfea", w.a * .3), 6)
		stroke_ell(w.x, w.y, w.r, w.r * 0.30, c("#9afaff", w.a), 1.8)

## 하늘을 지나가는 구름 (달 쪽 가장자리는 달빛을 받아 밝게)
func cloud_pos(cl: Dictionary, t: float) -> float:
	return fmod(cl.x + t * cl.sp + 300.0, W + 600.0) - 300.0

func draw_clouds(t: float) -> void:
	var wk: String = Game.weather.key
	var dark := wk == "storm" or wk == "rain"
	var boost := 1.8 if dark else (1.3 if wk == "fog" else 1.0)
	for cl in clouds:
		var cx := cloud_pos(cl, t)
		for b in cl.blobs:
			var p := Vector2(cx + b.x, cl.y + b.y)
			var lit := clampf(1.0 - p.distance_to(MOON) / 260.0, 0.0, 1.0) * moon_light
			var base := c("#4a4270") if dark else c("#9a8fc8")
			var col := base.lerp(c("#f2dcc0"), lit * 0.55)
			glow(p.x, p.y, b.z * 2.0, b.z * 0.6, Color(col, minf(cl.a * boost, 0.6)))

## 광원 상태 계산 → 바다·까미·부두 셰이더에 전달
func update_lights() -> void:
	var t := Game.clock
	var cover := 0.0
	for cl in clouds:
		var cx := cloud_pos(cl, t)
		for b in cl.blobs:
			var d := Vector2(cx + b.x, cl.y + b.y).distance_to(MOON)
			cover += cl.a * 2.2 * clampf(1.0 - d / (b.z * 1.4), 0.0, 1.0)
	var wk: String = Game.weather.key
	var weather_k := {"storm": 0.3, "rain": 0.55, "fog": 0.7}.get(wk, 1.0) as float
	var target := clampf(1.0 - cover, 0.35, 1.0) * weather_k
	moon_light = lerpf(moon_light, target, 0.05)
	var flick := lantern_flicker(t)
	var flash := Game.lightning if wk == "storm" else 0.0
	backdrop_mat.set_shader_parameter("moon_light", moon_light)
	var lpos := get_global_transform() * LANTERN
	for m in [lit_cat, lit_pier]:
		m.set_shader_parameter("lantern_pos", lpos)
		m.set_shader_parameter("lantern", flick)
		m.set_shader_parameter("moon_light", moon_light)
		m.set_shader_parameter("lightning", clampf(flash, 0.0, 1.0))
		m.set_shader_parameter("ambient", Vector3(0.86, 0.88, 1.0) * lerpf(0.82, 1.0, moon_light))
