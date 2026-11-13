extends Node2D
## 무대 그리기 — 원본 canvas 렌더 함수(drawSky/drawWater/drawDock/drawCat …)를 Godot 2D 드로잉으로 옮김.
## 좌표계는 원본과 같은 960x540. 상태는 전부 Game 오토로드에서 읽기만 한다.

const W := 960.0
const H := 540.0
const WATER := 318.0
const CAT := Vector2(186, 318)
const ROD_HAND := Vector2(186 + 34, 318 - 96)

var stars: Array = []
var mountains: Array[PackedVector2Array] = []
var glow_texture: GradientTexture2D
var _base := Vector2.ZERO      # 화면 흔들림 오프셋

func _ready() -> void:
	# Local deterministic visual seed: decoration never consumes gameplay randomness.
	var rng := RandomNumberGenerator.new()
	rng.seed = 307
	for i in 90:
		stars.append({"x": rng.randf() * W, "y": rng.randf() * (WATER - 40), "r": rng.randf_range(.35, .9),
			"ph": rng.randf() * TAU, "sp": rng.randf_range(.3, .7)})
	for layer in 5:
		var pts := PackedVector2Array([Vector2(0, WATER)])
		for x in range(0, 969, 8):
			var y := 219.0 + layer * 19 + sin(x * .013 + layer * 1.7) * (15 - layer)
			y += sin(x * .031 + layer) * 4 + rng.randf_range(-1.4, 1.4)
			pts.append(Vector2(x, y))
		pts.append(Vector2(W, WATER))
		mountains.append(pts)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, .25), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0, .35, 1])
	glow_texture = GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(.5, .5)
	glow_texture.fill_to = Vector2(1, .5)
	glow_texture.width = 128
	glow_texture.height = 128

func glow(x: float, y: float, rx: float, ry: float, color: Color) -> void:
	draw_texture_rect(glow_texture, Rect2(x - rx, y - ry, rx * 2, ry * 2), false, color)

func _process(_d: float) -> void:
	queue_redraw()

# ================================================================= 드로잉 헬퍼
static func c(hex: String, a := -1.0) -> Color:
	var col := Color(hex)
	if a >= 0.0: col.a = a
	return col

static func rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

func xf(off := Vector2.ZERO, rot := 0.0, scl := Vector2.ONE) -> void:
	draw_set_transform(_base + off, rot, scl)

