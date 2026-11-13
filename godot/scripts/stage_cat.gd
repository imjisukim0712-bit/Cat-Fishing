extends "res://scripts/stage_draw.gd"
## 까미 — 그림 스프라이트 리그 (몸·옷 7종, 눈 6종, 입 2종, 꼬리, 낚싯대 쥔 앞발).
## 표정/깜빡임/숨쉬기/통통해지기/흥분 떨림은 코드로 움직이고, 낚싯대는 기존 코드 그대로.

const ART := "res://assets/art/kkami/"
const OUTFITS := ["none", "hoodie", "captain", "wizard", "space", "royal", "pirate"]
# 몸 시트 한 칸(443px) 기준 측정값 (둥근 실루엣·검은 털): 고양이 중심 x=223, 바닥 y=420,
# 머리 중심 (223,196)·폭 238, 코 (222,232), 턱 y=282
const CELL_ANCHOR := Vector2(223, 420)
const EYES_Y := 200.0
const MOUTH_Y := 250.0
const NECK_Y := 282.0
const SCALE := 0.435                # 몸 시트 → 무대 (키 345px → 약 150px)
const PART_K := 131.0 / 190.0       # 부품 시트 → 몸 시트 (눈 한 쌍 폭 190px = 머리폭의 55%)
const TAIL_BASE := Vector2(105, 188) # 꼬리 그림에서 몸에 붙는 지점 (아래쪽 끝)
const EYE_SPREAD := 2.5              # 눈 한 쌍 그림을 반으로 갈라 양쪽으로 더 벌리는 거리 (무대 px, 한쪽 기준)

var tex := {}

func _ready() -> void:
	init_brush()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for o in OUTFITS: tex["body_" + o] = load(ART + "body_%s.png" % o)
	for n in ["eyes_normal", "eyes_alert", "eyes_closed", "eyes_happy", "eyes_sad", "eyes_star", "mouth_closed", "mouth_open", "tail", "paw"]:
		tex[n] = load(ART + n + ".png")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_cat(Game.clock)

## 몸 시트 좌표 → 무대 좌표 (발 밑 기준으로 통통함·숨쉬기 비율 적용)
func to_stage(cell: Vector2, anchor: Vector2, sx: float, sy: float) -> Vector2:
	return anchor + Vector2((cell.x - CELL_ANCHOR.x) * SCALE * sx, (cell.y - CELL_ANCHOR.y) * SCALE * sy)

## 부품을 중심 기준으로 그리기
func part(name: String, center: Vector2, k: float, mod := Color.WHITE) -> void:
	var t: Texture2D = tex[name]
	var size := t.get_size() * k
	draw_texture_rect(t, Rect2(center - size / 2.0, size), false, mod)

## 눈 한 쌍 그림을 좌우 반으로 나눠 spread 만큼 바깥으로 벌려 그리기
func eyes_split(name: String, center: Vector2, k: float, spread: float) -> void:
	var t: Texture2D = tex[name]
	var size := t.get_size()
	var half := Vector2(size.x / 2.0, size.y)
	var dst := half * k
	var top := center.y - dst.y / 2.0
	draw_texture_rect_region(t, Rect2(Vector2(center.x - dst.x - spread, top), dst), Rect2(Vector2.ZERO, half))
	draw_texture_rect_region(t, Rect2(Vector2(center.x + spread, top), dst), Rect2(Vector2(half.x, 0), half))

func draw_cat(tm: float) -> void:
	var fat := Game.fat_show
	var excited := Game.mode == "bite" or Game.mode == "fight"
	var jitter := sin(tm * 26) * 1.6 if excited else 0.0
	var breathe := sin(tm * 1.9)
	var anchor := Vector2(CAT.x + jitter, CAT.y - 12)
	var sx := 1.0 + fat * 0.22
	var sy := (1.0 + fat * 0.04) * (1.0 + breathe * 0.006)
	xf()

	fill_ell(anchor.x, anchor.y - 2, 50 + fat * 10, 7, Color(0, 0, 0, .35))    # 그림자

	# 꼬리 (몸 뒤, 붙는 지점을 축으로 흔들기)
	var tw := sin(tm * (7.5 if excited else 2.1)) * 0.5
	var tail_t: Texture2D = tex.tail
	var tk := SCALE * PART_K * 0.95
	var pivot := anchor + Vector2(-38 * sx, -10)
	xf(pivot, -0.08 + tw * 0.22)
	draw_texture_rect(tail_t, Rect2(-TAIL_BASE * tk, tail_t.get_size() * tk), false)
	xf()

	# 몸 (옷 포함)
	var outfit: String = Game.S.outfit if OUTFITS.has(Game.S.outfit) else "none"
	var body: Texture2D = tex["body_" + outfit]
	var top_left := to_stage(Vector2.ZERO, anchor, sx, sy)
	draw_texture_rect(body, Rect2(top_left, body.get_size() * SCALE * Vector2(sx, sy)), false)

	# 표정
	var mood := Game.cat_mood
	var blinking := Game.blink > 0.0 and mood != "star"
	var eyes := "eyes_normal"
	match mood:
		"alert": eyes = "eyes_alert"
		"happy": eyes = "eyes_happy"
		"sad": eyes = "eyes_sad"
		"star": eyes = "eyes_star"
	if blinking and mood in ["idle", "alert"]: eyes = "eyes_closed"
	var pk := SCALE * PART_K * (0.5 * (1.0 + sx))   # 통통해지면 얼굴도 살짝 넓게
	var eye_pos := to_stage(Vector2(223, EYES_Y), anchor, sx, sy)
	if eyes == "eyes_normal" or eyes == "eyes_alert":
		var eye_off := 50.5 * pk + EYE_SPREAD * sx   # 눈 그림에서 각 눈 중심은 한가운데서 ±50.5px
		for side in [-1.0, 1.0]:                     # 밤 고양이 눈빛 (눈마다 따로, 사이에 띠가 생기지 않게)
			glow(eye_pos.x + side * eye_off, eye_pos.y, 9, 6, c("#d3ef5b", .14))
	var star_pulse := 1.0 + (sin(tm * 9) * 0.08 if mood == "star" else 0.0)
	eyes_split(eyes, eye_pos, pk * star_pulse, EYE_SPREAD * sx)
	var mouth := "mouth_open" if (mood == "star" or mood == "alert") else "mouth_closed"
	part(mouth, to_stage(Vector2(222, MOUTH_Y + (4.0 if mouth == "mouth_open" else 0.0)), anchor, sx, sy), pk * 0.9)

	# 목도리 (레벨업 훈장 느낌)
	if Game.S.upg.charm > 1:
		var neck := to_stage(Vector2(223, NECK_Y), anchor, sx, sy)
		var cols := ["#e0454f", "#ff8a3d", "#63e6ff", "#b06bff", "#ffd166"]
		fill_ell(neck.x, neck.y, 27 * sx, 7, c(cols[mini(4, Game.S.upg.charm - 1)], .92), 0, 0, PI)
		circle(neck.x, neck.y + 5, 4.2, c("#ffd166"))

	# 낚싯대 + 대를 쥔 앞발 (흥분 떨림은 몸과 같이)
	xf(Vector2(jitter, 0))
	draw_rod()
	part("paw", ROD_HAND + Vector2(-2, 3), SCALE * PART_K * 0.95)
	xf()

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
