extends "res://scripts/stage_draw.gd"
## 빛 레이어 (두들): 랜턴 반짝 선, 별똥별, 반딧불이를 선명한 단색 모양으로 그린다.

const FIREFLIES := 6
var flies: Array = []
var shooting: Array = []      # 가끔 떨어지는 별똥별
var next_star := 4.0

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
	var lx := LANTERN.x; var ly := LANTERN.y
	# 랜턴: 두들 '반짝 선' 세 가닥이 불꽃 깜빡임 따라 길어졌다 짧아짐
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.62
		var d := Vector2(cos(a), sin(a))
		var r0 := 22.0
		var r1 := r0 + 5.0 + 6.0 * (f - 0.7) / 0.4 + 1.5 * sin(t * 5.0 + i * 2.1)
		line(Vector2(lx, ly) + d * r0, Vector2(lx, ly) + d * r1, c("#ffe27a"), 2.6, true)
	# 별똥별: 맑은 밤엔 가끔 하나씩 (유성우 날씨는 별도 효과)
	var wk: String = Game.weather.key
	if t > next_star:
		next_star = t + randf_range(6.0, 14.0)
		if wk in ["clear", "hightide", "meteor"]:
			shooting.append({"x": randf_range(120, 820), "y": randf_range(20, 120), "t0": t,
				"ang": randf_range(0.35, 0.65) * (1 if randf() < .5 else -1) + (0.0 if randf() < .5 else PI)})
	for i in range(shooting.size() - 1, -1, -1):
		var st: Dictionary = shooting[i]
		var k: float = (t - float(st.t0)) / 0.9
		if k > 1.0:
			shooting.remove_at(i); continue
		var ang: float = st.ang
		var dir := Vector2(cos(ang), absf(sin(ang)))
		var head: Vector2 = Vector2(st.x, st.y) + dir * 260.0 * k
		var tail_len := 70.0 * sin(k * PI)
		# 꼬리: 점점 가늘어지는 크림색 선, 머리: 네 갈래 반짝이
		for j in 4:
			var q0: Vector2 = head - dir * tail_len * j / 4.0
			var q1: Vector2 = head - dir * tail_len * (j + 1) / 4.0
			line(q0, q1, c("#fff4d6"), 3.0 - j * 0.6, true)
		star4(head, 6.0 * (0.6 + 0.4 * sin(k * PI)), c("#fff4d6"))
	# 반딧불이: 연두 점 + 납작한 빛 고리
	for fl in flies:
		var x: float = fl.cx + sin(t * fl.sx + fl.ph) * fl.rx + sin(t * fl.sx * 2.3 + fl.ph * 1.7) * fl.rx * 0.3
		var y: float = fl.cy + sin(t * fl.sy + fl.ph * 0.6) * fl.ry
		var a := smoothstep(0.1, 1.0, 0.5 + 0.5 * sin(t * fl.blink + fl.bp))
		if a <= 0.05: continue
		circle(x, y, 7.0 * a, c("#e8ff9a", 0.22 * a))
		circle(x, y, 3.2, c("#d9f56a", a))
		circle(x - 0.8, y - 0.8, 1.2, c("#fbffe6", a))

## 네 갈래 반짝이 (두들 별)
func star4(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0 - PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.32
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