static func ell(cx: float, cy: float, rx: float, ry: float, rot := 0.0, a0 := 0.0, a1 := TAU, seg := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(6, int(seg * absf(a1 - a0) / TAU))
	var cr := cos(rot); var sr := sin(rot)
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		var px := cos(a) * rx; var py := sin(a) * ry
		pts.append(Vector2(cx + px * cr - py * sr, cy + px * sr + py * cr))
	return pts

func fill_ell(cx: float, cy: float, rx: float, ry: float, col: Color, rot := 0.0, a0 := 0.0, a1 := TAU) -> void:
	var p := ell(cx, cy, rx, ry, rot, a0, a1)
	if a1 - a0 >= TAU - 0.001: p.remove_at(p.size() - 1)
	draw_colored_polygon(p, col)

func stroke_ell(cx: float, cy: float, rx: float, ry: float, col: Color, w: float, rot := 0.0, a0 := 0.0, a1 := TAU) -> void:
	draw_polyline(ell(cx, cy, rx, ry, rot, a0, a1), col, w, true)

func circle(x: float, y: float, r: float, col: Color) -> void:
	draw_circle(Vector2(x, y), r, col)

static func rrect(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) / 2.0)
	var pts := PackedVector2Array()
	var corners := [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
	for cn in corners:
		for i in 7:
			var a: float = cn[2] + (PI / 2) * i / 6.0
			pts.append(Vector2(cn[0] + cos(a) * r, cn[1] + sin(a) * r))
	return pts

func fill_rrect(x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	if w <= 0.5 or h <= 0.5: return
	draw_colored_polygon(rrect(x, y, w, h, r), col)

func stroke_rrect(x: float, y: float, w: float, h: float, r: float, col: Color, lw: float) -> void:
	var p := rrect(x, y, w, h, r)
	p.append(p[0])
	draw_polyline(p, col, lw, true)

static func quad_pts(p0: Vector2, cp: Vector2, p1: Vector2, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		pts.append(p0.lerp(cp, k).lerp(cp.lerp(p1, k), k))
	return pts

func stroke(pts: PackedVector2Array, col: Color, w: float, round_caps := false) -> void:
	draw_polyline(pts, col, w, true)
	if round_caps and pts.size() > 0:
		draw_circle(pts[0], w / 2.0, col)
		draw_circle(pts[pts.size() - 1], w / 2.0, col)

func line(a: Vector2, b: Vector2, col: Color, w: float, round_caps := false) -> void:
	stroke(PackedVector2Array([a, b]), col, w, round_caps)

static func grad_at(stops: Array, k: float) -> Color:
	k = clampf(k, 0.0, 1.0)
	for i in stops.size() - 1:
		if k <= stops[i + 1][0]:
			var span: float = stops[i + 1][0] - stops[i][0]
			return (stops[i][1] as Color).lerp(stops[i + 1][1], 0.0 if span <= 0.0 else (k - stops[i][0]) / span)
	return stops[-1][1]

## 선형 그라데이션으로 폴리곤 채우기 (canvas createLinearGradient 대응).
## 스톱 경계마다 잘라서 그리므로 구간 안에서는 정확히 선형.
func grad_poly(poly: PackedVector2Array, p0: Vector2, p1: Vector2, stops: Array) -> void:
	var axis := p1 - p0
	var L := axis.length()
	if L <= 0.0: return
	var dir := axis / L
	var nrm := Vector2(-dir.y, dir.x) * 4000.0
	# 앞뒤 바깥 영역 포함한 구간 목록
	var segs := []
	segs.append([-50.0, float(stops[0][0])])
	for i in stops.size() - 1: segs.append([float(stops[i][0]), float(stops[i + 1][0])])
	segs.append([float(stops[-1][0]), 50.0])
	for s in segs:
		if s[1] - s[0] <= 0.0: continue
		var a: Vector2 = p0 + axis * s[0]
		var b: Vector2 = p0 + axis * s[1]
		var slab := PackedVector2Array([a - nrm, b - nrm, b + nrm, a + nrm])
		for piece in Geometry2D.intersect_polygons(poly, slab):
			var cols := PackedColorArray()
			for v in piece:
				cols.append(grad_at(stops, (v - p0).dot(dir) / L))
			draw_polygon(piece, cols)

func grad_rect(x: float, y: float, w: float, h: float, p0: Vector2, p1: Vector2, stops: Array) -> void:
	grad_poly(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), p0, p1, stops)

## 원형 그라데이션 (중심 r0 까지 c0, r1 에서 c1)
func radial(cx: float, cy: float, r0: float, r1: float, c0: Color, c1: Color, seg := 48) -> void:
	if r0 > 0.0: draw_circle(Vector2(cx, cy), r0, c0)
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var d0 := Vector2(cos(a0), sin(a0)); var d1 := Vector2(cos(a1), sin(a1))
		var ctr := Vector2(cx, cy)
		draw_polygon(PackedVector2Array([ctr + d0 * r0, ctr + d0 * r1, ctr + d1 * r1, ctr + d1 * r0]),
			PackedColorArray([c0, c1, c1, c0]))

## 초점에서 테두리로 퍼지는 그라데이션 (볼록 도형 전용)
func fan(focus: Vector2, focus_col: Color, boundary: PackedVector2Array, col_fn: Callable) -> void:
	var n := boundary.size()
	for i in n:
		var p0 := boundary[i]; var p1 := boundary[(i + 1) % n]
		draw_polygon(PackedVector2Array([focus, p0, p1]), PackedColorArray([focus_col, col_fn.call(p0), col_fn.call(p1)]))

func text(s: String, x: float, y: float, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, font: Font = null) -> void:
	var f: Font = font if font else Data.font_bold
	var pos := Vector2(x, y)
	if align == HORIZONTAL_ALIGNMENT_CENTER: pos.x -= 300
	elif align == HORIZONTAL_ALIGNMENT_RIGHT: pos.x -= 600
	draw_string(f, pos, s, align, 600 if align != HORIZONTAL_ALIGNMENT_LEFT else -1, size, col)

func panel(x: float, y: float, w: float, h: float) -> void:
	fill_rrect(x, y, w, h, 14, rgba(19, 23, 49, .94))
	stroke_rrect(x, y, w, h, 14, rgba(159, 149, 224, .85), 1.5)

# ================================================================= 렌더
func _draw() -> void:
	var tm := Game.clock
	_base = Vector2.ZERO
	if Game.shake > 0.0:
		_base = Vector2((randf() - .5) * Game.shake, (randf() - .5) * Game.shake)
	xf()
	# 흔들릴 때 가장자리가 비지 않도록 바탕을 먼저 깐다
	draw_rect(Rect2(-40, -40, W + 80, H + 80), c("#050914"))

	draw_sky(tm)
	draw_water(tm)
	draw_dock()
	draw_line_and_float(tm)
	draw_cat(tm)
	draw_particles()
	draw_weather_fx(tm)

	if Game.mode == "power": draw_power_bar()
	if Game.mode == "fight": draw_fight_bar(tm)
	if Game.mode == "bite": draw_bite_mark(tm)

	draw_set_transform(Vector2.ZERO)
	if Game.flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, minf(.85, Game.flash)))

