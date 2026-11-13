extends Node2D
## Shared visual geometry; no gameplay state updates.
## 부두 그림 배치: 폭 400px (약한 캐스팅 최소 지점 x=400 과 겹치지 않는 최대 폭)
const PIER_SCALE := 400.0 / 1869.0
const PIER_TOP := 318.0 - 16.0 - 232.0 * PIER_SCALE
## 그림 왼쪽 끝마구리(모서리 깎인 부분)를 잘라내 부두가 화면 밖으로 이어지는 것처럼 보이게
const PIER_CUT := 64.0
const PIER_SHIFT := -PIER_CUT * PIER_SCALE   # 잘라낸 만큼 그림 속 위치가 왼쪽으로 이동
## 부두 그림 속 랜턴 유리 중심 (무대 좌표)
const LANTERN := Vector2(237.0 * PIER_SCALE - PIER_CUT * PIER_SCALE, 318.0 - 16.0 - 232.0 * PIER_SCALE + 150.0 * PIER_SCALE)

## 랜턴 불꽃 밝기: 여러 주기를 섞어 불규칙하게 일렁임 (0.7~1.1)
static func lantern_flicker(t: float) -> float:
	var f := 0.9 + 0.07 * sin(t * 7.3) + 0.05 * sin(t * 13.1 + 1.0) + 0.04 * sin(t * 23.7 + 2.0) + 0.03 * sin(t * 2.1)
	if fmod(t, 5.3) < 0.12: f -= 0.12   # 가끔 '툭' 하고 약해짐
	return clampf(f, 0.7, 1.1)


const W := 960.0
const H := 540.0
const WATER := 318.0
const CAT := Vector2(186, 318)
const ROD_HAND := Vector2(186 + 32, 318 - 66)   # game.gd 와 같은 값

var _base := Vector2.ZERO
var glow_texture: GradientTexture2D

func init_brush() -> void:
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

