extends "res://scripts/stage_draw.gd"
## Unchanged cat/outfit/rod animation, isolated for the painterly compositor.

func _ready() -> void:
	init_brush()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_cat(Game.clock)

func draw_cat(tm: float) -> void:
	var fat := Game.fat_show
	var bx := CAT.x; var by := CAT.y - 16     # 부두 상판 위
	var breathe := sin(tm * 1.9) * 1.6
	var excited := Game.mode == "bite" or Game.mode == "fight"
	var jitter := sin(tm * 26) * 1.6 if excited else 0.0
	xf(Vector2(jitter, 0))

	fill_ell(bx, by + 2, 46 + fat * 9, 8, Color(0, 0, 0, .35))    # 그림자

	# 꼬리
	var tw := sin(tm * (7.5 if excited else 2.1)) * 0.5
	var tail := quad_pts(Vector2(bx - 30, by - 14), Vector2(bx - 78, by - 24 + tw * 26), Vector2(bx - 72, by - 66 + tw * 18))
	stroke(tail, c("#14151f"), 13, true)
	stroke(tail, c("#61537f"), 11, true)
	stroke(tail, c("#29263e"), 8, true)

	# 몸통
	var body_w := 40 + fat * 11; var body_h := 50 + fat * 5
	var body := ell(bx, by - body_h * 0.55 + breathe * 0.3, body_w, body_h)
	body.remove_at(body.size() - 1)
	grad_poly(body, Vector2(bx - 40, by - 90), Vector2(bx + 40, by), [[0.0, c("#3b3566")], [.35, c("#302b53")], [.72, c("#211b3b")], [1.0, c("#120f26")]])
	stroke_ell(bx, by - body_h * .55 + breathe * .3, body_w, body_h, c("#b7a8ff", .70), 2.5, 0, -1.2, .7)
	# Broad soft form light, then fine fur edges; outfits still draw over the body.
	glow(bx - body_w * .28, by - body_h * .85, body_w * .65, body_h * .64, c("#8a769a", .19))
	stroke_ell(bx, by - body_h * .55 + breathe * .3, body_w - 1, body_h - 1, c("#ffb466", .27), 3, 0, 2.6, 4.1)
	stroke_ell(bx, by - body_h * .55 + breathe * .3, body_w - 1, body_h - 1, c("#b8a4ef", .24), 4, 0, -1.1, .55)
	for i in 9:
		var a := 2.6 + i * .16
		var edge := Vector2(bx + cos(a) * body_w, by - body_h * .55 + breathe * .3 + sin(a) * body_h)
		line(edge, edge + Vector2(-1.7, -2.2), c("#c2a0b2", .22), .7)
	for side in [-1, 1]:
		for i in 5:
			var a := -.10 + i * .19
			var edge := Vector2(bx + side * cos(a) * body_w, by - body_h * .55 + breathe * .3 + sin(a) * body_h)
			var tuft := quad_pts(edge + Vector2(0, -3), edge + Vector2(side * 5, 1), edge + Vector2(-side, 5), 6)
			stroke(tuft, c("#a08ab9", .32), 3.5)
			stroke(tuft, c("#b7a8ff" if side > 0 else "#ffb466", .52 if side > 0 else .30), 1.2)
	draw_outfit_body(Game.S.outfit, bx, by, body_w, body_h, breathe)

	# 앞발
	for paw in [Vector2(bx + 14, by - 6), Vector2(bx - 9, by - 5)]:
		grad_poly(ell(paw.x, paw.y, 13, 8), paw + Vector2(-8, -7), paw + Vector2(7, 8), [[0.0, c("#51445f")], [.45, c("#2c2943")], [1.0, c("#16182c")]])
		stroke_ell(paw.x, paw.y, 12, 7, c("#a392c9", .25), .8, 0, -2.6, -.4)
		for toe in 2:
			line(paw + Vector2(2 + toe * 4, 2), paw + Vector2(2 + toe * 4, 5), c("#101225", .5), .7)

	# 머리
	var hy := by - body_h - 34 + breathe
	var hx := bx + (5.0 if excited else 2.0)
	var hr := 33.0

	# 귀
	var ear_tw := sin(tm * 22) * 0.16 if Game.cat_mood == "alert" else sin(tm * 1.3) * 0.03
	draw_ear(hx - 22, hy - 20, -0.35 + ear_tw)
	draw_ear(hx + 22, hy - 20, 0.35 - ear_tw)

	var head := ell(hx, hy, hr, hr - 2)
	head.remove_at(head.size() - 1)
	var focus := Vector2(hx - 10, hy - 12)
	var c0 := c("#3b3566"); var c1 := c("#120f26")
	fan(focus, c0, head, func(p: Vector2): return c0.lerp(c1, clampf((p.distance_to(focus) - 4) / (hr + 8 - 4), 0, 1)))

	stroke_ell(hx, hy, hr, hr - 2, c("#b7a8ff", .78), 2.5, 0, -1.5, .55)
	stroke_ell(hx, hy, hr - 1, hr - 3, c("#baa8ef", .22), 4, 0, -1.5, .55)
	stroke_ell(hx, hy, hr - 1, hr - 3, c("#ffb466", .27), 2.5, 0, 2.5, 3.9)
	glow(hx - 15, hy - 10, 16, 18, c("#dab092", .12))
	for side in [-1, 1]:
		for i in 3:
			var edge := Vector2(hx + side * (hr - 2 - i), hy + 8 + i * 4)
			var tuft := quad_pts(edge + Vector2(0, -3), edge + Vector2(side * 5, 0), edge + Vector2(-side * 2, 4), 6)
			stroke(tuft, c("#a08ab9", .42), 3.5)
			stroke(tuft, c("#b7a8ff" if side > 0 else "#ffb466", .62 if side > 0 else .36), 1.2)
	# 눈
	var mood := Game.cat_mood
	var blinking := Game.blink > 0.0 and mood != "star"
	var ey := hy - 2
	for X in [hx - 12, hx + 13]:
		if mood == "star":
			draw_star_eye(X, ey, 10 + sin(tm * 9 + X) * 1.4)
			continue
		if mood == "happy":
			draw_arc(Vector2(X, ey + 3), 8, PI * 1.12, PI * 1.88, 16, c("#ffe36b"), 3.4, true)
			continue
		if mood == "sad":
			draw_arc(Vector2(X, ey + 9), 8, PI * 0.15, PI * 0.85, 16, c("#c9d3ea"), 3, true)
			continue
		var eh := 1.6 if blinking else (12.0 if mood == "alert" else 9.5)
		glow(X, ey, 12, eh + 4, c("#d3ef5b", .22))
		grad_poly(ell(X, ey, 8.4, eh), Vector2(X, ey - eh), Vector2(X, ey + eh), [[0.0, c("#94b746")], [.45, c("#d8f24a")], [1.0, c("#f4ef94")]])
		if not blinking:
			var pw := 4.6 if mood == "alert" else 2.4
			fill_ell(X, ey, pw, eh - 1.2, c("#10131c"))
			circle(X - 2.4, ey - 4, 3.0, Color(1, 1, 1, .98))
			circle(X + 3, ey + 4, 1.4, c("#ffffff", .92))

	# 코 & 입
	draw_colored_polygon(PackedVector2Array([Vector2(hx, hy + 11), Vector2(hx - 4.5, hy + 7), Vector2(hx + 4.5, hy + 7)]), c("#ff9ab5"))
	if mood == "star" or mood == "alert":
		fill_ell(hx, hy + 17, 6.5, 6, c("#4a1d2b"))
		fill_ell(hx, hy + 20, 3.4, 2.6, c("#ff9ab5"))
	else:
		draw_arc(Vector2(hx - 4, hy + 13), 4.4, 0, PI * 0.85, 12, c("#8e93ad"), 1.7, true)
		draw_arc(Vector2(hx + 4, hy + 13), 4.4, PI * 0.15, PI, 12, c("#8e93ad"), 1.7, true)

	# 수염
	for s in [-1, 1]:
		for i in 3:
			var yy := hy + 6 + i * 5
			stroke(quad_pts(Vector2(hx + s * 9, yy), Vector2(hx + s * 30, yy - 4 + i * 3), Vector2(hx + s * 47, yy - 8 + i * 6), 12), rgba(230, 238, 255, .55), 1.2)

	draw_outfit_head(Game.S.outfit, hx, hy, hr, tm)

	# 목도리 (레벨업 훈장 느낌)
	if Game.S.upg.charm > 1:
		var cols := ["#e0454f", "#ff8a3d", "#63e6ff", "#b06bff", "#ffd166"]
		fill_ell(hx - 1, hy + hr - 4, 26, 8, c(cols[mini(4, Game.S.upg.charm - 1)]), 0, 0, PI)
		circle(hx - 1, hy + hr + 1, 4.5, c("#ffd166"))

	draw_rod()
	xf()