# ----------------------------------------------------------------- 하늘
func draw_sky(tm: float) -> void:
	grad_rect(0, 0, W, WATER, Vector2.ZERO, Vector2(0, WATER), [[0.0, c("#101631")], [.55, c("#252d59")], [1.0, c("#62608a")]])
	for s in stars:
		circle(s.x, s.y, s.r, c("#d7d9ff", .22 + .28 * absf(sin(tm * s.sp + s.ph))))
	var mx := 760.0; var my := 88.0; var mr := 36.0
	# Smooth cream disc: four soft craters, no procedural speckle.
	glow(mx, my, mr * 1.6, mr * 1.6, c("#ffe3b0", .18))
	var moon := ell(mx, my, mr, mr)
	moon.remove_at(moon.size() - 1)
	grad_poly(moon, Vector2(mx - mr, my), Vector2(mx + mr, my),
		[[0.0, c("#fff5d4")], [.55, c("#fff0c3")], [1.0, c("#e8d6a5")]])
	for crater in [Vector4(-12, -9, 10, 8), Vector4(11, 5, 13, 11), Vector4(-4, 19, 7, 6), Vector4(16, -16, 6, 5)]:
		glow(mx + crater.x, my + crater.y, crater.z, crater.w, c("#a48e61", .18))
	stroke_ell(mx, my, mr, mr, c("#fff9df", .42), 1)
	var colors := ["#555780", "#494e78", "#3b436c", "#30385f", "#292f54"]
	for layer in mountains.size():
		draw_colored_polygon(mountains[layer], c(colors[layer]))
		var y := 244.0 + layer * 16
		grad_rect(0, y, W, 30, Vector2(0, y), Vector2(0, y + 30), [[0.0, c("#aba0ca", 0)], [.6, c("#aba0ca", .055)], [1.0, c("#aba0ca", 0)]])
	for i in 21:
		var x := 340.0 + fmod(i * 137.7, 590)
		var y := WATER - 4 - fmod(i * 3.3, 7)
		circle(x, y, .7, c("#ffc58a", .30))
		glow(x, y, 4, 2, c("#ffc58a", .12))

