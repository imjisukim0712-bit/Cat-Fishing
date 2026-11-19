extends "res://scripts/stage_draw.gd"
## Foreground effects retain their original ordering above the composited cat.
## 밝은 파스텔 패널 위에서 읽히는 등급 색 (main.gd RCOL 과 같은 값)
const RC := {"junk": "#6f6a7d", "common": "#4a5578", "rare": "#2f6fd0", "epic": "#8a3fd6", "legend": "#c27a00", "myth": "#d81f35", "trans": "#b0399a"}
func _ready() -> void:
	init_brush()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_base = get_parent()._base
	xf()
	draw_particles()
	draw_weather_fx(Game.clock)
	if Game.mode == "power": draw_power_bar()
	if Game.mode == "fight": draw_fight_bar(Game.clock)
	if Game.mode == "bite": draw_bite_mark(Game.clock)
	draw_set_transform(Vector2.ZERO)
	if Game.flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, minf(.85, Game.flash)))

func draw_particles() -> void:
	for p in Game.parts:
		var col: Color = p.c
		col.a = p.a
		if p.sq:
			xf(Vector2(p.x, p.y), p.rot)
			draw_rect(Rect2(-p.r, -p.r * 0.6, p.r * 2, p.r * 1.2), col)
		else:
			circle(p.x, p.y, p.r, col)
	xf()

# ----------------------------------------------------------------- 날씨 이펙트
func draw_weather_fx(tm: float) -> void:
	var key: String = Game.weather.key
	if key == "rain":
		for d in Game.rain:
			line(Vector2(d.x, d.y), Vector2(d.x - d.len * 0.32, d.y + d.len), rgba(179, 181, 231, .28), 1.4, true)
	if key == "fog":
		for i in 3:
			var y := WATER - 70 + i * 55 + sin(tm * 0.35 + i) * 10
			var mid := rgba(179, 170, 211, 0.09 + 0.04 * sin(tm * 0.5 + i))
			grad_rect(0, y - 40, W, 80, Vector2(0, y - 40), Vector2(0, y + 40), [[0.0, rgba(179, 170, 211, 0)], [.5, mid], [1.0, rgba(179, 170, 211, 0)]])
	if key == "hightide":
		grad_rect(0, WATER - 14, W, 32, Vector2(0, WATER - 14), Vector2(0, WATER + 18), [[0.0, c("#47c8d7", 0)], [.5, c("#47c8d7", .10 + sin(tm * 1.4) * .025)], [1.0, c("#47c8d7", 0)]])
	if key == "meteor":
		for m in Game.meteors:
			var k: float = 1 - m.t / m.life
			line(Vector2(m.x, m.y), Vector2(m.x - cos(m.ang) * m.len, m.y - sin(m.ang) * m.len), rgba(255, 244, 214, 0.60 * k), 2.4)
			circle(m.x, m.y, 2.4, Color(1, 1, 1, 0.9 * k))
	if key == "storm":
		draw_rect(Rect2(0, 0, W, H), rgba(4, 6, 22, .32))
		if Game.lightning > 0.0:
			draw_rect(Rect2(0, 0, W, H), c("#dfe9ff", minf(.6, Game.lightning * 0.6)))

# ----------------------------------------------------------------- 게이지
func draw_power_bar() -> void:
	var x := 270.0; var y := H - 96; var w := 420.0; var h := 22.0
	panel(x - 8, y - 30, w + 16, h + 40)
	text("던지기 세기", x, y - 12, 12, c("#3d2346"), HORIZONTAL_ALIGNMENT_LEFT, Data.font_heavy)
	text("%d%%" % Data.js_round(Game.power * 100), x + w, y - 12, 12, c("#c27a00"), HORIZONTAL_ALIGNMENT_RIGHT, Data.font_heavy)
	fill_rrect(x, y, w, h, 7, c("#efe8ff"))
	if Game.power > 0.005:
		var shape := Geometry2D.intersect_polygons(rrect(x, y, w, h, 7), PackedVector2Array([Vector2(x, y), Vector2(x + w * Game.power, y), Vector2(x + w * Game.power, y + h), Vector2(x, y + h)]))
		for piece in shape:
			grad_poly(piece, Vector2(x, 0), Vector2(x + w, 0), [[0.0, c("#8fb8ff")], [.6, c("#9be59b")], [.85, c("#ffd36b")], [1.0, c("#ff8a8a")]])
	draw_dashed_line(Vector2(x + w * 0.86, y - 3), Vector2(x + w * 0.86, y + h + 3), c("#3d2346", .7), 2, 4)   # 스윗스팟
	stroke_rrect(x, y, w, h, 7, c("#3d2346"), 2.2)