func draw_ear(x: float, y: float, rot: float) -> void:
	var o := Vector2(x, y)
	var outer := PackedVector2Array([Vector2(-15, 10), Vector2(0, -24), Vector2(15, 8)])
	var inner := PackedVector2Array([Vector2(-8, 7), Vector2(0, -13), Vector2(8, 6)])
	for i in 3:
		outer[i] = o + outer[i].rotated(rot)
		inner[i] = o + inner[i].rotated(rot)
	draw_colored_polygon(outer, c("#201e36"))
	stroke(PackedVector2Array([outer[0], outer[1], outer[2]]), c("#ad89cf", .65), 1.2)
	draw_colored_polygon(inner, c("#815078"))

func draw_star_eye(x: float, y: float, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r * 0.45 if i % 2 else r
		pts.append(Vector2(x + cos(a) * rr, y + sin(a) * rr))
	draw_colored_polygon(pts, c("#ffe36b"))

func draw_rod() -> void:
	var a := Game.rod_angle(); var L := 176.0
	var h := ROD_HAND
	var d := Vector2(cos(a), sin(a))
	var tip := h + d * L
	line(h - d * 26, h + d * 16, c("#4a2f1c"), 8, true)   # 손잡이
	var cols := ["#8a6b46", "#a8804f", "#c09a5c", "#d4b06a", "#9fd8ff", "#b6a2ff", "#ffb020", "#ff6ec7"]
	var bend := 26.0 if (Game.mode == "fight" or Game.mode == "bite") else (8.0 if Game.mode == "wait" else 2.0)
	var rod := quad_pts(h + d * 14, h + d * L * 0.55 + Vector2(0, bend * 0.4), tip + Vector2(0, bend))
	stroke(rod, c(cols[mini(cols.size() - 1, Game.S.upg.rod - 1)]), 4.5, true)
	stroke(rod, Color(1, 1, 1, .25), 2)
	var reel := h + Vector2(cos(a + 1.4), sin(a + 1.4)) * 13   # 릴
	circle(reel.x, reel.y, 7, c("#c9d3ea"))
	circle(reel.x, reel.y, 3, c("#5a6584"))

# ----------------------------------------------------------------- 까미 의상
func draw_outfit_body(id: String, bx: float, by: float, body_w: float, body_h: float, breathe: float) -> void:
	if id == "none": return
	var cy := by - body_h * .48 + breathe * .3
	match id:
		"hoodie":
			fill_ell(bx, cy + 6, body_w * .94, body_h * .82, c("#b9273d"))
			fill_rrect(bx - 19, cy + 17, 38, 18, 7, c("#8e1930"))
			line(Vector2(bx - 7, cy - 24), Vector2(bx - 5, cy - 7), c("#ffe4d9"), 2)
			line(Vector2(bx + 7, cy - 24), Vector2(bx + 5, cy - 7), c("#ffe4d9"), 2)
		"captain":
			fill_ell(bx, cy + 5, body_w * .96, body_h * .84, c("#172d57"))
			line(Vector2(bx, cy - 30), Vector2(bx, cy + 34), c("#f4c95d"), 3)
			for i in 3:
				circle(bx - 8, cy - 5 + i * 13, 2.5, c("#f4c95d"))
				circle(bx + 8, cy - 5 + i * 13, 2.5, c("#f4c95d"))
		"wizard":
			var cape := quad_pts(Vector2(bx - 35, cy - 24), Vector2(bx, cy - 40), Vector2(bx + 35, cy - 24), 12)
			cape.append(Vector2(bx + 43, by - 2)); cape.append(Vector2(bx - 43, by - 2))
			grad_poly(cape, Vector2(bx - 35, cy - 30), Vector2(bx + 35, cy + 35), [[0.0, c("#39236b")], [1.0, c("#7d3eb5")]])
			for p in [[-20, -5], [17, 8], [-8, 24]]:
				circle(bx + p[0], cy + p[1], 2.2, c("#ffd166"))
		"space":
			fill_ell(bx, cy + 5, body_w * .98, body_h * .86, c("#e8eff7"))
			draw_arc(Vector2(bx, cy + 5), body_w * .72, .1, PI - .1, 24, c("#5bbde8"), 4, true)
			fill_rrect(bx - 18, cy + 4, 36, 21, 5, c("#243756"))
			draw_rect(Rect2(bx - 11, cy + 10, 8, 4), c("#63e6ff"))
			circle(bx + 9, cy + 12, 3, c("#ff6b6b"))
		"royal":
			fill_ell(bx, cy + 7, body_w, body_h * .86, c("#711c62"))
			draw_arc(Vector2(bx, cy - 24), 25, .08, PI - .08, 24, c("#f7e7c6"), 7, true)
			circle(bx, cy + 5, 5, c("#ffd166"))
		"pirate":
			fill_ell(bx, cy + 6, body_w * .97, body_h * .85, c("#6f2630"))
			draw_rect(Rect2(bx - body_w * .85, cy + 15, body_w * 1.7, 8), c("#30201b"))
			draw_rect(Rect2(bx - 6, cy + 14, 12, 10), c("#ffd166"))
			line(Vector2(bx, cy - 24), Vector2(bx - 9, cy + 12), c("#e8d7b4"), 3)
			line(Vector2(bx, cy - 24), Vector2(bx + 9, cy + 12), c("#e8d7b4"), 3)

func draw_outfit_head(id: String, hx: float, hy: float, hr: float, tm: float) -> void:
	if id == "none": return
	match id:
		"hoodie":
			draw_arc(Vector2(hx, hy + 1), hr + 3, .05, PI - .05, 24, c("#b9273d"), 10, true)
		"captain":
			fill_ell(hx, hy - 31, 31, 10, c("#172d57"))
			var cap := quad_pts(Vector2(hx - 24, hy - 33), Vector2(hx, hy - 57), Vector2(hx + 24, hy - 33), 14)
			draw_colored_polygon(cap, c("#1f3c72"))
			line(Vector2(hx - 23, hy - 33), Vector2(hx + 23, hy - 33), c("#f4c95d"), 3, true)
			circle(hx, hy - 41, 4, c("#f4c95d"))
		"wizard":
			draw_colored_polygon(PackedVector2Array([Vector2(hx - 27, hy - 28), Vector2(hx + 7, hy - 76), Vector2(hx + 27, hy - 28)]), c("#56308d"))
			fill_ell(hx, hy - 27, 35, 8, c("#34205e"))
			circle(hx + 4, hy - 52 + sin(tm * 3) * 2, 3, c("#ffd166"))
		"space":
			circle(hx, hy, hr + 9, rgba(135, 220, 255, .10))
			draw_arc(Vector2(hx, hy), hr + 9, 0, TAU, 48, c("#bcecff"), 4, true)
			draw_arc(Vector2(hx - 7, hy - 5), hr - 2, 3.5, 4.65, 16, Color(1, 1, 1, .75), 3, true)
		"royal":
			draw_colored_polygon(PackedVector2Array([Vector2(hx - 24, hy - 25), Vector2(hx - 18, hy - 53), Vector2(hx - 5, hy - 37), Vector2(hx, hy - 59),
				Vector2(hx + 7, hy - 37), Vector2(hx + 22, hy - 53), Vector2(hx + 24, hy - 25)]), c("#ffd166"))
			for x in [-14, 0, 14]: circle(hx + x, hy - 31, 3, c("#e83e68"))
		"pirate":
			var hat := quad_pts(Vector2(hx - 35, hy - 29), Vector2(hx - 19, hy - 58), Vector2(hx, hy - 42), 10)
			hat.append_array(quad_pts(Vector2(hx, hy - 42), Vector2(hx + 19, hy - 58), Vector2(hx + 35, hy - 29), 10))
			hat.append_array(quad_pts(Vector2(hx + 35, hy - 29), Vector2(hx, hy - 18), Vector2(hx - 35, hy - 29), 10))
			draw_colored_polygon(hat, c("#34211d"))
			line(Vector2(hx - 8, hy - 42), Vector2(hx + 8, hy - 29), c("#e8d7b4"), 3, true)
			line(Vector2(hx + 8, hy - 42), Vector2(hx - 8, hy - 29), c("#e8d7b4"), 3, true)
			fill_ell(hx + 13, hy - 2, 10, 8, c("#191318"))
			line(Vector2(hx - 25, hy - 14), Vector2(hx + 23, hy - 10), c("#191318"), 2, true)

