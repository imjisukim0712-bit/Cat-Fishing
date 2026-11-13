extends "res://scripts/stage_draw.gd"
## Hybrid scene: imported paintings beneath live gameplay and a softened cat.
var backdrop: Sprite2D
var backdrop_mat: ShaderMaterial
var pier: Sprite2D
var cat: Node2D

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
	add_child(backdrop)
	pier = Sprite2D.new()
	pier.texture = load("res://assets/art/pier.png")
	pier.centered = false
	pier.scale = Vector2.ONE * PIER_SCALE
	var pier_material := ShaderMaterial.new()
	pier_material.shader = load("res://shaders/pier_water.gdshader")
	pier_material.set_shader_parameter("water_uv", (WATER - PIER_TOP) / (740 * PIER_SCALE))
	pier.material = pier_material
	add_child(pier)

	var props := Node2D.new()
	props.set_script(load("res://scripts/stage_props.gd"))
	add_child(props)
	# 까미는 이제 그림 스프라이트라 별도 뷰포트·흐림 처리 없이 화면 해상도 그대로 그린다
	cat = Node2D.new()
	cat.set_script(load("res://scripts/stage_cat.gd"))
	add_child(cat)
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
	pier.position = _base + Vector2(0, PIER_TOP)
	cat.position = _base
	draw_water(Game.clock)
	draw_reflections(Game.clock)

func draw_water(tm: float) -> void:
	# Soft alpha stamps accent the existing painting, never replace its waves.
	# 물 위 반짝임은 셰이더와 같은 흐름을 탄다: 모두 아래(보는 쪽)로 밀려오며 오른쪽으로 살짝 흐름.
	# 제자리에서 제각각 깜빡이는 효과는 쓰지 않는다.
	for i in 14:   # 달빛 기둥: 수평선에서 아래로 흘러내리는 빛 조각
		var depth := fmod(i / 14.0 + tm * 0.05, 1.0)
		var x := 762 + depth * 10
		var y := WATER + 5 + depth * 122
		var fade := sin(depth * PI)   # 생겨나고 사라질 때 부드럽게
		glow(x, y, 8 + depth * 16, 1.2 + depth, c("#ffe8ba", .05 * fade))
	for i in 12:   # 가까운 물결 위 빛 띠: 같은 속도로 오른쪽 아래로 흐름
		var k := fmod(i / 12.0 + tm * 0.03, 1.0)
		var x := fmod(i * 173.3 + tm * 9.0, W + 60) - 30
		var y := 440 + k * 90
		glow(x, y, 14 + k * 12, 1.6, c("#92fbff", .06 * sin(k * PI)))
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


func draw_reflections(tm: float) -> void:
	# Reflections follow the painted post centers, below their submerged tips.
	var bottom := PIER_TOP + 740 * PIER_SCALE
	for source_x in [220.0, 905.0, 1585.0]:
		for i in 9:
			var x: float = source_x * PIER_SCALE + sin(tm * .7 + i * 1.4) * 3
			var y := bottom - 4 + i * 4.2
			glow(x, y, 9 + sin(i * 2.1) * 3, 1.8, c("#c5a0bf", .10 * (1 - i / 9.0)))
	for i in 13:
		glow(237 * PIER_SCALE + sin(tm * .7 + i) * 3, WATER + 9 + i * 5, 6 + i * .35, 1.6, c("#ffd291", .09 * (1 - i / 13.0)))