func draw_fight_bar(_tm: float) -> void:
	var f = Game.fight
	if not f or not Game.fish: return
	var x := 270.0; var y := H - 104; var w := 420.0; var h := 28.0
	panel(x - 14, y - 42, w + 28, h + 62)
	var ra: Dictionary = Data.RARITY[Game.fish.r]
	text("%s 입질" % ra.name, x, y - 20, 13, Color(RC.get(String(Game.fish.r), "#3d2346")), HORIZONTAL_ALIGNMENT_LEFT, Data.font_heavy)
	# 진행: 맞춘 수만큼 그림 발바닥, 남은 수는 점, 빗나간 수는 빨간 ×  (오른쪽 정렬)
	var paw: Texture2D = Data.icon("paw")
	var cx := x + w
	for i in f.miss:
		text("×", cx, y - 19, 16, c("#d81f35"), HORIZONTAL_ALIGNMENT_RIGHT, Data.font_heavy)
		cx -= 12
	if f.miss > 0: cx -= 8
	for i in range(f.need - 1, -1, -1):
		if i < f.hits and paw:
			draw_texture_rect(paw, Rect2(cx - 16, y - 34, 16, 16), false)
		else:
			circle(cx - 8, y - 26, 2.4, c("#6e5a8c", .8))
		cx -= 19

	fill_rrect(x, y, w, h, 9, c("#efe8ff"))   # 트랙
	var zx: float = x + (f.zc - f.zw / 2) * w
	var zw: float = f.zw * w
	fill_rrect(zx, y + 2, zw, h - 4, 7, c("#9be59b"))
	stroke_rrect(zx, y + 2, zw, h - 4, 7, c("#3f8f3a"), 1.6)
	line(Vector2(x + f.zc * w, y + 4), Vector2(x + f.zc * w, y + h - 4), c("#3f8f3a", .8), 1.5)   # 중앙선

	var mx: float = x + f.pos * w   # 마커
	var mc := (c("#6fd46f") if f.flashOk else c("#ff6b6b")) if f.flashT > 0.0 else c("#fff4d6")
	stroke_rrect(x, y, w, h, 9, c("#3d2346"), 2.2)
	fill_rrect(mx - 5, y - 7.5, 10, h + 15, 5, c("#3d2346"))
	fill_rrect(mx - 3, y - 5.5, 6, h + 11, 3, mc)
	circle(mx, y - 10, 6, c("#3d2346"))
	circle(mx, y - 10, 4.5, c("#ffd166"))
	text("초록 구간에서 클릭 / 스페이스 · 3번 빗나가면 도망가요", x + w / 2, y + h + 20, 12, c("#6e5a8c"), HORIZONTAL_ALIGNMENT_CENTER)

func draw_bite_mark(tm: float) -> void:
	var x := Game.fx; var y := Game.surf - 58
	var s := 1.0 + sin(tm * 22) * 0.12
	xf(Vector2(x, y), 0.0, Vector2(s, s))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -31), Vector2(16, 13), Vector2(-16, 13)]), c("#3d2346"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(13, 10), Vector2(-13, 10)]), c("#ff6b7a"))
	text("!", 0, 6, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Data.font_heavy)
	xf()
	# 시간 게이지
	var left := 1.0 - Game.t / Game.bite_win
	fill_rrect(x - 34, y + 14, 68, 11, 5.5, c("#3d2346"))
	fill_rrect(x - 32, y + 16, 64, 7, 3.5, c("#efe8ff"))
	fill_rrect(x - 32, y + 16, 64 * maxf(0.0, left), 7, 3.5, c("#6fd46f") if left > .4 else c("#ff6b6b"))