# ----------------------------------------------------------------- 물
func draw_water(tm: float) -> void:
	grad_rect(0, WATER, W, H - WATER, Vector2(0, WATER), Vector2(0, H), [[0.0, c("#101c38")], [.33, c("#09243a")], [.65, c("#07344b")], [1.0, c("#08263f")]])

	# Quiet distant water; broken, narrow cream reflection.
	for i in 24:
		var y := WATER + 3 + i * 6.3
		var wdt := 8 + i * .8 + sin(tm * .6 + i * 2.1) * 6
		fill_ell(760 + sin(i * 1.8 + tm * .4) * 7, y, wdt, .7, c("#ffe0b7", .24 - i * .007))
	var wk: String = Game.weather.key
	var amp := 6.4 if wk == "storm" else (5.2 if wk == "hightide" else 2.0)
	for i in 15:
		var pts := PackedVector2Array()
		for x in range(0, 969, 12):
			pts.append(Vector2(x, WATER + 6 + i * 14 + sin(x * .014 + tm * .45 + i) * amp))
		draw_polyline(pts, c("#839ed5", .07), 1, true)
	# Layered alpha glow is local to the near water (Compatibility / Web).
	for band in 3:
		var pts := PackedVector2Array()
		var haze := PackedVector2Array()
		var haze_colors := PackedColorArray()
		var strength := .65 + band * .16
		for x in range(0, 969, 8):
			var y := 402 + band * 54 + sin(x * .012 + tm * .35 + band * 2) * (9 + band * 3)
			y += sin(x * .027 - tm * .22 + band) * 2.5
			pts.append(Vector2(x, y))
		# A translucent ribbon fades below each crest, not into the sky.
		# One vertex-colored polygon per ribbon, rather than one draw per segment.
		for point in pts:
			haze.append(point)
			haze_colors.append(c("#02d5ed", .13 * strength))
		for i in range(pts.size() - 1, -1, -1):
			haze.append(pts[i] + Vector2(0, 32))
			haze_colors.append(c("#02d5ed", 0))
		draw_polygon(haze, haze_colors)
		draw_polyline(pts, c("#00cde2", .035 * strength), 28, true)
		draw_polyline(pts, c("#00d9ec", .075 * strength), 16, true)
		draw_polyline(pts, c("#16e7f5", .18 * strength), 8, true)
		draw_polyline(pts, c("#35eefa", .40 * strength), 4.5, true)
		draw_polyline(pts, c("#7ff6ff", .88 * strength), 2.1 + band * .3, true)
	# Nine 45–70 px silhouettes; the active float gets a wide, softly faded gap.
	for i in 9:
		var x := fposmod(i * 113.7 + tm * (3 + i % 3), W + 100) - 50
		var y := 428 + fmod(i * 31.3, 74) + sin(tm * .7 + i) * 3
		var visibility := 1.0
		if Game.mode in ["wait", "bite", "fight"]:
			visibility = smoothstep(110.0, 165.0, absf(x - Game.fx))
		if visibility <= .001: continue
		var size := (45.0 + fmod(i * 9.7, 26.0)) / 2.7
		var wiggle := sin(tm * 2.2 + i * 1.7) * size * .10
		glow(x, y, size * 2.3, size * .9, c("#00ddf4", .45 * visibility))
		glow(x, y, size * 1.4, size * .5, c("#51efff", .27 * visibility))
		draw_colored_polygon(PackedVector2Array([Vector2(x + size * .7, y), Vector2(x + size * 1.7, y - size * .4 + wiggle), Vector2(x + size * 1.4, y + wiggle), Vector2(x + size * 1.7, y + size * .35 + wiggle)]), c("#56deef", .53 * visibility))
		fill_ell(x, y, size, size * .28, c("#74e9f6", .60 * visibility), -.08)
		stroke_ell(x, y, size, size * .28, c("#b0faff", .65 * visibility), 1, -.08, PI, TAU)
		circle(x - size * .6, y - 1, 1, c("#e5ffff", .7 * visibility))
	for i in 86:
		var x := fmod(i * 137.53, W)
		var y := 400 + fmod(i * 53.17, 137)
		var twinkle := pow(absf(sin(tm * .8 + i)), 6)
		var alpha := .22 + .62 * twinkle
		glow(x, y, 6 + twinkle * 3, 6 + twinkle * 3, c("#10e6f5", alpha * .7))
		circle(x, y, .75 + twinkle * .45, c("#a5faff", alpha))
		if i % 9 == 0:
			line(Vector2(x - 2.5, y), Vector2(x + 2.5, y), c("#bcffff", twinkle * .65), .8)
			line(Vector2(x, y - 2.5), Vector2(x, y + 2.5), c("#bcffff", twinkle * .65), .8)

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

