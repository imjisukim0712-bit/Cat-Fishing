extends "res://scripts/stage_draw.gd"
## 빛 레이어 (가산 혼합): 일렁이는 랜턴 불빛이 부두·까미를 비추고, 반딧불이가 맴돈다.

const FIREFLIES := 10
var flies: Array = []

func _ready() -> void:
	init_brush()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in FIREFLIES:
		flies.append({
			# 랜턴 주변과 부두 앞 물가를 중심으로 천천히 맴돌기
			"cx": rng.randf_range(20, 420), "cy": rng.randf_range(200, 380),
			"rx": rng.randf_range(18, 60), "ry": rng.randf_range(10, 34),
			"sx": rng.randf_range(0.13, 0.32), "sy": rng.randf_range(0.17, 0.41),
			"ph": rng.randf() * TAU, "blink": rng.randf_range(0.5, 1.2), "bp": rng.randf() * TAU,
		})

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_base = get_parent()._base
	xf()
	var t := Game.clock
	var f := lantern_flicker(t)
	var warm := c("#ffb35a")
	var lx := LANTERN.x; var ly := LANTERN.y
	# 랜턴 불꽃 주변 후광 (깜빡임에 따라 크기·밝기 변화)
	glow(lx, ly, 105 * f, 92 * f, Color(warm, 0.34 * f))
	glow(lx, ly, 22 * f, 26 * f, Color(c("#ffd9a0"), 0.55 * f))
	# 부두 바닥에 고이는 빛
	glow(lx + 40, WATER - 14, 170 * f, 13, Color(warm, 0.48 * f))
	# 까미 왼쪽(랜턴 쪽) 몸을 비추는 빛
	glow(CAT.x - 40, CAT.y - 55, 62, 74, Color(warm, 0.14 * f))
	# 반딧불이
	for fl in flies:
		var x: float = fl.cx + sin(t * fl.sx + fl.ph) * fl.rx + sin(t * fl.sx * 2.3 + fl.ph * 1.7) * fl.rx * 0.3
		var y: float = fl.cy + sin(t * fl.sy + fl.ph * 0.6) * fl.ry
		var a := smoothstep(0.1, 1.0, 0.5 + 0.5 * sin(t * fl.blink + fl.bp))
		if a <= 0.01: continue
		glow(x, y, 13, 13, Color(c("#d8ff8a"), 0.45 * a))
		glow(x, y, 3.2, 3.2, Color(c("#f4ffd0"), 1.0 * a))
