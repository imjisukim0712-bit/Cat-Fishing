extends "res://scripts/stage_draw.gd"
## Paint-aligned lantern/creel accents and the original line/float animation.

func _ready() -> void:
	init_brush()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_base = get_parent()._base
	xf()
	if not Game.S.creel.is_empty():
		var box := CREEL_BOX
		# 상자에 물고기가 있으면 위로 작은 반짝이가 톡톡
		var k := fmod(Game.clock * 0.8, 1.0)
		var r := 4.0 * sin(k * PI)
		var p := box + Vector2(12, -26 - k * 6)
		var pts := PackedVector2Array()
		for i in 8:
			var a := i * PI / 4.0 - PI / 2.0
			pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.32))
		if r > 0.5: draw_colored_polygon(pts, c("#fff4d6"))
	draw_line_and_float(Game.clock)

func draw_line_and_float(tm: float) -> void:
	var mode := Game.mode
	var tip := Game.rod_tip()
	if mode == "idle" and not Game.celebrating:
		# 대기 상태: 줄만 살짝 늘어뜨림
		stroke(quad_pts(tip, tip + Vector2(16, 34), tip + Vector2(8, 58)), rgba(220, 235, 255, .35), 1.2)
		draw_arc(tip + Vector2(8, 62), 4, .4, 4.6, 16, c("#cfd9ef"), 1.6, true)   # 바늘
		return
	if mode == "power":
		stroke(quad_pts(tip, tip + Vector2(-10, -30), tip + Vector2(-26, -44)), rgba(220, 235, 255, .35), 1.2)
		return
	var fx := Game.fx; var fy := Game.fy
	var bob := 0.0
	if mode == "wait":
		var near_nibble := absf(Game.t - Game.nibble) < 0.35
		bob = sin(tm * 2.2) * 2.2 + (sin(tm * 30) * 4.5 if near_nibble else 0.0)
		if near_nibble and randf() < 0.16: Game.ripples.append({"x": fx, "y": Game.surf, "r": 4.0, "a": .4})
	elif mode == "bite":
		bob = 12 + sin(tm * 36) * 4    # 찌가 쑥 들어감
	elif mode == "fight":
		bob = 8 + sin(tm * 22) * 6
		fx = Game.fx + sin(tm * 7) * 16
		if randf() < 0.25: Game.ripples.append({"x": fx, "y": Game.surf, "r": 5.0, "a": .35})
	var dy := fy + bob
	# 낚싯줄 (늘어짐)
	var sag := 6.0 if (mode == "fight" or mode == "bite") else 26.0
	stroke(quad_pts(tip, Vector2((tip.x + fx) / 2, maxf(tip.y, dy) + sag), Vector2(fx, dy)), rgba(255, 244, 214, .75), 1.4)
	draw_float(fx, dy, tm)

func draw_float(x: float, y: float, tm: float) -> void:
	# 찌 주변 물결 고리·빛은 찌가 물에 떠 있을 때만 (던지는 중·감아올리는 중엔 없음).
	# 찌가 떠 있는 수면(Game.surf) 높이에 그리고, 착수 직후엔 빠르게 퍼지며 나타난다.
	var on_water := Game.mode in ["wait", "bite", "fight"]
	if on_water:
		var since := Game.t if Game.mode == "wait" else 10.0
		var appear := clampf(since / 0.35, 0.0, 1.0)
		var wy := Game.surf + 2
		for i in 3:
			var radius := 13.0 + fmod(tm * 10 + i * 13, 39)
			var fade := (1 - (radius - 13) / 39) * appear
			stroke_ell(x, wy, radius, radius * .26, c("#fff4d6", fade), 2.8)
	var lv: int = Game.S.upg.float
	var top_col := c("#ff3ba0") if lv >= 7 else (c("#ffb020") if lv >= 5 else (c("#ff7a18") if lv >= 3 else c("#e64545")))
	var plum := c("#3d2346")
	# 시안처럼 찌를 조금 크게 (1.35배): 찌 중심 기준으로 확대해서 그림
	xf(Vector2(x, y), 0.0, Vector2(1.35, 1.35))
	x = 0.0; y = 0.0
	line(Vector2(x, y - 26), Vector2(x, y - 9), plum, 3.4)   # 안테나 테두리
	line(Vector2(x, y - 26), Vector2(x, y - 9), c("#fff4d6"), 1.6)
	circle(x, y - 28, 4.8, plum)
	circle(x, y - 28, 3.4, top_col)
	if lv >= 4:
		circle(x, y - 28, 8 + sin(tm * 1000.0 / 300.0) * 1.6, rgba(255, 220, 120, .35))
	fill_ell(x, y - 1, 8.0, 11.5, plum)                      # 두들 테두리
	fill_ell(x, y - 3, 6.5, 9.5, top_col, 0, PI, TAU)       # 몸통 윗부분
	fill_ell(x, y + 2, 6.5, 9.5, c("#fff4d6"), 0, 0, PI)     # 몸통 아랫부분
	line(Vector2(x - 6.5, y - 2.5), Vector2(x + 6.5, y - 2.5), plum, 1.6)
	xf()