# ----------------------------------------------------------------- 부두
func draw_dock() -> void:
	for x in [70, 150, 232]:
		grad_rect(x, WATER - 6, 14, 96, Vector2(x, 0), Vector2(x + 14, 0), [[0.0, c("#654257")], [.35, c("#44304a")], [1.0, c("#251e34")]])
		line(Vector2(x + 3, WATER + 10), Vector2(x + 3, WATER + 88), c("#bd7880", .24), 1)
		glow(x + 7, WATER + 90, 31, 9, c("#03dfef", .4))
		stroke_ell(x + 7, WATER + 90, 23, 4, c("#42eaf4", .5), 1)
		line(Vector2(x + 1, WATER + 70), Vector2(x + 1, WATER + 90), c("#65eaff", .36), 1)
	grad_rect(0, WATER - 16, 286, 22, Vector2(0, WATER - 16), Vector2(0, WATER + 6), [[0.0, c("#ba795e")], [.2, c("#8b5860")], [.25, c("#684252")], [1.0, c("#34263b")]])
	for x in range(14, 286, 34):
		line(Vector2(x, WATER - 16), Vector2(x, WATER + 6), c("#291e36", .7), 1.5)
		line(Vector2(x + 4, WATER - 11), Vector2(x + 27, WATER - 12), c("#e0a078", .25), 1)
		circle(x + 15, WATER - 1, 1.6, c("#8d849e"))
	# Amber lantern, with restrained local flicker.
	var ly := WATER - 35
	var flicker := .85 + .07 * sin(Game.clock * 4.1) + .04 * sin(Game.clock * 7.3)
	glow(35, ly, 45, 49, c("#ffb34e", .38 * flicker))
	fill_ell(35, WATER - 15, 31, 4, c("#ffc46b", .2))
	stroke_ell(35, ly - 21, 9, 12, c("#dba56e"), 1)
	fill_rrect(24, ly - 19, 22, 36, 5, c("#513948"))
	grad_poly(rrect(27, ly - 15, 16, 28, 4), Vector2(27, ly), Vector2(43, ly), [[0.0, c("#9c694b")], [.5, c("#ffd47e")], [1.0, c("#a16c54")]])
	glow(35, ly + 1, 12, 19, c("#ffda81", flicker))
	fill_ell(35, ly + 4, 3, 7, c("#fff2bc"))
	stroke_rrect(24, ly - 19, 22, 36, 5, c("#ffd590", .8), 1)
	fill_rrect(21, ly + 16, 28, 4, 2, c("#57394a"))
	# Translucent tackle box; filled creel remains visible through its lid.
	var bx := 80.0; var by := WATER - 16
	fill_rrect(bx - 19, by - 24, 38, 24, 3, c("#a99adb", .36))
	stroke_rrect(bx - 19, by - 24, 38, 24, 3, c("#d3ccff", .8), 1)
	fill_rrect(bx - 20, by - 27, 40, 7, 2, c("#bcb9f4", .45))
	line(Vector2(bx - 18, by - 19), Vector2(bx + 18, by - 19), c("#ddd7ff", .6), 1)
	stroke_rrect(bx - 5, by - 31, 10, 4, 2, c("#a9a6d8"), 1)
	fill_rrect(bx - 2, by - 20, 4, 7, 1, c("#e0d5ff", .7))
	if not Game.S.creel.is_empty():
		glow(bx, by - 10, 19, 10, c("#52eee9", .45))
		fill_ell(bx - 2, by - 9, 8, 3, c("#a7fff1", .9))
		draw_colored_polygon(PackedVector2Array([Vector2(bx + 4, by - 9), Vector2(bx + 11, by - 13), Vector2(bx + 11, by - 5)]), c("#a7fff1", .9))

