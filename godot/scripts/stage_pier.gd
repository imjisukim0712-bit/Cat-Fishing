extends "res://scripts/stage_draw.gd"
## 부두 (두들 화풍, 승인 시안 M6 비율): 두툼한 상판·짧은 기둥은 코드로 그리고,
## 랜턴·물고기 상자는 그림 스프라이트. 랜턴 후광과 불꽃은 깜빡임에 맞춰 움직인다.

const PLUM := Color("#3d2346")
const DECK_TOP := Color("#ffc196")
const DECK_FACE := Color("#f8a774")
const POST := Color("#f3a06d")
const OUT_W := 2.6
## 랜턴 그림(87x144) 속 유리창 영역 중심·반크기
const GLASS_C := Vector2(43, 86)
const GLASS_HALF := Vector2(29, 32)
const LANTERN_K := 0.5
const BOX_K := 0.45

var lantern_tex: Texture2D
var box_tex: Texture2D

func _ready() -> void:
	init_brush()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lantern_tex = load("res://assets/art/lantern.png")
	box_tex = load("res://assets/art/creel_box.png")

func _process(_delta: float) -> void:
	queue_redraw()

func outlined_rect(r: Rect2, fill: Color, rad := 3.0) -> void:
	fill_rrect(r.position.x - OUT_W, r.position.y - OUT_W, r.size.x + OUT_W * 2, r.size.y + OUT_W * 2, rad + OUT_W, PLUM)
	fill_rrect(r.position.x, r.position.y, r.size.x, r.size.y, rad, fill)

func _draw() -> void:
	_base = get_parent()._base
	xf()
	var t := Game.clock
	# 기둥 (상판 뒤): 물에 닿는 밑동엔 크림색 물결 두 줄이 살랑
	for px in PIER_POSTS:
		outlined_rect(Rect2(px - 15, DECK_FACE_BOTTOM - 4, 30, PIER_POST_BOTTOM - DECK_FACE_BOTTOM + 4), POST, 2.0)
		var wob := sin(t * 2.2 + px * 0.05) * 2.0
		for side in [-1.0, 1.0]:
			var x0: float = px + side * (19.0 + wob)
			line(Vector2(x0, PIER_POST_BOTTOM - 4), Vector2(x0 + side * 9.0, PIER_POST_BOTTOM - 5 + sin(t * 3.0 + px) * 1.2), Color("#fff4d6"), 2.4, true)
	# 상판 앞면 (볼트)
	outlined_rect(Rect2(-20, DECK_SURFACE_BOTTOM, PIER_RIGHT + 20, DECK_FACE_BOTTOM - DECK_SURFACE_BOTTOM), DECK_FACE, 3.0)
	var bx := 30.0
	while bx < PIER_RIGHT - 8:
		circle(bx, (DECK_SURFACE_BOTTOM + DECK_FACE_BOTTOM) * 0.5, 2.6, PLUM)
		bx += 64.0
	# 상판 윗면 (비스듬한 널빤지 줄)
	outlined_rect(Rect2(-20, DECK_SURFACE_TOP, PIER_RIGHT + 20, DECK_SURFACE_BOTTOM - DECK_SURFACE_TOP), DECK_TOP, 3.0)
	var lx := 34.0
	while lx < PIER_RIGHT - 10:
		line(Vector2(lx + 5, DECK_SURFACE_TOP + 1), Vector2(lx - 3, DECK_SURFACE_BOTTOM - 1), PLUM, 2.0, true)
		lx += 54.0

	# 랜턴: 노란 후광이 불꽃 따라 숨쉬고, 유리 속 불빛 밝기·불꽃 흔들림
	var f := lantern_flicker(t)
	var halo_r := 40.0 + (f - 0.9) * 22.0
	circle(LANTERN.x, LANTERN.y - 4, halo_r + 7.0, Color("#ffe27a", 0.22))
	circle(LANTERN.x, LANTERN.y - 4, halo_r, Color("#ffd966"))
	var ls := lantern_tex.get_size() * LANTERN_K
	var ltl := Vector2(LANTERN.x - GLASS_C.x * LANTERN_K, LANTERN.y - GLASS_C.y * LANTERN_K)
	var glass := Color("#ffe27a").lerp(Color("#fff6c8"), clampf((f - 0.7) / 0.4, 0.0, 1.0))
	fill_rrect(LANTERN.x - GLASS_HALF.x * LANTERN_K - 1, LANTERN.y - GLASS_HALF.y * LANTERN_K - 1,
		(GLASS_HALF.x * 2 + 2) * LANTERN_K, (GLASS_HALF.y * 2 + 2) * LANTERN_K, 5, glass)
	var sway := sin(t * 6.1) * 1.2 + sin(t * 11.3) * 0.6
	var fh := 9.0 * f
	draw_colored_polygon(PackedVector2Array([
		LANTERN + Vector2(sway, -fh - 2), LANTERN + Vector2(4.2, 2.5), LANTERN + Vector2(0, 6.0), LANTERN + Vector2(-4.2, 2.5)]), Color.WHITE)
	circle(LANTERN.x, LANTERN.y + 2.6, 4.2, Color.WHITE)
	draw_texture_rect(lantern_tex, Rect2(ltl, ls), false)
	# 물고기 상자
	var bs := box_tex.get_size() * BOX_K
	draw_texture_rect(box_tex, Rect2(CREEL_BOX - bs * 0.5, bs), false)
