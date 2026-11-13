extends "res://scripts/stage_draw.gd"
## Paint-aligned lantern/creel accents and the original line/float animation.

func _ready() -> void:
	init_brush()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_base = get_parent()._base
	xf()
	var lantern := Vector2(237 * PIER_SCALE, PIER_TOP + 150 * PIER_SCALE)
	var flicker := .16 + sin(Game.clock * 3.1) * .025 + sin(Game.clock * 5.7) * .015
	glow(lantern.x, lantern.y, 24, 30, c("#ffc778", flicker))
	glow(lantern.x, WATER - 16, 47, 5, c("#ffc778", flicker * .7))
	if not Game.S.creel.is_empty():
		var box := Vector2(449 * PIER_SCALE, PIER_TOP + 182 * PIER_SCALE)
		glow(box.x, box.y + 5, 15, 9, c("#64eee9", .38))
		fill_ell(box.x - 1, box.y + 6, 5, 2, c("#b7fff4", .7))
		draw_colored_polygon(PackedVector2Array([box + Vector2(3, 6), box + Vector2(7, 3), box + Vector2(7, 9)]), c("#b7fff4", .6))
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
		if near_nibble and randf() < 0.16: Game.ripples.append({"x": fx, "y": WATER, "r": 4.0, "a": .4})
	elif mode == "bite":
		bob = 12 + sin(tm * 36) * 4    # 찌가 쑥 들어감
	elif mode == "fight":
		bob = 8 + sin(tm * 22) * 6
		fx = Game.fx + sin(tm * 7) * 16
		if randf() < 0.25: Game.ripples.append({"x": fx, "y": WATER, "r": 5.0, "a": .35})
	var dy := fy + bob
	# 낚싯줄 (늘어짐)
	var sag := 6.0 if (mode == "fight" or mode == "bite") else 26.0
	stroke(quad_pts(tip, Vector2((tip.x + fx) / 2, maxf(tip.y, dy) + sag), Vector2(fx, dy)), rgba(225, 240, 255, .55), 1.3)
	draw_float(fx, dy, tm)

func draw_float(x: float, y: float, tm: float) -> void:
	glow(x, y + 6, 61, 19, c("#00dbef", .65))
	glow(x, y + 6, 26, 8, c("#77faff", .52))
	for i in 3:
		var radius := 13.0 + fmod(tm * 10 + i * 13, 39)
		var fade := 1 - (radius - 13) / 39
		stroke_ell(x, y + 6, radius, radius * .22, c("#00dbea", fade * .22), 7)
		stroke_ell(x, y + 6, radius, radius * .22, c("#28eefa", fade * .4), 3.5)
		stroke_ell(x, y + 6, radius, radius * .22, c("#adfcff", fade * .88), 1.6)
	var lv: int = Game.S.upg.float
	var top_col := c("#ff3ba0") if lv >= 7 else (c("#ffb020") if lv >= 5 else (c("#ff7a18") if lv >= 3 else c("#e64545")))
	line(Vector2(x, y - 26), Vector2(x, y - 9), c("#f4f7ff"), 2)   # 안테나
	circle(x, y - 28, 3.4, top_col)
	if lv >= 4:
		circle(x, y - 28, 8 + sin(tm * 1000.0 / 300.0) * 1.6, rgba(255, 220, 120, .35))
	fill_ell(x, y - 3, 6.5, 9.5, top_col, 0, PI, TAU)       # 몸통 윗부분
	fill_ell(x, y + 2, 6.5, 9.5, c("#f4f7ff"), 0, 0, PI)     # 몸통 아랫부분
	stroke_ell(x, y - 1, 6.5, 10, Color(0, 0, 0, .25), 1)