# ----------------------------------------------------------------- 낚싯줄 & 찌
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

# ----------------------------------------------------------------- 까미
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
	grad_poly(body, Vector2(bx - 40, by - 90), Vector2(bx + 40, by), [[0.0, c("#35314f")], [.5, c("#201e36")], [1.0, c("#121326")]])
	stroke_ell(bx, by - body_h * .55 + breathe * .3, body_w, body_h, c("#b4a2e8", .45), 1.3, 0, -1.2, .7)
	draw_outfit_body(Game.S.outfit, bx, by, body_w, body_h, breathe)

	# 앞발
	fill_ell(bx + 14, by - 6, 13, 8, c("#1a1b26"))
	fill_ell(bx - 9, by - 5, 13, 8, c("#1a1b26"))
	fill_ell(bx + 14, by - 8, 6.5, 4, c("#2c2e40"))

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
	var c0 := c("#41385b"); var c1 := c("#17172d")
	fan(focus, c0, head, func(p: Vector2): return c0.lerp(c1, clampf((p.distance_to(focus) - 4) / (hr + 8 - 4), 0, 1)))

	stroke_ell(hx, hy, hr, hr - 2, c("#c3aff9", .65), 1.2, 0, -1.5, .55)
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
		fill_ell(X, ey, 8.4, eh, c("#d8f24a"))
		if not blinking:
			var pw := 4.6 if mood == "alert" else 2.4
			fill_ell(X, ey, pw, eh - 1.2, c("#10131c"))
			circle(X - 3, ey - 4, 1.9, Color(1, 1, 1, .85))

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

# ----------------------------------------------------------------- 파티클
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
			line(Vector2(d.x, d.y), Vector2(d.x - d.len * 0.32, d.y + d.len), rgba(179, 181, 231, .38), 1.4, true)
	if key == "fog":
		for i in 3:
			var y := WATER - 70 + i * 55 + sin(tm * 0.35 + i) * 10
			var mid := rgba(179, 170, 211, 0.12 + 0.05 * sin(tm * 0.5 + i))
			grad_rect(0, y - 40, W, 80, Vector2(0, y - 40), Vector2(0, y + 40), [[0.0, rgba(179, 170, 211, 0)], [.5, mid], [1.0, rgba(179, 170, 211, 0)]])
	if key == "hightide":
		draw_rect(Rect2(0, WATER - 14, W, 14 + sin(tm * 1.4) * 3), rgba(71, 200, 215, .13))
	if key == "meteor":
		for m in Game.meteors:
			var k: float = 1 - m.t / m.life
			line(Vector2(m.x, m.y), Vector2(m.x - cos(m.ang) * m.len, m.y - sin(m.ang) * m.len), rgba(255, 244, 214, 0.75 * k), 2.4)
			circle(m.x, m.y, 2.4, Color(1, 1, 1, 0.9 * k))
	if key == "storm":
		draw_rect(Rect2(0, 0, W, WATER), rgba(4, 6, 14, .28))
		if Game.lightning > 0.0:
			draw_rect(Rect2(0, 0, W, H), c("#dfe9ff", minf(.6, Game.lightning * 0.6)))

# ----------------------------------------------------------------- 게이지
func draw_power_bar() -> void:
	var x := 270.0; var y := H - 96; var w := 420.0; var h := 22.0
	panel(x - 8, y - 30, w + 16, h + 40)
	text("던지기 세기", x, y - 12, 12, c("#cfd9ef"))
	text("%d%%" % Data.js_round(Game.power * 100), x + w, y - 12, 12, c("#ffc24a"), HORIZONTAL_ALIGNMENT_RIGHT)
	fill_rrect(x, y, w, h, 7, c("#0b1122"))
	if Game.power > 0.005:
		var shape := Geometry2D.intersect_polygons(rrect(x, y, w, h, 7), PackedVector2Array([Vector2(x, y), Vector2(x + w * Game.power, y), Vector2(x + w * Game.power, y + h), Vector2(x, y + h)]))
		for piece in shape:
			grad_poly(piece, Vector2(x, 0), Vector2(x + w, 0), [[0.0, c("#4a8cff")], [.6, c("#8af08a")], [.85, c("#ffc24a")], [1.0, c("#ff5d5d")]])
	draw_dashed_line(Vector2(x + w * 0.86, y - 3), Vector2(x + w * 0.86, y + h + 3), Color(1, 1, 1, .6), 2, 4)   # 스윗스팟
	stroke_rrect(x, y, w, h, 7, Color(1, 1, 1, .35), 1.5)

func draw_fight_bar(_tm: float) -> void:
	var f = Game.fight
	if not f or not Game.fish: return
	var x := 270.0; var y := H - 104; var w := 420.0; var h := 28.0
	panel(x - 14, y - 42, w + 28, h + 62)
	var ra: Dictionary = Data.RARITY[Game.fish.r]
	text("%s 입질" % ra.name, x, y - 20, 13, ra.col, HORIZONTAL_ALIGNMENT_LEFT, Data.font_heavy)
	var prog := "🐾".repeat(f.hits) + "·".repeat(maxi(0, f.need - f.hits)) + "   " + "✖".repeat(f.miss)
	text(prog, x + w, y - 20, 13, c("#cfd9ef"), HORIZONTAL_ALIGNMENT_RIGHT, Data.font_heavy)

	fill_rrect(x, y, w, h, 9, c("#0b1122"))   # 트랙
	var zx: float = x + (f.zc - f.zw / 2) * w
	var zw: float = f.zw * w
	grad_poly(rrect(zx, y + 2, zw, h - 4, 7), Vector2(zx, 0), Vector2(zx + zw, 0),
		[[0.0, rgba(90, 240, 140, .25)], [.5, rgba(120, 255, 160, .85)], [1.0, rgba(90, 240, 140, .25)]])
	line(Vector2(x + f.zc * w, y + 3), Vector2(x + f.zc * w, y + h - 3), Color(1, 1, 1, .6), 1.5)   # 중앙선

	var mx: float = x + f.pos * w   # 마커
	var mc := (c("#8af08a") if f.flashOk else c("#ff6b6b")) if f.flashT > 0.0 else Color.WHITE
	fill_rrect(mx - 3.5, y - 6, 7, h + 12, 3.5, mc)
	circle(mx, y - 10, 4.5, c("#ffd166"))
	stroke_rrect(x, y, w, h, 9, Color(1, 1, 1, .28), 1.5)
	text("초록 구간에서 클릭 / 스페이스 · 3번 빗나가면 도망가요", x + w / 2, y + h + 20, 12, c("#8b98bd"), HORIZONTAL_ALIGNMENT_CENTER)

func draw_bite_mark(tm: float) -> void:
	var x := Game.fx; var y := WATER - 58
	var s := 1.0 + sin(tm * 22) * 0.12
	xf(Vector2(x, y), 0.0, Vector2(s, s))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(13, 10), Vector2(-13, 10)]), c("#e0454f"))
	text("!", 0, 6, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Data.font_heavy)
	xf()
	# 시간 게이지
	var left := 1.0 - Game.t / Game.bite_win
	fill_rrect(x - 32, y + 16, 64, 7, 3.5, Color(0, 0, 0, .5))
	fill_rrect(x - 32, y + 16, 64 * maxf(0.0, left), 7, 3.5, c("#8af08a") if left > .4 else c("#ff6b6b"))
